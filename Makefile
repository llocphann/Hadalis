PREFIX ?= /usr/local
BINDIR = $(PREFIX)/bin
SHAREDIR = $(PREFIX)/share
APPLICATIONS_DIR = $(SHAREDIR)/applications
ICON_DIR = $(SHAREDIR)/icons/hicolor/scalable/apps
SHELL_INSTALL_DIR = $(SHAREDIR)/quickshell/inir
DOC_DIR = $(SHAREDIR)/doc/inir-shell
LICENSE_DIR = $(SHAREDIR)/licenses/inir-shell
SYSTEMD_USER_DIR ?= $(PREFIX)/lib/systemd/user
LIBEXECDIR ?= /usr/libexec
POLKIT_ACTIONS_DIR ?= /usr/share/polkit-1/actions
TLP_CONFDIR ?= /etc/tlp.d
INIR_SYSTEM_SHAREDIR ?= /usr/share/inir
BATTERY_HELPER = $(LIBEXECDIR)/inir-battery-charge-limit
BATTERY_POLICY = $(POLKIT_ACTIONS_DIR)/org.inir.battery-charge-limit.policy
BATTERY_DROPIN = $(TLP_CONFDIR)/99-inir-battery-charge-limit.conf
TLP_SETTINGS_DROPIN = $(TLP_CONFDIR)/99-inir-tlp-settings.conf
TLP_SETTINGS_SCHEMA = $(INIR_SYSTEM_SHAREDIR)/tlp-settings-schema.json
THINKFAN_HELPER = $(LIBEXECDIR)/inir-thinkfan
THINKFAN_POLICY = $(POLKIT_ACTIONS_DIR)/org.inir.thinkfan.policy
PACKAGE_UPDATE_HINT = sudo make install PREFIX=\"$(PREFIX)\" SYSTEMD_USER_DIR=\"$(SYSTEMD_USER_DIR)\" LIBEXECDIR=\"$(LIBEXECDIR)\" POLKIT_ACTIONS_DIR=\"$(POLKIT_ACTIONS_DIR)\" TLP_CONFDIR=\"$(TLP_CONFDIR)\" INIR_SYSTEM_SHAREDIR=\"$(INIR_SYSTEM_SHAREDIR)\"

.PHONY: all build test-local test-doctor-routing test-optional-audio-deps test-news-contract test-equalizer-contracts test-perimeter-contracts test-docs test-install-lifecycle test-prefix-install test-package-docs test-package-metadata test-package-hooks test-battery-helper test-thinkfan-helper install install-bin install-shell install-systemd install-icon install-desktop install-docs install-license install-battery-helper install-thinkfan-helper uninstall uninstall-bin uninstall-shell uninstall-systemd uninstall-icon uninstall-desktop uninstall-docs uninstall-license uninstall-battery-helper uninstall-thinkfan-helper

all: build

build:
	@bash -n scripts/inir
	@bash -n scripts/test-local-distribution.sh
	@bash -n setup

test-local: build test-doctor-routing test-optional-audio-deps test-news-contract test-equalizer-contracts test-perimeter-contracts test-docs test-install-lifecycle test-prefix-install test-package-docs test-package-metadata test-package-hooks
	@bash scripts/test-local-distribution.sh
	@bash scripts/test-packaging-contract.sh
	@bash scripts/test-nix-module-contract.sh

test-doctor-routing:
	@bash scripts/test-doctor-dependency-routing.sh

test-optional-audio-deps:
	@bash scripts/test-optional-audio-deps-contract.sh

test-news-contract:
	@bash scripts/test-news-service-contract.sh

test-equalizer-contracts:
	@bash scripts/test-equalizer-boundary-contract.sh
	@bash scripts/test-equalizer-service-contract.sh

test-perimeter-contracts:
	@bash scripts/test-perimeter-contracts.sh
	@bash scripts/test-perimeter-compatibility-placement-contract.sh
	@bash scripts/test-perimeter-family-contracts.sh
	@bash scripts/test-perimeter-route-contracts.sh
	@bash scripts/test-perimeter-settings-contracts.sh
	@bash scripts/test-perimeter-source-contracts.sh
	@bash scripts/test-perimeter-runtime-health-contract.sh

test-docs:
	@bash scripts/verify-docs.sh

test-install-lifecycle:
	@bash scripts/test-make-install-lifecycle.sh

test-prefix-install:
	@stage="$$(mktemp -d)"; \
		trap 'rm -rf -- "$$stage"' EXIT; \
		$(MAKE) -s install-bin install-shell install-desktop install-docs DESTDIR="$$stage" PREFIX=/opt/inir; \
		runtime="$$stage/opt/inir/share/quickshell/inir"; \
		docs="$$stage/opt/inir/share/doc/inir-shell"; \
		test -f "$$runtime/shell.qml"; \
		test -f "$$runtime/qmldir"; \
		test -f "$$docs/README.md"; \
		test -f "$$docs/AUDIO_MEDIA.md"; \
		test -f "$$docs/INSTALL.md"; \
		test -f "$$docs/PACKAGES.md"; \
		test -f "$$docs/RELEASING.md"; \
		grep -Fq 'system_config_dir="$${INIR_SYSTEM_RUNTIME_DIR:-/opt/inir/share/quickshell/inir}"' "$$stage/opt/inir/bin/inir"; \
		grep -Fq 'system_config_dir="$${INIR_SYSTEM_RUNTIME_DIR:-/opt/inir/share/quickshell/inir}"' "$$runtime/scripts/inir"; \
		grep -Fq 'RUNTIME_DIR_SYSTEM_LOCAL="$${INIR_SYSTEM_RUNTIME_DIR_LOCAL:-/opt/inir/share/quickshell/inir}"' "$$runtime/sdata/lib/versioning.sh"; \
		grep -Fq 'get_installed_update_strategy 2>/dev/null || true' "$$runtime/setup"; \
		python3 -c 'import json, pathlib, sys; data=json.loads(pathlib.Path(sys.argv[1]).read_text()); assert data["version"] == pathlib.Path("VERSION").read_text().strip(); assert data["installMode"] == "package-managed"; assert data["updateStrategy"] == "package-manager"; assert data["packageManager"] == "manual"; assert "PREFIX=\"/opt/inir\"" in data["packageUpdateHint"]' "$$runtime/version.json"; \
		grep -Fxq 'Exec=/opt/inir/bin/inir service restart' "$$stage/opt/inir/share/applications/inir.desktop"; \
		grep -Fxq 'Exec=/opt/inir/bin/inir settings' "$$stage/opt/inir/share/applications/inir-settings.desktop"

test-package-docs:
	@grep -Fq 'for doc in docs/*.md; do' Makefile
	@grep -Fq 'for doc in "$$srcroot"/docs/*.md; do' distro/arch/inir-shell/PKGBUILD
	@grep -Fq 'for doc in "$$srcroot"/docs/*.md; do' distro/arch/inir-shell-git/PKGBUILD
	@grep -Fq 'for doc in docs/*.md; do' nix/package.nix
	@grep -Fq 'install -Dm644 LICENSE "$$out/share/licenses/inir/LICENSE"' nix/package.nix

test-package-metadata:
	@repo_version="$$(tr -d '[:space:]' < VERSION)"; \
		git_version="$$(grep -m1 '^pkgver=' distro/arch/inir-shell-git/PKGBUILD | cut -d= -f2-)"; \
		case "$$git_version" in \
			"$$repo_version".r*) ;; \
			*) printf 'inir-shell-git pkgver seed %s does not follow VERSION %s\n' "$$git_version" "$$repo_version" >&2; exit 1 ;; \
		esac; \
		srcinfo_version="$$(sed -n 's/^[[:space:]]*pkgver = //p' distro/arch/inir-shell-git/.SRCINFO | head -1)"; \
		test "$$srcinfo_version" = "$$git_version"

test-package-hooks:
	@cmp -s distro/arch/inir-shell/inir-shell.install distro/arch/inir-shell-git/inir-shell-git.install || { \
		printf 'Arch stable/git install hooks drifted; keep lifecycle cleanup in sync\n' >&2; \
		exit 1; \
	}
	@for hook in distro/arch/inir-shell/inir-shell.install distro/arch/inir-shell-git/inir-shell-git.install; do \
		grep -Fq 'pre_remove() {' "$$hook"; \
		grep -Fq '/usr/libexec/inir-battery-charge-limit --config-reset' "$$hook"; \
		grep -Fq '/usr/libexec/inir-battery-charge-limit --disable' "$$hook"; \
		grep -Fq '/etc/tlp.d/99-inir-battery-charge-limit.conf' "$$hook"; \
		grep -Fq '/etc/tlp.d/99-inir-tlp-settings.conf' "$$hook"; \
	done

test-battery-helper:
	@sh scripts/test-battery-charge-limit-helper.sh

test-thinkfan-helper:
	@bash scripts/test-thinkfan-helper.sh

install-bin:
	@mkdir -p "$(DESTDIR)$(BINDIR)"
	@sed 's|^system_config_dir=.*|system_config_dir="$${INIR_SYSTEM_RUNTIME_DIR:-$(SHELL_INSTALL_DIR)}"|' \
		scripts/inir > "$(DESTDIR)$(BINDIR)/inir"
	@chmod 755 "$(DESTDIR)$(BINDIR)/inir"

install-shell:
	@python3 sdata/lib/runtime-payload.py copy --root . --target "$(DESTDIR)$(SHELL_INSTALL_DIR)"
	@chmod +x "$(DESTDIR)$(SHELL_INSTALL_DIR)/setup" "$(DESTDIR)$(SHELL_INSTALL_DIR)/scripts/inir"
	@find "$(DESTDIR)$(SHELL_INSTALL_DIR)/scripts" -type f \( -name "*.sh" -o -name "*.fish" -o -name "*.py" \) -exec chmod +x {} +
	@sed -i \
		-e 's|/usr/libexec/inir-battery-charge-limit|$(BATTERY_HELPER)|g' \
		-e 's|/usr/libexec/inir-thinkfan|$(THINKFAN_HELPER)|g' \
		"$(DESTDIR)$(SHELL_INSTALL_DIR)/services/TlpSettingsService.qml" \
		"$(DESTDIR)$(SHELL_INSTALL_DIR)/services/ThinkFanService.qml"
	@sed -i \
		's|^system_config_dir=.*|system_config_dir="$${INIR_SYSTEM_RUNTIME_DIR:-$(SHELL_INSTALL_DIR)}"|' \
		"$(DESTDIR)$(SHELL_INSTALL_DIR)/scripts/inir"
	@sed -i \
		's|^RUNTIME_DIR_SYSTEM_LOCAL=.*|RUNTIME_DIR_SYSTEM_LOCAL="$${INIR_SYSTEM_RUNTIME_DIR_LOCAL:-$(SHELL_INSTALL_DIR)}"|' \
		"$(DESTDIR)$(SHELL_INSTALL_DIR)/sdata/lib/versioning.sh"
	@python3 -c 'from pathlib import Path; p=Path("$(DESTDIR)$(SHELL_INSTALL_DIR)/setup"); t=p.read_text(); m="sync_launcher_from_repo() {\n"; assert t.count(m) == 1, "expected one sync_launcher_from_repo definition"; g=m+"    if [[ \"$$(get_installed_update_strategy 2>/dev/null || true)\" == \"package-manager\" ]]; then\n        return 0\n    fi\n"; p.write_text(t.replace(m, g, 1))'
	@printf '{\n  "version": "%s",\n  "commit": "%s",\n  "installed_at": "%s",\n  "installedAt": "%s",\n  "source": "make-install",\n  "repo_path": "",\n  "repoPath": "",\n  "install_mode": "package-managed",\n  "installMode": "package-managed",\n  "update_strategy": "package-manager",\n  "updateStrategy": "package-manager",\n  "package_manager": "manual",\n  "packageManager": "manual",\n  "package_name": "source-install",\n  "packageName": "source-install",\n  "package_update_hint": "$(PACKAGE_UPDATE_HINT)",\n  "packageUpdateHint": "$(PACKAGE_UPDATE_HINT)"\n}\n' "$$(cat VERSION)" "$$(git rev-parse --short HEAD 2>/dev/null || printf manual)" "$$(date -Iseconds)" "$$(date -Iseconds)" > "$(DESTDIR)$(SHELL_INSTALL_DIR)/version.json"

install-systemd:
	@mkdir -p "$(DESTDIR)$(SYSTEMD_USER_DIR)"
	@sed -e 's|^ExecStart=.*|ExecStart=$(BINDIR)/inir run --session|' \
		-e 's|^ExecStopPost=-.*|ExecStopPost=-$(BINDIR)/inir cleanup-orphans|' \
		assets/systemd/inir.service > "$(DESTDIR)$(SYSTEMD_USER_DIR)/inir.service"
	@chmod 644 "$(DESTDIR)$(SYSTEMD_USER_DIR)/inir.service"

install-icon:
	@install -Dm644 assets/icons/desktop-symbolic.svg "$(DESTDIR)$(ICON_DIR)/inir.svg"
	@if [ -z "$(DESTDIR)" ]; then gtk-update-icon-cache -q "$(SHAREDIR)/icons/hicolor" 2>/dev/null || true; fi

install-desktop:
	@mkdir -p "$(DESTDIR)$(APPLICATIONS_DIR)"
	@sed 's|^Exec=inir|Exec=$(BINDIR)/inir|' assets/applications/inir.desktop > "$(DESTDIR)$(APPLICATIONS_DIR)/inir.desktop"
	@sed 's|^Exec=inir|Exec=$(BINDIR)/inir|' assets/applications/inir-settings.desktop > "$(DESTDIR)$(APPLICATIONS_DIR)/inir-settings.desktop"
	@chmod 644 "$(DESTDIR)$(APPLICATIONS_DIR)/inir.desktop" "$(DESTDIR)$(APPLICATIONS_DIR)/inir-settings.desktop"
	@if [ -z "$(DESTDIR)" ]; then update-desktop-database -q "$(APPLICATIONS_DIR)" 2>/dev/null || true; fi

install-docs:
	@install -Dm644 README.md "$(DESTDIR)$(DOC_DIR)/README.md"
	@for doc in docs/*.md; do \
		install -Dm644 "$$doc" "$(DESTDIR)$(DOC_DIR)/$$(basename "$$doc")"; \
	done

install-license:
	@install -Dm644 LICENSE "$(DESTDIR)$(LICENSE_DIR)/LICENSE"

install-battery-helper:
	@mkdir -p "$(DESTDIR)$(LIBEXECDIR)"
	@sed \
		-e 's|^config_dir=.*|config_dir=$(TLP_CONFDIR)|' \
		-e 's|^tlp_settings_schema=.*|tlp_settings_schema=$(TLP_SETTINGS_SCHEMA)|' \
		assets/helpers/inir-battery-charge-limit > "$(DESTDIR)$(BATTERY_HELPER)"
	@chmod 755 "$(DESTDIR)$(BATTERY_HELPER)"
	@mkdir -p "$(DESTDIR)$(POLKIT_ACTIONS_DIR)"
	@sed 's|<annotate key="org.freedesktop.policykit.exec.path">[^<]*</annotate>|<annotate key="org.freedesktop.policykit.exec.path">$(BATTERY_HELPER)</annotate>|' \
		assets/polkit/org.inir.battery-charge-limit.policy > "$(DESTDIR)$(BATTERY_POLICY)"
	@chmod 644 "$(DESTDIR)$(BATTERY_POLICY)"
	@install -Dm644 assets/tlp/tlp-settings-schema.json "$(DESTDIR)$(TLP_SETTINGS_SCHEMA)"

install-thinkfan-helper:
	@install -Dm755 assets/helpers/inir-thinkfan "$(DESTDIR)$(THINKFAN_HELPER)"
	@mkdir -p "$(DESTDIR)$(POLKIT_ACTIONS_DIR)"
	@sed 's|<annotate key="org.freedesktop.policykit.exec.path">[^<]*</annotate>|<annotate key="org.freedesktop.policykit.exec.path">$(THINKFAN_HELPER)</annotate>|' \
		assets/polkit/org.inir.thinkfan.policy > "$(DESTDIR)$(THINKFAN_POLICY)"
	@chmod 644 "$(DESTDIR)$(THINKFAN_POLICY)"

install: build install-bin install-shell install-systemd install-icon install-desktop install-docs install-license install-battery-helper install-thinkfan-helper

uninstall-bin:
	@rm -f "$(DESTDIR)$(BINDIR)/inir"

uninstall-shell:
	@rm -rf "$(DESTDIR)$(SHELL_INSTALL_DIR)"

uninstall-systemd:
	@rm -f "$(DESTDIR)$(SYSTEMD_USER_DIR)/inir.service"

uninstall-icon:
	@rm -f "$(DESTDIR)$(ICON_DIR)/inir.svg"
	@if [ -z "$(DESTDIR)" ]; then gtk-update-icon-cache -q "$(SHAREDIR)/icons/hicolor" 2>/dev/null || true; fi

uninstall-desktop:
	@rm -f "$(DESTDIR)$(APPLICATIONS_DIR)/inir.desktop" "$(DESTDIR)$(APPLICATIONS_DIR)/inir-settings.desktop"
	@if [ -z "$(DESTDIR)" ]; then update-desktop-database -q "$(APPLICATIONS_DIR)" 2>/dev/null || true; fi

uninstall-docs:
	@rm -rf "$(DESTDIR)$(DOC_DIR)"

uninstall-license:
	@rm -rf "$(DESTDIR)$(LICENSE_DIR)"

uninstall-battery-helper:
	@if [ -z "$(DESTDIR)" ] && [ -x "$(BATTERY_HELPER)" ]; then \
		"$(BATTERY_HELPER)" --config-reset >/dev/null 2>&1 || true; \
		"$(BATTERY_HELPER)" --disable >/dev/null 2>&1 || true; \
	fi
	@rm -f "$(DESTDIR)$(BATTERY_DROPIN)"
	@rm -f "$(DESTDIR)$(TLP_SETTINGS_DROPIN)"
	@rm -f "$(DESTDIR)$(BATTERY_HELPER)" "$(DESTDIR)$(BATTERY_POLICY)" "$(DESTDIR)$(TLP_SETTINGS_SCHEMA)"

uninstall-thinkfan-helper:
	@rm -f "$(DESTDIR)$(THINKFAN_HELPER)" "$(DESTDIR)$(THINKFAN_POLICY)"

uninstall: uninstall-systemd uninstall-desktop uninstall-icon uninstall-docs uninstall-license uninstall-shell uninstall-bin uninstall-battery-helper uninstall-thinkfan-helper