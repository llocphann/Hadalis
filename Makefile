PREFIX ?= /usr/local
BINDIR = $(PREFIX)/bin
SHAREDIR = $(PREFIX)/share
APPLICATIONS_DIR = $(SHAREDIR)/applications
ICON_DIR = $(SHAREDIR)/icons/hicolor/scalable/apps
SHELL_INSTALL_DIR = $(SHAREDIR)/quickshell/inir
DOC_DIR = $(SHAREDIR)/doc/inir-shell
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

.PHONY: all build test-local test-battery-helper install install-bin install-shell install-systemd install-icon install-desktop install-docs install-battery-helper install-thinkfan-helper uninstall uninstall-bin uninstall-shell uninstall-systemd uninstall-icon uninstall-desktop uninstall-docs uninstall-battery-helper uninstall-thinkfan-helper

all: build

build:
	@chmod +x scripts/inir
	@chmod +x scripts/test-local-distribution.sh
	@chmod +x setup
	@find scripts -type f \( -name "*.sh" -o -name "*.fish" -o -name "*.py" \) -exec chmod +x {} +

test-local: build
	@bash scripts/test-local-distribution.sh

test-battery-helper:
	@sh scripts/test-battery-charge-limit-helper.sh

install-bin:
	@install -Dm755 scripts/inir "$(DESTDIR)$(BINDIR)/inir"

install-shell:
	@python3 sdata/lib/runtime-payload.py copy --root . --target "$(DESTDIR)$(SHELL_INSTALL_DIR)"
	@chmod +x "$(DESTDIR)$(SHELL_INSTALL_DIR)/setup" "$(DESTDIR)$(SHELL_INSTALL_DIR)/scripts/inir"
	@find "$(DESTDIR)$(SHELL_INSTALL_DIR)/scripts" -type f \( -name "*.sh" -o -name "*.fish" -o -name "*.py" \) -exec chmod +x {} +
	@printf '{\n  "version": "%s",\n  "commit": "manual",\n  "installed_at": "%s",\n  "installedAt": "%s",\n  "source": "make-install",\n  "repo_path": "",\n  "repoPath": "",\n  "install_mode": "package-managed",\n  "installMode": "package-managed",\n  "update_strategy": "package-manager",\n  "updateStrategy": "package-manager",\n  "package_manager": "manual",\n  "packageManager": "manual",\n  "package_name": "source-install",\n  "packageName": "source-install",\n  "package_update_hint": "sudo make install",\n  "packageUpdateHint": "sudo make install"\n}\n' "$$(cat VERSION)" "$$(date -Iseconds)" "$$(date -Iseconds)" > "$(DESTDIR)$(SHELL_INSTALL_DIR)/version.json"

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
	@install -Dm644 assets/applications/inir.desktop "$(DESTDIR)$(APPLICATIONS_DIR)/inir.desktop"
	@install -Dm644 assets/applications/inir-settings.desktop "$(DESTDIR)$(APPLICATIONS_DIR)/inir-settings.desktop"
	@if [ -z "$(DESTDIR)" ]; then update-desktop-database -q "$(APPLICATIONS_DIR)" 2>/dev/null || true; fi

install-docs:
	@install -Dm644 README.md "$(DESTDIR)$(DOC_DIR)/README.md"
	@install -Dm644 docs/SETUP.md "$(DESTDIR)$(DOC_DIR)/SETUP.md"
	@install -Dm644 docs/IPC.md "$(DESTDIR)$(DOC_DIR)/IPC.md"

install-battery-helper:
	@install -Dm755 assets/helpers/inir-battery-charge-limit "$(DESTDIR)$(BATTERY_HELPER)"
	@install -Dm644 assets/polkit/org.inir.battery-charge-limit.policy "$(DESTDIR)$(BATTERY_POLICY)"
	@install -Dm644 assets/tlp/tlp-settings-schema.json "$(DESTDIR)$(TLP_SETTINGS_SCHEMA)"

install-thinkfan-helper:
	@install -Dm755 assets/helpers/inir-thinkfan "$(DESTDIR)$(THINKFAN_HELPER)"
	@install -Dm644 assets/polkit/org.inir.thinkfan.policy "$(DESTDIR)$(THINKFAN_POLICY)"

install: build install-bin install-shell install-systemd install-icon install-desktop install-docs install-battery-helper install-thinkfan-helper

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

uninstall: uninstall-systemd uninstall-desktop uninstall-icon uninstall-docs uninstall-shell uninstall-bin uninstall-battery-helper uninstall-thinkfan-helper
