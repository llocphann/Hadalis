#include "capture_backend.hpp"

#include <QByteArray>
#include <QDBusConnection>
#include <QDBusConnectionInterface>
#include <QDBusError>
#include <QDBusInterface>
#include <QDBusMessage>
#include <QDBusObjectPath>
#include <QDBusReply>
#include <QHash>
#include <QMetaObject>
#include <QTimer>
#include <QVariantMap>
#include <QtGlobal>

#include <algorithm>
#include <chrono>
#include <cmath>
#include <cstdint>
#include <cstring>

extern "C" {
#include <pipewire/pipewire.h>
#include <spa/param/video/format-utils.h>
#include <spa/param/video/raw.h>
#include <spa/pod/builder.h>
}

namespace {

constexpr auto kScreenCastService = "org.gnome.Mutter.ScreenCast";
constexpr auto kScreenCastRootPath = "/org/gnome/Mutter/ScreenCast";
constexpr auto kScreenCastRootInterface = "org.gnome.Mutter.ScreenCast";
constexpr auto kScreenCastSessionInterface = "org.gnome.Mutter.ScreenCast.Session";
constexpr auto kScreenCastStreamInterface = "org.gnome.Mutter.ScreenCast.Stream";

constexpr int kDefaultPreviewWidth = 640;
constexpr int kDefaultPreviewHeight = 360;
constexpr int kMinPreviewDimension = 32;
constexpr int kMaxPreviewDimension = 1024;
constexpr int kMotionSampleColumns = 48;
constexpr int kMotionSampleRows = 27;
constexpr int kMotionDeltaThreshold = 10;

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
        return scaled.copy();

    return scaled.copy(
        x,
        y,
        std::min(target.width(), scaled.width() - x),
        std::min(target.height(), scaled.height() - y));
}

qint64 monotonicMilliseconds() {
    return std::chrono::duration_cast<std::chrono::milliseconds>(
               std::chrono::steady_clock::now().time_since_epoch())
        .count();
}

QByteArray sampleLuma(const uchar* base,
                      int width,
                      int height,
                      int stride) {
    QByteArray sample;
    sample.resize(kMotionSampleColumns * kMotionSampleRows);
    if (!base || width <= 0 || height <= 0 || stride == 0) {
        sample.fill(0);
        return sample;
    }

    const int rowStride = std::abs(stride);
    for (int sy = 0; sy < kMotionSampleRows; ++sy) {
        const int y = std::clamp(
            ((sy * 2 + 1) * height) / (kMotionSampleRows * 2),
            0,
            height - 1);
        const uchar* row = stride > 0
            ? base + y * rowStride
            : base + (height - 1 - y) * rowStride;

        for (int sx = 0; sx < kMotionSampleColumns; ++sx) {
            const int x = std::clamp(
                ((sx * 2 + 1) * width) / (kMotionSampleColumns * 2),
                0,
                width - 1);
            const uchar* pixel = row + x * 4;
            const int b = pixel[0];
            const int g = pixel[1];
            const int r = pixel[2];
            const int luma = (19 * b + 183 * g + 54 * r) >> 8;
            sample[sy * kMotionSampleColumns + sx] = static_cast<char>(luma);
        }
    }
    return sample;
}

qreal motionScore(const QByteArray& previous, const QByteArray& current) {
    if (previous.size() != current.size() || current.isEmpty())
        return 0.0;

    int changed = 0;
    qint64 deltaSum = 0;
    for (qsizetype i = 0; i < current.size(); ++i) {
        const int a = static_cast<unsigned char>(previous.at(i));
        const int b = static_cast<unsigned char>(current.at(i));
        const int delta = std::abs(a - b);
        deltaSum += delta;
        if (delta >= kMotionDeltaThreshold)
            ++changed;
    }

    const qreal changedRatio =
        static_cast<qreal>(changed) / static_cast<qreal>(current.size());
    const qreal averageDelta =
        static_cast<qreal>(deltaSum)
        / (static_cast<qreal>(current.size()) * 255.0);

    return std::clamp<qreal>(
        changedRatio * 0.78 + averageDelta * 0.22,
        0.0,
        1.0);
}

} // namespace

class CaptureWorker;

class StreamWatcher final : public QObject {
    Q_OBJECT

public:
    StreamWatcher(CaptureWorker* owner, quint64 token, QObject* parent = nullptr)
        : QObject(parent)
        , m_owner(owner)
        , m_token(token) {}

public slots:
    void onPipeWireStreamAdded(uint nodeId);

private:
    CaptureWorker* m_owner = nullptr;
    quint64 m_token = 0;
};

class CaptureWorker final : public QObject {
public:
    explicit CaptureWorker(CaptureBroker* broker)
        : m_broker(broker)
        , m_bus(QDBusConnection::sessionBus()) {}

    ~CaptureWorker() override {
        shutdown();
    }

    void initialize() {
        if (!m_bus.isConnected()) {
            publishBackendAvailability(false);
            return;
        }

        auto* busInterface = m_bus.interface();
        if (!busInterface) {
            publishBackendAvailability(false);
            return;
        }

        const QDBusReply<bool> service =
            busInterface->isServiceRegistered(QString::fromLatin1(kScreenCastService));
        if (!service.isValid() || !service.value()) {
            publishBackendAvailability(false);
            return;
        }

        pw_init(nullptr, nullptr);
        m_pwLoop = pw_thread_loop_new("HadalisNiriPreview", nullptr);
        if (!m_pwLoop || pw_thread_loop_start(m_pwLoop) < 0) {
            if (m_pwLoop) {
                pw_thread_loop_destroy(m_pwLoop);
                m_pwLoop = nullptr;
            }
            publishBackendAvailability(false);
            return;
        }

        publishBackendAvailability(true);
    }

    void updateConsumer(quint64 token,
                        quint64 windowId,
                        bool active,
                        bool live,
                        int maxFps,
                        const QSize& targetSize) {
        auto it = m_sessions.find(token);

        if (!active || windowId == 0) {
            if (it != m_sessions.end()) {
                publishSourceReady(token, false);
                destroySession(token);
            }
            return;
        }

        maxFps = std::clamp(maxFps, 1, 30);
        const QSize boundedSize = boundedTargetSize(targetSize);

        if (it == m_sessions.end()) {
            auto* state = new SessionState;
            state->owner = this;
            state->token = token;
            state->windowId = windowId;
            state->active = true;
            state->live = live;
            state->maxFps = maxFps;
            state->targetSize = boundedSize;
            state->wantOneShot = true;
            m_sessions.insert(token, state);
            createScreenCast(state);
            return;
        }

        SessionState* state = it.value();
        if (state->windowId != windowId) {
            publishSourceReady(token, false);
            destroySession(token);
            updateConsumer(token, windowId, active, live, maxFps, boundedSize);
            return;
        }

        const bool fpsChanged = state->maxFps != maxFps;
        const bool liveChanged = state->live != live;

        if (m_pwLoop)
            pw_thread_loop_lock(m_pwLoop);

        state->active = active;
        state->live = live;
        state->maxFps = maxFps;
        state->targetSize = boundedSize;
        if (liveChanged && !live)
            state->wantOneShot = true;

        if (m_pwLoop)
            pw_thread_loop_unlock(m_pwLoop);

        // Niri honors the negotiated max framerate. Reconnect only the
        // PipeWire consumer when probe/live cadence changes; the D-Bus window
        // cast session and its node stay alive.
        if (fpsChanged && state->nodeId != PW_ID_ANY) {
            destroyPipeWireStream(state);
            startPipeWireStream(state);
        }
    }

    void captureOnce(quint64 token) {
        auto it = m_sessions.find(token);
        if (it == m_sessions.end())
            return;

        SessionState* state = it.value();
        if (m_pwLoop)
            pw_thread_loop_lock(m_pwLoop);
        state->wantOneShot = true;
        if (m_pwLoop)
            pw_thread_loop_unlock(m_pwLoop);
    }

    void unregisterConsumer(quint64 token) {
        destroySession(token);
    }

    void stop() {
        shutdown();
        publishBackendAvailability(false);
    }

    void handlePipeWireNode(quint64 token, uint32_t nodeId) {
        auto it = m_sessions.find(token);
        if (it == m_sessions.end())
            return;

        SessionState* state = it.value();
        if (state->nodeId == nodeId && state->pwStream)
            return;

        state->nodeId = nodeId;
        destroyPipeWireStream(state);
        startPipeWireStream(state);
    }

private:
    struct SessionState {
        CaptureWorker* owner = nullptr;
        quint64 token = 0;
        quint64 windowId = 0;
        bool active = false;
        bool live = false;
        int maxFps = 18;
        QSize targetSize;
        bool wantOneShot = true;

        QString sessionPath;
        QString streamPath;
        QDBusInterface* sessionInterface = nullptr;
        StreamWatcher* watcher = nullptr;

        uint32_t nodeId = PW_ID_ANY;
        pw_stream* pwStream = nullptr;
        spa_video_info_raw format{};
        bool formatReady = false;
        qint64 lastEmitMs = 0;
        QByteArray previousSample;
    };

    static const pw_stream_events& streamEvents() {
        static const pw_stream_events events = [] {
            pw_stream_events value{};
            value.version = PW_VERSION_STREAM_EVENTS;
            value.state_changed = &CaptureWorker::pipeWireStateChanged;
            value.param_changed = &CaptureWorker::pipeWireParamChanged;
            value.process = &CaptureWorker::pipeWireProcess;
            return value;
        }();
        return events;
    }

    void createScreenCast(SessionState* state) {
        if (!state || !m_bus.isConnected()) {
            if (state)
                publishError(state->token, QStringLiteral("Niri ScreenCast D-Bus is unavailable"));
            return;
        }

        QDBusInterface root(
            QString::fromLatin1(kScreenCastService),
            QString::fromLatin1(kScreenCastRootPath),
            QString::fromLatin1(kScreenCastRootInterface),
            m_bus);
        if (!root.isValid()) {
            publishError(
                state->token,
                QStringLiteral("Niri org.gnome.Mutter.ScreenCast is unavailable"));
            return;
        }

        const QDBusReply<QDBusObjectPath> sessionReply =
            root.call(QStringLiteral("CreateSession"), QVariantMap{});
        if (!sessionReply.isValid()) {
            publishError(
                state->token,
                QStringLiteral("CreateSession failed: %1")
                    .arg(sessionReply.error().message()));
            return;
        }

        state->sessionPath = sessionReply.value().path();
        state->sessionInterface = new QDBusInterface(
            QString::fromLatin1(kScreenCastService),
            state->sessionPath,
            QString::fromLatin1(kScreenCastSessionInterface),
            m_bus,
            this);

        if (!state->sessionInterface->isValid()) {
            publishError(
                state->token,
                QStringLiteral("Niri ScreenCast session interface is invalid"));
            destroySession(state->token);
            return;
        }

        QVariantMap properties;
        properties.insert(
            QStringLiteral("window-id"),
            QVariant::fromValue<qulonglong>(state->windowId));

        const QDBusReply<QDBusObjectPath> streamReply =
            state->sessionInterface->call(QStringLiteral("RecordWindow"), properties);
        if (!streamReply.isValid()) {
            publishError(
                state->token,
                QStringLiteral("RecordWindow(%1) failed: %2")
                    .arg(state->windowId)
                    .arg(streamReply.error().message()));
            destroySession(state->token);
            return;
        }

        state->streamPath = streamReply.value().path();
        state->watcher = new StreamWatcher(this, state->token, this);
        const bool connected = m_bus.connect(
            QString::fromLatin1(kScreenCastService),
            state->streamPath,
            QString::fromLatin1(kScreenCastStreamInterface),
            QStringLiteral("PipeWireStreamAdded"),
            state->watcher,
            SLOT(onPipeWireStreamAdded(uint)));

        if (!connected) {
            publishError(
                state->token,
                QStringLiteral("Could not subscribe to PipeWireStreamAdded"));
            destroySession(state->token);
            return;
        }

        const QDBusMessage startReply =
            state->sessionInterface->call(QStringLiteral("Start"));
        if (startReply.type() == QDBusMessage::ErrorMessage) {
            publishError(
                state->token,
                QStringLiteral("Niri ScreenCast Start failed: %1")
                    .arg(startReply.errorMessage()));
            destroySession(state->token);
            return;
        }

        const quint64 token = state->token;
        QTimer::singleShot(2500, this, [this, token] {
            auto it = m_sessions.find(token);
            if (it == m_sessions.end())
                return;
            SessionState* pending = it.value();
            if (pending->nodeId != PW_ID_ANY)
                return;
            publishError(
                token,
                QStringLiteral("Niri did not publish a PipeWire node for this window"));
            publishSourceReady(token, false);
        });
    }

    void startPipeWireStream(SessionState* state) {
        if (!state || !m_pwLoop || state->nodeId == PW_ID_ANY)
            return;

        pw_thread_loop_lock(m_pwLoop);

        QByteArray targetId = QByteArray::number(state->nodeId);
        pw_properties* properties = pw_properties_new(
            PW_KEY_MEDIA_TYPE, "Video",
            PW_KEY_MEDIA_CATEGORY, "Capture",
            PW_KEY_MEDIA_ROLE, "Screen",
            PW_KEY_TARGET_OBJECT, targetId.constData(),
            nullptr);

        state->format = {};
        state->formatReady = false;
        state->wantOneShot = true;
        state->lastEmitMs = 0;

        state->pwStream = pw_stream_new_simple(
            pw_thread_loop_get_loop(m_pwLoop),
            "hadalis-niri-window-preview",
            properties,
            &streamEvents(),
            state);

        if (!state->pwStream) {
            pw_thread_loop_unlock(m_pwLoop);
            publishError(
                state->token,
                QStringLiteral("Could not create PipeWire preview stream"));
            return;
        }

        uint8_t podBuffer[1024];
        spa_pod_builder builder =
            SPA_POD_BUILDER_INIT(podBuffer, sizeof(podBuffer));

        const spa_rectangle defaultSize = SPA_RECTANGLE(1280, 720);
        const spa_rectangle minSize = SPA_RECTANGLE(1, 1);
        const spa_rectangle maxSize = SPA_RECTANGLE(16384, 16384);
        const spa_fraction defaultRate =
            SPA_FRACTION(static_cast<uint32_t>(state->maxFps), 1);
        const spa_fraction minRate = SPA_FRACTION(0, 1);
        const spa_fraction maxRate =
            SPA_FRACTION(static_cast<uint32_t>(state->maxFps), 1);

        const spa_pod* params[1];
        params[0] = static_cast<const spa_pod*>(spa_pod_builder_add_object(
            &builder,
            SPA_TYPE_OBJECT_Format,
            SPA_PARAM_EnumFormat,
            SPA_FORMAT_mediaType,
            SPA_POD_Id(SPA_MEDIA_TYPE_video),
            SPA_FORMAT_mediaSubtype,
            SPA_POD_Id(SPA_MEDIA_SUBTYPE_raw),
            SPA_FORMAT_VIDEO_format,
            SPA_POD_CHOICE_ENUM_Id(
                3,
                SPA_VIDEO_FORMAT_BGRx,
                SPA_VIDEO_FORMAT_BGRx,
                SPA_VIDEO_FORMAT_BGRA),
            SPA_FORMAT_VIDEO_size,
            SPA_POD_CHOICE_RANGE_Rectangle(&defaultSize, &minSize, &maxSize),
            SPA_FORMAT_VIDEO_framerate,
            SPA_POD_CHOICE_RANGE_Fraction(&defaultRate, &minRate, &maxRate)));

        const int result = pw_stream_connect(
            state->pwStream,
            PW_DIRECTION_INPUT,
            PW_ID_ANY,
            static_cast<pw_stream_flags>(
                PW_STREAM_FLAG_AUTOCONNECT | PW_STREAM_FLAG_MAP_BUFFERS),
            params,
            1);

        if (result < 0) {
            pw_stream_destroy(state->pwStream);
            state->pwStream = nullptr;
            pw_thread_loop_unlock(m_pwLoop);
            publishError(
                state->token,
                QStringLiteral("Could not connect PipeWire preview stream"));
            return;
        }

        pw_thread_loop_unlock(m_pwLoop);
    }

    void destroyPipeWireStream(SessionState* state) {
        if (!state || !state->pwStream || !m_pwLoop)
            return;

        pw_thread_loop_lock(m_pwLoop);
        pw_stream_destroy(state->pwStream);
        state->pwStream = nullptr;
        state->formatReady = false;
        pw_thread_loop_unlock(m_pwLoop);
    }

    void destroySession(quint64 token) {
        auto it = m_sessions.find(token);
        if (it == m_sessions.end())
            return;

        SessionState* state = it.value();
        m_sessions.erase(it);

        destroyPipeWireStream(state);

        if (state->watcher) {
            m_bus.disconnect(
                QString::fromLatin1(kScreenCastService),
                state->streamPath,
                QString::fromLatin1(kScreenCastStreamInterface),
                QStringLiteral("PipeWireStreamAdded"),
                state->watcher,
                SLOT(onPipeWireStreamAdded(uint)));
            delete state->watcher;
            state->watcher = nullptr;
        }

        if (state->sessionInterface) {
            state->sessionInterface->call(QDBus::NoBlock, QStringLiteral("Stop"));
            delete state->sessionInterface;
            state->sessionInterface = nullptr;
        }

        delete state;
    }

    static void pipeWireStateChanged(void* data,
                                     pw_stream_state,
                                     pw_stream_state state,
                                     const char* error) {
        auto* session = static_cast<SessionState*>(data);
        if (!session || !session->owner)
            return;

        if (state == PW_STREAM_STATE_PAUSED
                || state == PW_STREAM_STATE_STREAMING) {
            session->owner->publishSourceReady(session->token, true);
        } else if (state == PW_STREAM_STATE_ERROR) {
            session->owner->publishSourceReady(session->token, false);
            session->owner->publishError(
                session->token,
                QStringLiteral("PipeWire preview error: %1")
                    .arg(QString::fromUtf8(error ? error : "unknown error")));
        }
    }

    static void pipeWireParamChanged(void* data,
                                     uint32_t id,
                                     const spa_pod* param) {
        auto* state = static_cast<SessionState*>(data);
        if (!state || !param || id != SPA_PARAM_Format)
            return;

        spa_video_info_raw raw{};
        if (spa_format_video_raw_parse(param, &raw) < 0)
            return;

        if (raw.format != SPA_VIDEO_FORMAT_BGRx
                && raw.format != SPA_VIDEO_FORMAT_BGRA)
            return;

        state->format = raw;
        state->formatReady = true;
        state->previousSample.clear();
    }

    static void pipeWireProcess(void* data) {
        auto* state = static_cast<SessionState*>(data);
        if (!state || !state->pwStream)
            return;

        pw_buffer* buffer = pw_stream_dequeue_buffer(state->pwStream);
        if (!buffer)
            return;

        spa_buffer* spaBuffer = buffer->buffer;
        if (!spaBuffer || spaBuffer->n_datas < 1 || !state->formatReady) {
            pw_stream_queue_buffer(state->pwStream, buffer);
            return;
        }

        spa_data& plane = spaBuffer->datas[0];
        if (!plane.data || !plane.chunk) {
            pw_stream_queue_buffer(state->pwStream, buffer);
            return;
        }

        const int width = static_cast<int>(state->format.size.width);
        const int height = static_cast<int>(state->format.size.height);
        int stride = plane.chunk->stride;
        if (stride == 0)
            stride = width * 4;

        if (width <= 0 || height <= 0 || std::abs(stride) < width * 4) {
            pw_stream_queue_buffer(state->pwStream, buffer);
            return;
        }

        const qint64 now = monotonicMilliseconds();
        const qint64 minInterval =
            std::max<qint64>(1, 1000 / std::max(1, state->maxFps));

        const bool requested = state->live || state->wantOneShot;
        if (!requested || now - state->lastEmitMs < minInterval) {
            pw_stream_queue_buffer(state->pwStream, buffer);
            return;
        }

        const auto* bytes =
            static_cast<const uchar*>(plane.data) + plane.chunk->offset;

        const QByteArray sample = sampleLuma(bytes, width, height, stride);
        const qreal activity = motionScore(state->previousSample, sample);
        state->previousSample = sample;

        const QImage::Format imageFormat =
            state->format.format == SPA_VIDEO_FORMAT_BGRA
                ? QImage::Format_ARGB32
                : QImage::Format_RGB32;

        QImage view(
            bytes,
            width,
            height,
            stride,
            imageFormat);
        QImage frame = cropScaleFrame(view, state->targetSize);

        state->lastEmitMs = now;
        if (!state->live)
            state->wantOneShot = false;

        state->owner->publishFrame(
            state->token,
            frame,
            activity,
            QSize(width, height));

        pw_stream_queue_buffer(state->pwStream, buffer);
    }

    void shutdown() {
        const QList<quint64> tokens = m_sessions.keys();
        for (quint64 token : tokens)
            destroySession(token);

        if (m_pwLoop) {
            pw_thread_loop_stop(m_pwLoop);
            pw_thread_loop_destroy(m_pwLoop);
            m_pwLoop = nullptr;
        }
    }

    void publishBackendAvailability(bool available) {
        QMetaObject::invokeMethod(
            m_broker,
            [broker = m_broker, available] {
                broker->setAvailable(available);
            },
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
    QDBusConnection m_bus;
    pw_thread_loop* m_pwLoop = nullptr;
    QHash<quint64, SessionState*> m_sessions;

    friend class StreamWatcher;
};

void StreamWatcher::onPipeWireStreamAdded(uint nodeId) {
    if (m_owner)
        m_owner->handlePipeWireNode(m_token, nodeId);
}

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
                                   quint64 windowId,
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
         windowId,
         active,
         live,
         maxFps,
         targetSize] {
            worker->updateConsumer(
                token, windowId, active, live, maxFps, targetSize);
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

#include "capture_backend.moc"
