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
    // transient paths for a placeholder user. Normal desktop sessions already
    // export USER, so the external id(1) lookup is only a compatibility fallback.
    property string username: String(Quickshell.env("USER") ?? "").trim() || "user"
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

    function _startDisplayNameFallback(name: string): void {
        const normalized = String(name ?? "").trim()
        if (normalized.length === 0 || getDisplayName.running)
            return
        getDisplayName.command = ["/usr/bin/getent", "passwd", normalized]
        getDisplayName.running = true
    }

    function _resolveDisplayName(name: string): void {
        const normalized = String(name ?? "").trim()
        if (normalized.length === 0) {
            root.displayName = root.username
            return
        }

        root.username = normalized
        passwdFile.lookupName = normalized
        if (passwdFile.path === "/etc/passwd")
            passwdFile.reload()
        else
            passwdFile.path = "/etc/passwd"
    }

    function _consumePasswd(text: string): void {
        const name = passwdFile.lookupName
        for (const line of String(text ?? "").split("\n")) {
            const fields = line.split(":")
            if (fields.length < 5 || fields[0] !== name)
                continue
            const gecos = fields[4].split(",")[0].trim()
            root.displayName = gecos.length > 0 ? gecos : name
            return
        }

        // NSS-backed users (SSSD/LDAP/etc.) may not exist in /etc/passwd.
        // Preserve getent as a compatibility fallback only for that case.
        root._startDisplayNameFallback(name)
    }

    function refreshIdentity(): void {
        if (getUsername.running || getDisplayName.running)
            return

        const envUsername = String(Quickshell.env("USER") ?? "").trim()
        if (envUsername.length > 0) {
            root._resolveDisplayName(envUsername)
            return
        }

        // USER can be absent in unusual launch environments. Preserve id(1) as
        // the compatibility path instead of making environment state mandatory.
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
            const prettyName = root._osReleaseValue(textOsRelease, "PRETTY_NAME")
            const name = root._osReleaseValue(textOsRelease, "NAME")
            distroName = prettyName.length > 0
                ? prettyName
                : (name.length > 0 ? name.replace(/Linux/i, "").trim() : "Unknown")

            const parsedId = root._osReleaseValue(textOsRelease, "ID")
            distroId = parsedId.length > 0 ? parsedId : "unknown"

            homeUrl = root._osReleaseValue(textOsRelease, "HOME_URL")
            documentationUrl = root._osReleaseValue(textOsRelease, "DOCUMENTATION_URL")
            supportUrl = root._osReleaseValue(textOsRelease, "SUPPORT_URL")
            bugReportUrl = root._osReleaseValue(textOsRelease, "BUG_REPORT_URL")
            privacyPolicyUrl = root._osReleaseValue(textOsRelease, "PRIVACY_POLICY_URL")
            logo = root._osReleaseValue(textOsRelease, "LOGO")

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
            root._resolveDisplayName(name)
            console.warn("[SystemInfo] Failed to start username lookup; using environment fallback")
        }

        onStarted: getUsername.startObserved = true

        stdout: StdioCollector {
            id: usernameCollector
            onStreamFinished: {
                const name = usernameCollector.text.trim() || Quickshell.env("USER") || root.username
                root._resolveDisplayName(name)
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
        id: passwdFile
        property string lookupName: ""
        path: ""
        printErrors: false
        onLoaded: root._consumePasswd(passwdFile.text())
        onLoadFailed: root._startDisplayNameFallback(passwdFile.lookupName)
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
