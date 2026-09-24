#include "capture_backend.hpp"

#include <QElapsedTimer>
#include <QHash>
#include <QMetaObject>
#include <QRegion>
#include <QSocketNotifier>
#include <QTimer>
#include <QTransform>
#include <QtGlobal>

#include <algorithm>
#include <cerrno>
#include <cstring>
#include <fcntl.h>
#include <utility>
#include <sys/mman.h>
#include <unistd.h>
#include <wayland-client.h>

extern "C" {
#include "ext-foreign-toplevel-list-v1-client-protocol.h"
#include "ext-image-capture-source-v1-client-protocol.h"
#include "ext-image-copy-capture-v1-client-protocol.h"
}

namespace {

constexpr int kDefaultPreviewWidth = 640;
constexpr int kDefaultPreviewHeight = 360;
constexpr int kMinPreviewDimension = 32;
constexpr int kMaxPreviewDimension = 1024;

QSize boundedTargetSize(const QSize& requested) {
    if (!requested.isValid() || requested.isEmpty())
        return QSize(kDefaultPreviewWidth, kDefaultPreviewHeight);

    return QSize(
        std::clamp(requested.width(), kMinPreviewDimension, kMaxPreviewDimension),
        std::clamp(requested.height(), kMinPreviewDimension, kMaxPreviewDimension));
}

QImage cropScaleFrame(const QImage& source, const QSize& requested) {
    if (source.isNull())
        return {};

    const QSize target = boundedTargetSize(requested);
    QImage scaled = source.scaled(
        target,
        Qt::KeepAspectRatioByExpanding,
        Qt::FastTransformation);

    const int x = std::max(0, (scaled.width() - target.width()) / 2);
    const int y = std::max(0, (scaled.height() - target.height()) / 2);
    if (scaled.width() == target.width() && scaled.height() == target.height())
        return scaled;
    return scaled.copy(x, y,
                       std::min(target.width(), scaled.width() - x),
                       std::min(target.height(), scaled.height() - y));
}

QImage applyTransform(const QImage& image, uint32_t transform) {
    switch (transform) {
    case WL_OUTPUT_TRANSFORM_90:
    case WL_OUTPUT_TRANSFORM_FLIPPED_90:
        return image.transformed(QTransform().rotate(90), Qt::FastTransformation);
    case WL_OUTPUT_TRANSFORM_180:
    case WL_OUTPUT_TRANSFORM_FLIPPED_180:
        return image.transformed(QTransform().rotate(180), Qt::FastTransformation);
    case WL_OUTPUT_TRANSFORM_270:
    case WL_OUTPUT_TRANSFORM_FLIPPED_270:
        return image.transformed(QTransform().rotate(270), Qt::FastTransformation);
    default:
        return image;
    }
}

} // namespace

class CaptureWorker final : public QObject {
public:
    explicit CaptureWorker(CaptureBroker* broker)
        : m_broker(broker) {
        m_clock.start();

        m_pump.setInterval(15);
        m_pump.setTimerType(Qt::PreciseTimer);
        connect(&m_pump, &QTimer::timeout, this, [this] { pumpLiveSessions(); });
    }

    ~CaptureWorker() override {
        shutdown();
    }

    void initialize() {
        if (m_display)
            return;

        m_display = wl_display_connect(nullptr);
        if (!m_display) {
            publishBackendAvailability(false);
            return;
        }

        m_registry = wl_display_get_registry(m_display);
        static const wl_registry_listener registryListener = {
            &CaptureWorker::registryGlobal,
            &CaptureWorker::registryGlobalRemove,
        };
        wl_registry_add_listener(m_registry, &registryListener, this);

        if (wl_display_roundtrip(m_display) < 0) {
            shutdown();
            publishBackendAvailability(false);
            return;
        }

        if (!m_shm || !m_toplevelList || !m_sourceManager || !m_captureManager) {
            shutdown();
            publishBackendAvailability(false);
            return;
        }

        static const ext_foreign_toplevel_list_v1_listener listListener = {
            &CaptureWorker::toplevelCreated,
            &CaptureWorker::toplevelListFinished,
        };
        ext_foreign_toplevel_list_v1_add_listener(m_toplevelList, &listListener, this);

        if (wl_display_roundtrip(m_display) < 0) {
            shutdown();
            publishBackendAvailability(false);
            return;
        }

        m_notifier = new QSocketNotifier(
            wl_display_get_fd(m_display),
            QSocketNotifier::Read,
            this);
        connect(m_notifier, &QSocketNotifier::activated, this, [this] {
            if (!m_display)
                return;
            if (wl_display_dispatch(m_display) < 0) {
                publishBackendAvailability(false);
                shutdown();
            }
        });

        m_pump.start();
        publishBackendAvailability(true);
    }

    void updateConsumer(quint64 token,
                        const QString& identifier,
                        bool active,
                        bool live,
                        int maxFps,
                        const QSize& targetSize) {
        auto it = m_sessions.find(token);
        if (!active || identifier.isEmpty()) {
            if (it != m_sessions.end()) {
                publishSourceReady(token, false);
                destroySession(token);
            }
            return;
        }

        if (it == m_sessions.end()) {
            auto* state = new SessionState;
            state->owner = this;
            state->token = token;
            state->identifier = identifier;
            state->active = true;
            state->live = live;
            state->maxFps = std::clamp(maxFps, 1, 30);
            state->targetSize = boundedTargetSize(targetSize);
            m_sessions.insert(token, state);
            ensureCaptureSession(state);
            return;
        }

        SessionState* state = it.value();
        if (state->identifier != identifier) {
            publishSourceReady(token, false);
            destroySession(token);
            updateConsumer(token, identifier, active, live, maxFps, targetSize);
            return;
        }

        state->active = active;
        state->live = live;
        state->maxFps = std::clamp(maxFps, 1, 30);
        state->targetSize = boundedTargetSize(targetSize);
        ensureCaptureSession(state);
        if (state->live)
            requestFrame(state);
    }

    void captureOnce(quint64 token) {
        auto it = m_sessions.find(token);
        if (it == m_sessions.end())
            return;
        requestFrame(it.value());
    }

    void unregisterConsumer(quint64 token) {
        destroySession(token);
    }

    void stop() {
        shutdown();
        publishBackendAvailability(false);
    }

private:
    struct ToplevelState {
        CaptureWorker* owner = nullptr;
        ext_foreign_toplevel_handle_v1* handle = nullptr;
        QString identifier;
    };

    struct SessionState {
        CaptureWorker* owner = nullptr;
        quint64 token = 0;
        QString identifier;
        bool active = false;
        bool live = false;
        int maxFps = 18;
        QSize targetSize;

        ext_image_capture_source_v1* source = nullptr;
        ext_image_copy_capture_session_v1* session = nullptr;
        ext_image_copy_capture_frame_v1* frame = nullptr;

        uint32_t width = 0;
        uint32_t height = 0;
        uint32_t shmFormat = 0;
        bool supportsArgb = false;
        bool supportsXrgb = false;
        bool constraintsReady = false;
        bool framePending = false;
        bool firstFrame = true;
        bool bufferNeedsFullDamage = true;
        uint32_t transform = WL_OUTPUT_TRANSFORM_NORMAL;

        int memfd = -1;
        void* map = MAP_FAILED;
        size_t mapSize = 0;
        int stride = 0;
        wl_buffer* buffer = nullptr;

        QRegion damage;
        qint64 lastCaptureMs = 0;
    };

    static void registryGlobal(void* data,
                               wl_registry* registry,
                               uint32_t name,
                               const char* interface,
                               uint32_t version) {
        auto* self = static_cast<CaptureWorker*>(data);
        if (std::strcmp(interface, wl_shm_interface.name) == 0) {
            self->m_shm = static_cast<wl_shm*>(
                wl_registry_bind(registry, name, &wl_shm_interface, std::min(version, 1u)));
        } else if (std::strcmp(interface, ext_foreign_toplevel_list_v1_interface.name) == 0) {
            self->m_toplevelList = static_cast<ext_foreign_toplevel_list_v1*>(
                wl_registry_bind(registry, name,
                                 &ext_foreign_toplevel_list_v1_interface,
                                 std::min(version, 1u)));
        } else if (std::strcmp(
                       interface,
                       ext_foreign_toplevel_image_capture_source_manager_v1_interface.name) == 0) {
            self->m_sourceManager =
                static_cast<ext_foreign_toplevel_image_capture_source_manager_v1*>(
                    wl_registry_bind(
                        registry,
                        name,
                        &ext_foreign_toplevel_image_capture_source_manager_v1_interface,
                        std::min(version, 1u)));
        } else if (std::strcmp(interface, ext_image_copy_capture_manager_v1_interface.name) == 0) {
            self->m_captureManager = static_cast<ext_image_copy_capture_manager_v1*>(
                wl_registry_bind(registry, name,
                                 &ext_image_copy_capture_manager_v1_interface,
                                 std::min(version, 1u)));
        }
    }

    static void registryGlobalRemove(void*, wl_registry*, uint32_t) {}

    static void toplevelCreated(void* data,
                                ext_foreign_toplevel_list_v1*,
                                ext_foreign_toplevel_handle_v1* handle) {
        auto* self = static_cast<CaptureWorker*>(data);
        auto* top = new ToplevelState;
        top->owner = self;
        top->handle = handle;

        static const ext_foreign_toplevel_handle_v1_listener handleListener = {
            &CaptureWorker::toplevelClosed,
            &CaptureWorker::toplevelDone,
            &CaptureWorker::toplevelTitle,
            &CaptureWorker::toplevelAppId,
            &CaptureWorker::toplevelIdentifier,
        };
        ext_foreign_toplevel_handle_v1_add_listener(handle, &handleListener, top);
        self->m_toplevelByHandle.insert(handle, top);
    }

    static void toplevelListFinished(void* data, ext_foreign_toplevel_list_v1*) {
        auto* self = static_cast<CaptureWorker*>(data);
        self->publishBackendAvailability(false);
    }

    static void toplevelClosed(void* data, ext_foreign_toplevel_handle_v1* handle) {
        auto* top = static_cast<ToplevelState*>(data);
        CaptureWorker* self = top->owner;

        const QString identifier = top->identifier;
        QList<quint64> affected;
        for (auto it = self->m_sessions.cbegin(); it != self->m_sessions.cend(); ++it) {
            if (it.value()->identifier == identifier)
                affected.push_back(it.key());
        }
        for (quint64 token : affected) {
            self->publishSourceReady(token, false);
            self->destroySession(token);
        }

        if (!identifier.isEmpty())
            self->m_toplevels.remove(identifier);
        self->m_toplevelByHandle.remove(handle);
        ext_foreign_toplevel_handle_v1_destroy(handle);
        delete top;
    }

    static void toplevelDone(void*, ext_foreign_toplevel_handle_v1*) {}
    static void toplevelTitle(void*, ext_foreign_toplevel_handle_v1*, const char*) {}
    static void toplevelAppId(void*, ext_foreign_toplevel_handle_v1*, const char*) {}

    static void toplevelIdentifier(void* data,
                                   ext_foreign_toplevel_handle_v1*,
                                   const char* identifier) {
        auto* top = static_cast<ToplevelState*>(data);
        CaptureWorker* self = top->owner;

        if (!top->identifier.isEmpty())
            self->m_toplevels.remove(top->identifier);
        top->identifier = QString::fromUtf8(identifier);
        self->m_toplevels.insert(top->identifier, top);

        for (SessionState* state : std::as_const(self->m_sessions)) {
            if (state->identifier == top->identifier)
                self->ensureCaptureSession(state);
        }
    }

    static void sessionBufferSize(void* data,
                                  ext_image_copy_capture_session_v1*,
                                  uint32_t width,
                                  uint32_t height) {
        auto* state = static_cast<SessionState*>(data);
        if (state->width != width || state->height != height) {
            state->width = width;
            state->height = height;
            state->bufferNeedsFullDamage = true;
            state->constraintsReady = false;
        }
    }

    static void sessionShmFormat(void* data,
                                 ext_image_copy_capture_session_v1*,
                                 uint32_t format) {
        auto* state = static_cast<SessionState*>(data);
        if (format == WL_SHM_FORMAT_ARGB8888)
            state->supportsArgb = true;
        else if (format == WL_SHM_FORMAT_XRGB8888)
            state->supportsXrgb = true;
    }

    static void sessionDmabufDevice(void*,
                                    ext_image_copy_capture_session_v1*,
                                    wl_array*) {}
    static void sessionDmabufFormat(void*,
                                    ext_image_copy_capture_session_v1*,
                                    uint32_t,
                                    wl_array*) {}

    static void sessionDone(void* data, ext_image_copy_capture_session_v1*) {
        auto* state = static_cast<SessionState*>(data);
        CaptureWorker* self = state->owner;

        state->shmFormat = state->supportsArgb
            ? WL_SHM_FORMAT_ARGB8888
            : (state->supportsXrgb ? WL_SHM_FORMAT_XRGB8888 : 0);

        if (!state->shmFormat || state->width == 0 || state->height == 0) {
            self->publishError(state->token,
                               QStringLiteral("Niri preview capture has no supported SHM format"));
            self->publishSourceReady(state->token, false);
            return;
        }

        if (!self->allocateBuffer(state)) {
            self->publishError(state->token,
                               QStringLiteral("Unable to allocate Niri preview capture buffer"));
            self->publishSourceReady(state->token, false);
            return;
        }

        state->constraintsReady = true;
        self->publishSourceReady(state->token, true);
        self->requestFrame(state);
    }

    static void sessionStopped(void* data, ext_image_copy_capture_session_v1*) {
        auto* state = static_cast<SessionState*>(data);
        CaptureWorker* self = state->owner;
        const quint64 token = state->token;
        self->publishSourceReady(token, false);
        self->publishError(token, QStringLiteral("Niri ended the image-copy capture session"));
        self->destroySession(token);
    }

    static void frameTransform(void* data,
                               ext_image_copy_capture_frame_v1*,
                               uint32_t transform) {
        static_cast<SessionState*>(data)->transform = transform;
    }

    static void frameDamage(void* data,
                            ext_image_copy_capture_frame_v1*,
                            int32_t x,
                            int32_t y,
                            int32_t width,
                            int32_t height) {
        auto* state = static_cast<SessionState*>(data);
        if (width > 0 && height > 0)
            state->damage += QRect(x, y, width, height);
    }

    static void framePresentationTime(void*,
                                      ext_image_copy_capture_frame_v1*,
                                      uint32_t,
                                      uint32_t,
                                      uint32_t) {}

    static void frameReadyCallback(void* data, ext_image_copy_capture_frame_v1*) {
        auto* state = static_cast<SessionState*>(data);
        state->owner->handleFrameReady(state);
    }

    static void frameFailed(void* data,
                            ext_image_copy_capture_frame_v1*,
                            uint32_t reason) {
        auto* state = static_cast<SessionState*>(data);
        CaptureWorker* self = state->owner;

        if (state->frame) {
            ext_image_copy_capture_frame_v1_destroy(state->frame);
            state->frame = nullptr;
        }
        state->framePending = false;
        state->damage = QRegion();

        if (reason == EXT_IMAGE_COPY_CAPTURE_FRAME_V1_FAILURE_REASON_BUFFER_CONSTRAINTS) {
            state->constraintsReady = false;
            state->bufferNeedsFullDamage = true;
            self->releaseBuffer(state);
            return;
        }

        if (reason != EXT_IMAGE_COPY_CAPTURE_FRAME_V1_FAILURE_REASON_STOPPED)
            self->publishError(state->token,
                               QStringLiteral("Niri preview frame capture failed"));
    }

    void ensureCaptureSession(SessionState* state) {
        if (!m_display || !m_sourceManager || !m_captureManager || !state->active)
            return;
        if (state->session)
            return;

        ToplevelState* top = m_toplevels.value(state->identifier, nullptr);
        if (!top || !top->handle)
            return;

        state->source =
            ext_foreign_toplevel_image_capture_source_manager_v1_create_source(
                m_sourceManager, top->handle);
        if (!state->source)
            return;

        state->session = ext_image_copy_capture_manager_v1_create_session(
            m_captureManager, state->source, 0);
        if (!state->session) {
            ext_image_capture_source_v1_destroy(state->source);
            state->source = nullptr;
            return;
        }

        static const ext_image_copy_capture_session_v1_listener sessionListener = {
            &CaptureWorker::sessionBufferSize,
            &CaptureWorker::sessionShmFormat,
            &CaptureWorker::sessionDmabufDevice,
            &CaptureWorker::sessionDmabufFormat,
            &CaptureWorker::sessionDone,
            &CaptureWorker::sessionStopped,
        };
        ext_image_copy_capture_session_v1_add_listener(
            state->session, &sessionListener, state);
        wl_display_flush(m_display);
    }

    bool allocateBuffer(SessionState* state) {
        releaseBuffer(state);

        state->stride = static_cast<int>(state->width) * 4;
        state->mapSize = static_cast<size_t>(state->stride) * state->height;
        if (state->mapSize == 0)
            return false;

        state->memfd = memfd_create("inir-niri-preview", MFD_CLOEXEC);
        if (state->memfd < 0)
            return false;
        if (ftruncate(state->memfd, static_cast<off_t>(state->mapSize)) != 0) {
            releaseBuffer(state);
            return false;
        }

        state->map = mmap(nullptr,
                          state->mapSize,
                          PROT_READ | PROT_WRITE,
                          MAP_SHARED,
                          state->memfd,
                          0);
        if (state->map == MAP_FAILED) {
            releaseBuffer(state);
            return false;
        }

        wl_shm_pool* pool = wl_shm_create_pool(
            m_shm, state->memfd, static_cast<int>(state->mapSize));
        if (!pool) {
            releaseBuffer(state);
            return false;
        }

        state->buffer = wl_shm_pool_create_buffer(
            pool,
            0,
            static_cast<int>(state->width),
            static_cast<int>(state->height),
            state->stride,
            state->shmFormat);
        wl_shm_pool_destroy(pool);

        if (!state->buffer) {
            releaseBuffer(state);
            return false;
        }

        state->bufferNeedsFullDamage = true;
        return true;
    }

    void releaseBuffer(SessionState* state) {
        if (state->buffer) {
            wl_buffer_destroy(state->buffer);
            state->buffer = nullptr;
        }
        if (state->map != MAP_FAILED) {
            munmap(state->map, state->mapSize);
            state->map = MAP_FAILED;
        }
        if (state->memfd >= 0) {
            close(state->memfd);
            state->memfd = -1;
        }
        state->mapSize = 0;
        state->stride = 0;
    }

    void requestFrame(SessionState* state) {
        if (!state || !state->active)
            return;
        ensureCaptureSession(state);
        if (!state->session || !state->constraintsReady || !state->buffer)
            return;
        if (state->framePending || state->frame)
            return;

        const qint64 now = m_clock.elapsed();
        const qint64 minInterval = std::max<qint64>(1, 1000 / state->maxFps);
        if (state->live && now - state->lastCaptureMs < minInterval)
            return;

        state->damage = QRegion();
        state->transform = WL_OUTPUT_TRANSFORM_NORMAL;
        state->frame = ext_image_copy_capture_session_v1_create_frame(state->session);
        if (!state->frame)
            return;

        static const ext_image_copy_capture_frame_v1_listener frameListener = {
            &CaptureWorker::frameTransform,
            &CaptureWorker::frameDamage,
            &CaptureWorker::framePresentationTime,
            &CaptureWorker::frameReadyCallback,
            &CaptureWorker::frameFailed,
        };
        ext_image_copy_capture_frame_v1_add_listener(
            state->frame, &frameListener, state);
        ext_image_copy_capture_frame_v1_attach_buffer(
            state->frame, state->buffer);

        if (state->bufferNeedsFullDamage) {
            ext_image_copy_capture_frame_v1_damage_buffer(
                state->frame,
                0,
                0,
                static_cast<int>(state->width),
                static_cast<int>(state->height));
        }

        ext_image_copy_capture_frame_v1_capture(state->frame);
        state->framePending = true;
        state->lastCaptureMs = now;
        wl_display_flush(m_display);
    }

    void handleFrameReady(SessionState* state) {
        if (!state || !state->frame)
            return;

        ext_image_copy_capture_frame_v1_destroy(state->frame);
        state->frame = nullptr;
        state->framePending = false;
        state->bufferNeedsFullDamage = false;

        const QImage::Format format =
            state->shmFormat == WL_SHM_FORMAT_ARGB8888
                ? QImage::Format_ARGB32_Premultiplied
                : QImage::Format_RGB32;

        QImage mapped(static_cast<uchar*>(state->map),
                      static_cast<int>(state->width),
                      static_cast<int>(state->height),
                      state->stride,
                      format);

        QImage owned = mapped.copy();
        owned = applyTransform(owned, state->transform);
        owned = cropScaleFrame(owned, state->targetSize);

        qint64 damagedPixels = 0;
        for (const QRect& rect : state->damage)
            damagedPixels += static_cast<qint64>(rect.width()) * rect.height();

        const qint64 totalPixels =
            static_cast<qint64>(state->width) * state->height;
        qreal activity = totalPixels > 0
            ? static_cast<qreal>(damagedPixels) / static_cast<qreal>(totalPixels)
            : 0.0;
        activity = std::clamp<qreal>(activity, 0.0, 1.0);

        if (state->firstFrame) {
            activity = 0.0;
            state->firstFrame = false;
        }

        state->damage = QRegion();
        publishFrame(state->token,
                     owned,
                     activity,
                     QSize(static_cast<int>(state->width),
                           static_cast<int>(state->height)));

        if (state->live)
            requestFrame(state);
    }

    void pumpLiveSessions() {
        if (!m_display)
            return;
        for (SessionState* state : std::as_const(m_sessions)) {
            if (state->live && state->active)
                requestFrame(state);
        }
    }

    void destroySession(quint64 token) {
        auto it = m_sessions.find(token);
        if (it == m_sessions.end())
            return;

        SessionState* state = it.value();
        m_sessions.erase(it);

        if (state->frame) {
            ext_image_copy_capture_frame_v1_destroy(state->frame);
            state->frame = nullptr;
        }
        if (state->session) {
            ext_image_copy_capture_session_v1_destroy(state->session);
            state->session = nullptr;
        }
        if (state->source) {
            ext_image_capture_source_v1_destroy(state->source);
            state->source = nullptr;
        }
        releaseBuffer(state);
        delete state;

        if (m_display)
            wl_display_flush(m_display);
    }

    void shutdown() {
        m_pump.stop();

        const QList<quint64> tokens = m_sessions.keys();
        for (quint64 token : tokens)
            destroySession(token);

        for (ToplevelState* top : std::as_const(m_toplevelByHandle)) {
            if (top->handle)
                ext_foreign_toplevel_handle_v1_destroy(top->handle);
            delete top;
        }
        m_toplevelByHandle.clear();
        m_toplevels.clear();

        if (m_notifier) {
            delete m_notifier;
            m_notifier = nullptr;
        }
        if (m_toplevelList) {
            ext_foreign_toplevel_list_v1_destroy(m_toplevelList);
            m_toplevelList = nullptr;
        }
        if (m_sourceManager) {
            ext_foreign_toplevel_image_capture_source_manager_v1_destroy(
                m_sourceManager);
            m_sourceManager = nullptr;
        }
        if (m_captureManager) {
            ext_image_copy_capture_manager_v1_destroy(m_captureManager);
            m_captureManager = nullptr;
        }
        if (m_shm) {
            wl_shm_destroy(m_shm);
            m_shm = nullptr;
        }
        if (m_registry) {
            wl_registry_destroy(m_registry);
            m_registry = nullptr;
        }
        if (m_display) {
            wl_display_disconnect(m_display);
            m_display = nullptr;
        }
    }

    void publishBackendAvailability(bool available) {
        QMetaObject::invokeMethod(
            m_broker,
            [broker = m_broker, available] { broker->setAvailable(available); },
            Qt::QueuedConnection);
    }

    void publishSourceReady(quint64 token, bool ready) {
        QMetaObject::invokeMethod(
            m_broker,
            [broker = m_broker, token, ready] {
                emit broker->sourceReady(token, ready);
            },
            Qt::QueuedConnection);
    }

    void publishFrame(quint64 token,
                      const QImage& frame,
                      qreal activity,
                      const QSize& sourceSize) {
        QMetaObject::invokeMethod(
            m_broker,
            [broker = m_broker, token, frame, activity, sourceSize] {
                emit broker->frameReady(token, frame, activity, sourceSize);
            },
            Qt::QueuedConnection);
    }

    void publishError(quint64 token, const QString& message) {
        QMetaObject::invokeMethod(
            m_broker,
            [broker = m_broker, token, message] {
                emit broker->captureError(token, message);
            },
            Qt::QueuedConnection);
    }

    CaptureBroker* m_broker = nullptr;
    wl_display* m_display = nullptr;
    wl_registry* m_registry = nullptr;
    wl_shm* m_shm = nullptr;
    ext_foreign_toplevel_list_v1* m_toplevelList = nullptr;
    ext_foreign_toplevel_image_capture_source_manager_v1* m_sourceManager = nullptr;
    ext_image_copy_capture_manager_v1* m_captureManager = nullptr;
    QSocketNotifier* m_notifier = nullptr;

    QHash<QString, ToplevelState*> m_toplevels;
    QHash<ext_foreign_toplevel_handle_v1*, ToplevelState*> m_toplevelByHandle;
    QHash<quint64, SessionState*> m_sessions;

    QElapsedTimer m_clock;
    QTimer m_pump;
};

CaptureBroker* CaptureBroker::instance() {
    static auto* broker = new CaptureBroker;
    return broker;
}

CaptureBroker::CaptureBroker(QObject* parent)
    : QObject(parent) {
    m_worker = new CaptureWorker(this);
    m_worker->moveToThread(&m_thread);
    connect(&m_thread, &QThread::started, m_worker, [worker = m_worker] {
        worker->initialize();
    });
    connect(&m_thread, &QThread::finished, m_worker, &QObject::deleteLater);
    m_thread.setObjectName(QStringLiteral("HadalisNiriPreview"));
    m_thread.start();
}

CaptureBroker::~CaptureBroker() {
    if (m_worker && m_thread.isRunning()) {
        QMetaObject::invokeMethod(
            m_worker,
            [worker = m_worker] { worker->stop(); },
            Qt::BlockingQueuedConnection);
    }
    m_thread.quit();
    m_thread.wait(2000);
    m_worker = nullptr;
}

void CaptureBroker::setAvailable(bool available) {
    if (m_available == available)
        return;
    m_available = available;
    emit backendAvailableChanged(available);
}

void CaptureBroker::updateConsumer(quint64 token,
                                   const QString& identifier,
                                   bool active,
                                   bool live,
                                   int maxFps,
                                   const QSize& targetSize) {
    if (!m_worker)
        return;
    QMetaObject::invokeMethod(
        m_worker,
        [worker = m_worker,
         token,
         identifier,
         active,
         live,
         maxFps,
         targetSize] {
            worker->updateConsumer(
                token, identifier, active, live, maxFps, targetSize);
        },
        Qt::QueuedConnection);
}

void CaptureBroker::captureOnce(quint64 token) {
    if (!m_worker)
        return;
    QMetaObject::invokeMethod(
        m_worker,
        [worker = m_worker, token] { worker->captureOnce(token); },
        Qt::QueuedConnection);
}

void CaptureBroker::unregisterConsumer(quint64 token) {
    if (!m_worker)
        return;
    QMetaObject::invokeMethod(
        m_worker,
        [worker = m_worker, token] { worker->unregisterConsumer(token); },
        Qt::QueuedConnection);
}
