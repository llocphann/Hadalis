#pragma once

#include <QImage>
#include <QMutex>
#include <QQuickItem>
#include <QSize>
#include <qqmlintegration.h>

class NiriPreviewItem : public QQuickItem {
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(qulonglong windowId READ windowId WRITE setWindowId NOTIFY windowIdChanged)
    Q_PROPERTY(bool active READ active WRITE setActive NOTIFY activeChanged)
    Q_PROPERTY(bool live READ live WRITE setLive NOTIFY liveChanged)
    Q_PROPERTY(int maxFps READ maxFps WRITE setMaxFps NOTIFY maxFpsChanged)
    Q_PROPERTY(bool available READ available NOTIFY availableChanged)
    Q_PROPERTY(bool sourceReady READ sourceReady NOTIFY sourceReadyChanged)
    Q_PROPERTY(bool hasContent READ hasContent NOTIFY hasContentChanged)
    Q_PROPERTY(qreal activity READ activity NOTIFY activityChanged)
    Q_PROPERTY(QSize sourceSize READ sourceSize NOTIFY sourceSizeChanged)
    Q_PROPERTY(QString errorString READ errorString NOTIFY errorStringChanged)

public:
    explicit NiriPreviewItem(QQuickItem* parent = nullptr);
    ~NiriPreviewItem() override;

    qulonglong windowId() const { return m_windowId; }
    void setWindowId(qulonglong value);

    bool active() const { return m_active; }
    void setActive(bool value);

    bool live() const { return m_live; }
    void setLive(bool value);

    int maxFps() const { return m_maxFps; }
    void setMaxFps(int value);

    bool available() const { return m_available; }
    bool sourceReady() const { return m_sourceReady; }
    bool hasContent() const { return m_hasContent; }
    qreal activity() const { return m_activity; }
    QSize sourceSize() const { return m_sourceSize; }
    QString errorString() const { return m_errorString; }

    Q_INVOKABLE void captureOnce();

signals:
    void windowIdChanged();
    void activeChanged();
    void liveChanged();
    void maxFpsChanged();
    void availableChanged();
    void sourceReadyChanged();
    void hasContentChanged();
    void activityChanged();
    void sourceSizeChanged();
    void errorStringChanged();
    void frameCaptured();

protected:
    QSGNode* updatePaintNode(QSGNode* oldNode, UpdatePaintNodeData*) override;
    void geometryChange(const QRectF& newGeometry, const QRectF& oldGeometry) override;
    void componentComplete() override;

private:
    void syncConsumer();
    QSize targetPixelSize() const;
    void setErrorString(const QString& value);

    quint64 m_token = 0;
    qulonglong m_windowId = 0;
    bool m_active = false;
    bool m_live = false;
    int m_maxFps = 18;
    bool m_available = false;
    bool m_sourceReady = false;
    bool m_hasContent = false;
    qreal m_activity = 0.0;
    QSize m_sourceSize;
    QString m_errorString;
    bool m_complete = false;

    mutable QMutex m_frameMutex;
    QImage m_frame;
};
