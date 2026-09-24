import QtQuick
import Quickshell
import qs.modules.common
import qs.modules.common.functions

// From https://github.com/caelestia-dots/shell with modifications.
// License: GPLv3

Image {
    id: root
    required property var fileModelData
    asynchronous: true
    fillMode: Image.PreserveAspectFit

    function _extension(fileName): string {
        const name = String(fileName ?? "")
        const dot = name.lastIndexOf(".")
        return dot >= 0 ? name.substring(dot + 1).toLowerCase() : ""
    }

    source: {
        if (!fileModelData.fileIsDir) {
            // DirectoryIcon is used by wallpaper/file pickers. Avoid spawning a
            // `file --mime` process per delegate: image extensions are already
            // known by the shell, while other files can use a generic file icon.
            const extension = root._extension(fileModelData.fileName)
            if (Images.validImageTypes.some(type =>
                    String(type).toLowerCase() === extension))
                return fileModelData.fileUrl
            return Quickshell.iconPath("application-x-zerosize", "image-missing")
        }

        if ([Directories.documents, Directories.downloads, Directories.music, Directories.pictures, Directories.videos].some(dir => FileUtils.trimFileProtocol(dir) === fileModelData.filePath))
            return Quickshell.iconPath(`folder-${fileModelData.fileName.toLowerCase()}`);

        return Quickshell.iconPath("inode-directory");
    }

    onStatusChanged: {
        if (status === Image.Error)
            source = Quickshell.iconPath("error");
    }
}
