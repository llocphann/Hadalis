#include "niri_preview_item.hpp"

#include <QQmlExtensionPlugin>
#include <qqml.h>

class HadalisNiriPreviewPlugin final : public QQmlExtensionPlugin {
    Q_OBJECT
    Q_PLUGIN_METADATA(IID QQmlExtensionInterface_iid)

public:
    void registerTypes(const char* uri) override {
        qmlRegisterType<NiriPreviewItem>(uri, 1, 0, "NiriPreviewItem");
    }
};

#include "plugin.moc"
