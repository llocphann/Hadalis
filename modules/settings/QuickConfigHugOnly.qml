import QtQuick

// Public Quick page: common actions only. Bar position and backdrop controls
// now live solely in their dedicated owner pages; no post-load UI traversal
// or retired style selector needs to run.
QuickConfig {
    id: root
}
