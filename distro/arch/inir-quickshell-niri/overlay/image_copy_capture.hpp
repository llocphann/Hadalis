#pragma once

#include <qscreen.h>
#include <qstring.h>
#include <qtmetamacros.h>
#include <qvector.h>
#include <qwayland-ext-foreign-toplevel-list-v1.h>
#include <qwayland-ext-image-capture-source-v1.h>
#include <qwayland-ext-image-copy-capture-v1.h>
#include <qwaylandclientextension.h>

#include "../manager.hpp"

namespace qs::wayland::screencopy::icc {

class IccManager
    : public QWaylandClientExtensionTemplate<IccManager>
    , public QtWayland::ext_image_copy_capture_manager_v1 {
public:
	ScreencopyContext* createSession(::ext_image_capture_source_v1* source, bool paintCursors);

	static IccManager* instance();

private:
	explicit IccManager();
};

class IccForeignToplevelHandle;

class IccForeignToplevelSourceManager
    : public QWaylandClientExtensionTemplate<IccForeignToplevelSourceManager>
    , public QtWayland::ext_foreign_toplevel_image_capture_source_manager_v1 {
public:
	::ext_image_capture_source_v1*
	createSource(::ext_foreign_toplevel_handle_v1* handle);

	static IccForeignToplevelSourceManager* instance();

private:
	explicit IccForeignToplevelSourceManager();
};

class IccForeignToplevelManager
    : public QWaylandClientExtensionTemplate<IccForeignToplevelManager>
    , public QtWayland::ext_foreign_toplevel_list_v1 {
	Q_OBJECT;

public:
	[[nodiscard]] bool canCapture(const QString& identifier) const;
	ScreencopyContext* captureToplevel(const QString& identifier, bool paintCursors);

	static IccForeignToplevelManager* instance();

	// Internal callbacks owned by IccForeignToplevelHandle.
	void handleUpdated();
	void handleClosed(IccForeignToplevelHandle* handle);

signals:
	void toplevelsChanged();

protected:
	void ext_foreign_toplevel_list_v1_toplevel(::ext_foreign_toplevel_handle_v1* toplevel) override;
	void ext_foreign_toplevel_list_v1_finished() override;

private:
	explicit IccForeignToplevelManager();
	[[nodiscard]] IccForeignToplevelHandle* findHandle(const QString& identifier) const;

	QVector<IccForeignToplevelHandle*> mToplevels;
};

class IccOutputSourceManager
    : public QWaylandClientExtensionTemplate<IccOutputSourceManager>
    , public QtWayland::ext_output_image_capture_source_manager_v1 {
public:
	ScreencopyContext* captureOutput(QScreen* screen, bool paintCursors);

	static IccOutputSourceManager* instance();

private:
	explicit IccOutputSourceManager();
};

} // namespace qs::wayland::screencopy::icc
