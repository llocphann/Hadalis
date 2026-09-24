#include "niri_preview_item.hpp"

#include "capture_backend.hpp"

#include <QAtomicInteger>
#include <QMutexLocker>
#include <QQuickWindow>
#include <QSGSimpleTextureNode>
#include <QSGTexture>

#include <algorithm>

namespace {
QAtomicInteger<quint64> s_nextToken = 1;
}

NiriPreviewItem::NiriPreviewItem(QQuickItem* parent)
    : QQuickItem(parent)
    , m_token(s_nextToken.fetchAndAddRelaxed(1)) {
    setFlag(ItemHasContents, true);

    auto* broker = CaptureBroker::instance();
    m_available = broker->available();

    connect(broker,
            &CaptureBroker::backendAvailableChanged,
            this,
            [this](bool available) {
                if (m_available == available)
                    return;
                m_available = available;
                emit availableChanged();
                syncConsumer();
            });

    connect(broker,
            &CaptureBroker::sourceReady,
            this,
            [this](quint64 token, bool ready) {
                if (token != m_token || m_sourceReady == ready)
                    return;
                m_sourceReady = ready;
                emit sourceReadyChanged();
            });

    connect(broker,
            &CaptureBroker::frameReady,
            this,
            [this](quint64 token,
                   const QImage& frame,
                   qreal activity,
                   const QSize& sourceSize) {
                if (token != m_token)
                    return;

                {
                    QMutexLocker locker(&m_frameMutex);
                    m_frame = frame;
                }

                const bool hadContent = m_hasContent;
                m_hasContent = !frame.isNull();
                if (hadContent != m_hasContent)
                    emit hasContentChanged();

                if (!qFuzzyCompare(m_activity + 1.0, activity + 1.0)) {
                    m_activity = activity;
                    emit activityChanged();
                }

                if (m_sourceSize != sourceSize) {
                    m_sourceSize = sourceSize;
                    emit sourceSizeChanged();
                }

                if (!m_errorString.isEmpty())
                    setErrorString({});

                update();
                emit frameCaptured();
            });

    connect(broker,
            &CaptureBroker::captureError,
            this,
            [this](quint64 token, const QString& message) {
                if (token == m_token)
                    setErrorString(message);
            });
}

NiriPreviewItem::~NiriPreviewItem() {
    CaptureBroker::instance()->unregisterConsumer(m_token);
}

void NiriPreviewItem::setWindowId(qulonglong value) {
    if (m_windowId == value)
        return;
    m_windowId = value;
    emit windowIdChanged();

    {
        QMutexLocker locker(&m_frameMutex);
        m_frame = {};
    }
    if (m_hasContent) {
        m_hasContent = false;
        emit hasContentChanged();
    }
    if (m_sourceReady) {
        m_sourceReady = false;
        emit sourceReadyChanged();
    }
    if (!qFuzzyIsNull(m_activity)) {
        m_activity = 0.0;
        emit activityChanged();
    }
    if (!m_sourceSize.isEmpty()) {
        m_sourceSize = {};
        emit sourceSizeChanged();
    }
    syncConsumer();
}

void NiriPreviewItem::setActive(bool value) {
    if (m_active == value)
        return;
    m_active = value;
    emit activeChanged();
    syncConsumer();
}

void NiriPreviewItem::setLive(bool value) {
    if (m_live == value)
        return;
    m_live = value;
    emit liveChanged();
    syncConsumer();
}

void NiriPreviewItem::setMaxFps(int value) {
    value = std::clamp(value, 1, 30);
    if (m_maxFps == value)
        return;
    m_maxFps = value;
    emit maxFpsChanged();
    syncConsumer();
}

void NiriPreviewItem::captureOnce() {
    if (!m_complete || !m_active || m_windowId == 0)
        return;
    CaptureBroker::instance()->captureOnce(m_token);
}

void NiriPreviewItem::componentComplete() {
    QQuickItem::componentComplete();
    m_complete = true;
    syncConsumer();
}

void NiriPreviewItem::geometryChange(const QRectF& newGeometry,
                                     const QRectF& oldGeometry) {
    QQuickItem::geometryChange(newGeometry, oldGeometry);
    if (newGeometry.size() != oldGeometry.size())
        syncConsumer();
}

QSize NiriPreviewItem::targetPixelSize() const {
    qreal ratio = 1.0;
    if (window())
        ratio = window()->devicePixelRatio();

    return QSize(
        std::max(1, qRound(width() * ratio)),
        std::max(1, qRound(height() * ratio)));
}

void NiriPreviewItem::syncConsumer() {
    if (!m_complete)
        return;

    CaptureBroker::instance()->updateConsumer(
        m_token,
        QString::number(m_windowId),
        m_active && m_available && m_windowId != 0,
        m_live,
        m_maxFps,
        targetPixelSize());
}

void NiriPreviewItem::setErrorString(const QString& value) {
    if (m_errorString == value)
        return;
    m_errorString = value;
    emit errorStringChanged();
}

QSGNode* NiriPreviewItem::updatePaintNode(QSGNode* oldNode,
                                          UpdatePaintNodeData*) {
    QImage frame;
    {
        QMutexLocker locker(&m_frameMutex);
        frame = m_frame;
    }

    if (frame.isNull() || !window()) {
        delete oldNode;
        return nullptr;
    }

    // QSG owns textures on the render thread. Replacing the whole node keeps
    // texture destruction on that thread as well and avoids leaking the final
    // texture when the preview item disappears.
    delete oldNode;
    auto* node = new QSGSimpleTextureNode;
    node->setTexture(window()->createTextureFromImage(frame));
    node->setOwnsTexture(true);
    node->setRect(boundingRect());
    node->setFiltering(QSGTexture::Linear);
    return node;
}
