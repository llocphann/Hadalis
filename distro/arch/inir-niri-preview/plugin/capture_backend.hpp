#pragma once

#include <QImage>
#include <QObject>
#include <QSize>
#include <QThread>

class CaptureWorker;

class CaptureBroker final : public QObject {
    Q_OBJECT

public:
    static CaptureBroker* instance();

    bool available() const { return m_available; }

    void updateConsumer(quint64 token,
                        quint64 windowId,
                        bool active,
                        bool live,
                        int maxFps,
                        const QSize& targetSize);
    void captureOnce(quint64 token);
    void unregisterConsumer(quint64 token);

signals:
    void backendAvailableChanged(bool available);
    void sourceReady(quint64 token, bool ready);
    void frameReady(quint64 token,
                    const QImage& frame,
                    qreal activity,
                    const QSize& sourceSize);
    void captureError(quint64 token, const QString& message);

private:
    explicit CaptureBroker(QObject* parent = nullptr);
    ~CaptureBroker() override;

    void setAvailable(bool available);

    QThread m_thread;
    CaptureWorker* m_worker = nullptr;
    bool m_available = false;

    friend class CaptureWorker;
};
