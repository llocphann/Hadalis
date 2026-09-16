pragma Singleton
pragma ComponentBehavior: Bound

import qs.modules.common.functions
import qs.modules.common
import QtQuick
import Quickshell
import qs.services

/**
 * Renders LaTeX snippets with MicroTeX.
 * For every request:
 *   1. Hash it
 *   2. Check if the hash is already processed
 *   3. If not, render it with MicroTeX and mark as processed
 */
Singleton {
    id: root
    
    readonly property var renderPadding: 4 // This is to prevent cutoff in the rendered images

    property list<string> processedHashes: []
    property var processedExpressions: ({})
    property var renderedImagePaths: ({})
    property string microtexBinaryDir: "/opt/MicroTeX"
    property string microtexBinaryName: "LaTeX"
    property string latexOutputPath: Directories.latexOutput

    signal renderFinished(string hash, string imagePath)

    function _forgetRender(hash: string): void {
        root.processedHashes = root.processedHashes.filter(item => item !== hash)
        delete root.processedExpressions[hash]
        delete root.renderedImagePaths[hash]
    }

    function _completeRender(hash: string, imagePath: string): void {
        root.renderedImagePaths[hash] = imagePath
        root.renderFinished(hash, imagePath)
    }

    /**
    * Requests rendering of a LaTeX expression.
    * Returns the [hash, isNew]
    */
    function requestRender(expression) {
        // 1. Hash it and initialize necessary variables
        const hash = Qt.md5(expression)
        const imagePath = `${latexOutputPath}/${hash}.svg`
        
        // 2. Check if the hash is already processed
        if (processedHashes.includes(hash)) {
            // A duplicate request may arrive while the original render is still
            // in flight. Only replay completion after the output was recorded.
            const renderedPath = root.renderedImagePaths[hash]
            if (renderedPath)
                renderFinished(hash, renderedPath)
            return [hash, false]
        } else {
            root.processedHashes.push(hash)
            root.processedExpressions[hash] = expression
            // console.log("Rendering expression: " + expression)
        }

        // 3. If not, render it with MicroTeX and mark as processed
        // console.log(`[LatexRenderer] Rendering expression: ${expression} with hash: ${hash}`)
        // console.log(`                to file: ${imagePath}`)
        // console.log(`                with command: cd ${microtexBinaryDir} && ./${microtexBinaryName} -headless -input=${StringUtils.shellSingleQuoteEscape(expression)} -output=${imagePath} -textsize=${Appearance.font.pixelSize.normal} -padding=${renderPadding} -background=${Appearance.m3colors.m3tertiary} -foreground=${Appearance.m3colors.m3onTertiary} -maxwidth=0.85`)
        const command = [
            `${root.microtexBinaryDir}/${root.microtexBinaryName}`,
            "-headless",
            `-input=${expression}`,
            `-output=${imagePath}`,
            `-textsize=${Appearance.font.pixelSize.normal}`,
            `-padding=${renderPadding}`,
            `-foreground=${Appearance.colors.colOnLayer1}`,
            "-maxwidth=0.85"
        ]
        const processQml = `
            import Quickshell.Io
            Process {
                id: microtexProcess${hash}
                running: true
                command: ${JSON.stringify(command)}
                // stdout: SplitParser {
                //     onRead: data => { console.log("MicroTeX: " + data) }
                // }
                onExited: (exitCode, exitStatus) => {
                    // console.log("[LatexRenderer] MicroTeX process exited with code: " + exitCode + ", status: " + exitStatus)
                    if (exitCode === 0)
                        root._completeRender(${JSON.stringify(hash)}, ${JSON.stringify(imagePath)})
                    else
                        root._forgetRender(${JSON.stringify(hash)})
                    microtexProcess${hash}.destroy()
                }
            }
        `
        // console.log("MicroTeX: " + processQml)
        try {
            const process = Qt.createQmlObject(processQml, root, `MicroTeXProcess_${hash}`)
            if (!process)
                root._forgetRender(hash)
        } catch (e) {
            root._forgetRender(hash)
            console.error("[LatexRenderer] Failed to create MicroTeX process:", e)
        }
        return [hash, true]
    }
}