#pragma once

#include <qobject.h>
#include <qqmlintegration.h>
#include <qstring.h>
#include <qtmetamacros.h>

namespace qs::wayland::screencopy {

/// Capture-source descriptor for compositors implementing
/// ext-foreign-toplevel-list + ext-image-copy-capture.
///
/// The identifier is compositor-defined. Niri intentionally exposes its IPC
/// window ID as this identifier, allowing shells to map a niri window exactly.
class ForeignToplevelCaptureSource: public QObject {
	Q_OBJECT;
	QML_ELEMENT;

	Q_PROPERTY(QString identifier READ identifier WRITE setIdentifier NOTIFY identifierChanged);
	Q_PROPERTY(bool ready READ ready NOTIFY readyChanged);

public:
	explicit ForeignToplevelCaptureSource(QObject* parent = nullptr);

	[[nodiscard]] QString identifier() const { return this->mIdentifier; }
	void setIdentifier(const QString& identifier);

	[[nodiscard]] bool ready() const { return this->mReady; }

signals:
	void identifierChanged();
	void readyChanged();

private slots:
	void updateReady();

private:
	QString mIdentifier;
	bool mReady = false;
};

} // namespace qs::wayland::screencopy
