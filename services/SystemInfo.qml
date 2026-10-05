pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

/**
 * Provides some system info: distro, username.
 */
Singleton {
    id: root
    property string distroName: "Unknown"
    property string distroId: "unknown"
    property string distroIcon: "linux-symbolic"
    // Seed identity from the process environment so consumers do not build
    // transient paths for the placeholder user while `id -un` is starting.
    // The asynchronous lookup below remains the authoritative refresh.
    property string username: Quickshell.env("USER") || "user"
    property string displayName: ""
    // Static hostname. `/etc/hostname` is the portable source; the env var is a
    // seed for the frame before the file is read and is absent on most systems.
    property string hostname: Quickshell.env("HOSTNAME") || ""
    property string homeUrl: ""
    property string documentationUrl: ""
    property string supportUrl: ""
    property string bugReportUrl: ""
    property string privacyPolicyUrl: ""
    property string logo: ""
    property string desktopEnvironment: String(Quickshell.env("XDG_CURRENT_DESKTOP") ?? "").trim()
    property string windowingSystem: String(Quickshell.env("WAYLAND_DISPLAY") ?? "").trim().length > 0 ? "Wayland" : "X11"

    function _osReleaseValue(text: string, key: string): string {
        const prefix = key + "="
        const lines = String(text ?? "").split("\n")
        for (let i = 0; i < lines.length; ++i) {
            const line = lines[i]
            if (!line.startsWith(prefix))
                continue

            let value = line.slice(prefix.length).trim()
            if (value.length >= 2) {
                const quote = value[0]
                if ((quote === "\"" || quote === "'") && value[value.length - 1] === quote)
                    value = value.slice(1, -1)
            }
            return value
        }
        return ""
    }

    function _parseOsReleaseValues(text: string): var {
        const lines = String(text ?? "").split("\n")
        let prettyName
        let name
        let id
        let homeUrlValue
        let documentationUrlValue
        let supportUrlValue
        let bugReportUrlValue
        let privacyPolicyUrlValue
        let logoValue

        function normalizedValue(line, prefixLength) {
            let value = line.slice(prefixLength).trim()
            if (value.length >= 2) {
                const quote = value[0]
                if ((quote === "\"" || quote === "'") && value[value.length - 1] === quote)
                    value = value.slice(1, -1)
            }
            return value
        }

        for (let i = 0; i < lines.length; ++i) {
            const line = lines[i]
            if (prettyName === undefined && line.startsWith("PRETTY_NAME="))
                prettyName = normalizedValue(line, 12)
            else if (name === undefined && line.startsWith("NAME="))
                name = normalizedValue(line, 5)
            else if (id === undefined && line.startsWith("ID="))
                id = normalizedValue(line, 3)
            else if (homeUrlValue === undefined && line.startsWith("HOME_URL="))
                homeUrlValue = normalizedValue(line, 9)
            else if (documentationUrlValue === undefined && line.startsWith("DOCUMENTATION_URL="))
                documentationUrlValue = normalizedValue(line, 18)
            else if (supportUrlValue === undefined && line.startsWith("SUPPORT_URL="))
                supportUrlValue = normalizedValue(line, 12)
            else if (bugReportUrlValue === undefined && line.startsWith("BUG_REPORT_URL="))
                bugReportUrlValue = normalizedValue(line, 15)
            else if (privacyPolicyUrlValue === undefined && line.startsWith("PRIVACY_POLICY_URL="))
                privacyPolicyUrlValue = normalizedValue(line, 19)
            else if (logoValue === undefined && line.startsWith("LOGO="))
                logoValue = normalizedValue(line, 5)
        }

        return {
            prettyName: prettyName ?? "",
            name: name ?? "",
            id: id ?? "",
            homeUrl: homeUrlValue ?? "",
            documentationUrl: documentationUrlValue ?? "",
            supportUrl: supportUrlValue ?? "",
            bugReportUrl: bugReportUrlValue ?? "",
            privacyPolicyUrl: privacyPolicyUrlValue ?? "",
            logo: logoValue ?? ""
        }
    }

    function refreshIdentity(): void {
        if (getUsername.running || getDisplayName.running)
            return

        const envUser = String(Quickshell.env("USER") ?? "").trim()
        if (envUser.length > 0) {
            root.username = envUser
            getDisplayName.command = ["/usr/bin/getent", "passwd", envUser]
            getDisplayName.running = true
            return
        }

        getUsername.running = true
    }

    Timer {
        triggeredOnStart: true
        interval: 1
        running: true
        repeat: false
        onTriggered: {
            refreshIdentity()
            fileHostname.reload()
            const textHostname = fileHostname.text().trim()
            if (textHostname.length > 0) hostname = textHostname.split("\n")[0].trim()
            fileOsRelease.reload()
            const textOsRelease = fileOsRelease.text()

            // os-release permits both quoted and unquoted values. Parse the
            // assignment first so valid entries such as NAME=Arch Linux do not
            // silently fall back to Unknown.
            const osRelease = root._parseOsReleaseValues(textOsRelease)
            const prettyName = osRelease.prettyName
            const name = osRelease.name
            distroName = prettyName.length > 0
                ? prettyName
                : (name.length > 0 ? name.replace(/Linux/i, "").trim() : "Unknown")

            const parsedId = osRelease.id
            distroId = parsedId.length > 0 ? parsedId : "unknown"

            homeUrl = osRelease.homeUrl
            documentationUrl = osRelease.documentationUrl
            supportUrl = osRelease.supportUrl
            bugReportUrl = osRelease.bugReportUrl
            privacyPolicyUrl = osRelease.privacyPolicyUrl
            logo = osRelease.logo

            // Update the distroIcon property based on distroId
            switch (distroId) {
                case "arch": distroIcon = "arch-symbolic"; break;
                case "endeavouros": distroIcon = "endeavouros-symbolic"; break;
                case "cachyos": distroIcon = "cachyos-symbolic"; break;
                case "nixos": distroIcon = "nixos-symbolic"; break;
                case "fedora": distroIcon = "fedora-symbolic"; break;
                case "linuxmint":
                case "ubuntu":
                case "zorin":
                case "popos": distroIcon = "ubuntu-symbolic"; break;
                case "debian":
                case "raspbian":
                case "kali": distroIcon = "debian-symbolic"; break;
                case "funtoo":
                case "gentoo": distroIcon = "gentoo-symbolic"; break;
                default: distroIcon = "linux-symbolic"; break;
            }
            if (textOsRelease.toLowerCase().includes("nyarch")) {
                distroIcon = "nyarch-symbolic"
            }

            if (logo.trim().length === 0) {
                logo = distroIcon
            }

        }
    }


    Process {
        id: getUsername
        property bool startObserved: false
        command: ["/usr/bin/id", "-un"]

        onRunningChanged: {
            if (getUsername.running) {
                getUsername.startObserved = false
                return
            }
            if (getUsername.startObserved)
                return

            const name = Quickshell.env("USER") || root.username || "user"
            root.username = name
            getDisplayName.command = ["/usr/bin/getent", "passwd", name]
            getDisplayName.running = true
            console.warn("[SystemInfo] Failed to start username lookup; using environment fallback")
        }

        onStarted: getUsername.startObserved = true

        stdout: StdioCollector {
            id: usernameCollector
            onStreamFinished: {
                const name = usernameCollector.text.trim() || Quickshell.env("USER") || root.username
                root.username = name
                getDisplayName.command = ["/usr/bin/getent", "passwd", name]
                getDisplayName.running = true
            }
        }
    }

    Process {
        id: getDisplayName
        running: false
        property bool startObserved: false
        command: ["/usr/bin/getent", "passwd", root.username]

        onRunningChanged: {
            if (getDisplayName.running) {
                getDisplayName.startObserved = false
                return
            }
            if (getDisplayName.startObserved)
                return

            root.displayName = root.username
            console.warn("[SystemInfo] Failed to start display-name lookup; using username fallback")
        }

        onStarted: getDisplayName.startObserved = true

        stdout: StdioCollector {
            id: displayNameCollector
            onStreamFinished: {
                const passwdLine = displayNameCollector.text.trim().split("\n")[0] ?? ""
                const fields = passwdLine.split(":")
                const gecosField = fields.length >= 5 ? fields[4] : ""
                const name = gecosField.split(",")[0].trim()
                root.displayName = name.length > 0 ? name : root.username
            }
        }
    }

    FileView {
        id: fileOsRelease
        path: "/etc/os-release"
    }

    FileView {
        id: fileHostname
        path: "/etc/hostname"
    }
}
