#include "foreign_toplevel_source.hpp"

#include <qobject.h>
#include <qwaylandclientextension.h>

#include "build.hpp"

#if SCREENCOPY_ICC
#include "image_copy_capture/image_copy_capture.hpp"
#endif

namespace qs::wayland::screencopy {

ForeignToplevelCaptureSource::ForeignToplevelCaptureSource(QObject* parent): QObject(parent) {
#if SCREENCOPY_ICC
	auto* toplevels = icc::IccForeignToplevelManager::instance();
	auto* sources = icc::IccForeignToplevelSourceManager::instance();
	auto* capture = icc::IccManager::instance();

	QObject::connect(
	    toplevels,
	    &icc::IccForeignToplevelManager::toplevelsChanged,
	    this,
	    &ForeignToplevelCaptureSource::updateReady
	);
	QObject::connect(
	    toplevels,
	    &QWaylandClientExtension::activeChanged,
	    this,
	    &ForeignToplevelCaptureSource::updateReady
	);
	QObject::connect(
	    sources,
	    &QWaylandClientExtension::activeChanged,
	    this,
	    &ForeignToplevelCaptureSource::updateReady
	);
	QObject::connect(
	    capture,
	    &QWaylandClientExtension::activeChanged,
	    this,
	    &ForeignToplevelCaptureSource::updateReady
	);
#endif

	this->updateReady();
}

void ForeignToplevelCaptureSource::setIdentifier(const QString& identifier) {
	if (this->mIdentifier == identifier) return;
	this->mIdentifier = identifier;
	emit this->identifierChanged();
	this->updateReady();
}

void ForeignToplevelCaptureSource::updateReady() {
	auto ready = false;
#if SCREENCOPY_ICC
	ready = icc::IccForeignToplevelManager::instance()->canCapture(this->mIdentifier);
#endif
	if (ready == this->mReady) return;
	this->mReady = ready;
	emit this->readyChanged();
}

} // namespace qs::wayland::screencopy
