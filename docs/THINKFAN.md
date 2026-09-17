# ThinkFan Integration

Hadalis can expose ThinkFan status and switch between firmware-owned and ThinkFan-managed fan control. This integration is optional: the shell continues to run when ThinkFan, the helper, the service, or hardware telemetry is unavailable.

## Components

The integration has three pieces:

- `services/ThinkFanService.qml`
  - reads status through the unprivileged helper path;
  - requests profile changes through `pkexec`;
  - refreshes state periodically and fails closed when the helper cannot be started or times out.
- `/usr/libexec/inir-thinkfan`
  - reports ThinkFan/service/hardware state as JSON with `--status`;
  - applies `managed` or `firmware` ownership when invoked as root.
- `org.inir.thinkfan.policy`
  - authorizes privileged profile changes through Polkit.

The repo-managed `./setup install`, source/Make, and Arch package paths install the helper and policy. Package-managed setup runs leave those system files to the package manager. The current Nix package does not provision these privileged system-level files; see [NixOS / Home Manager](NIXOS.md#privileged-integration-limitation).

## Prerequisites

To use managed fan control, the machine must provide all of the following:

1. the `thinkfan` executable;
2. a system `thinkfan.service` visible to `systemctl`;
3. a valid ThinkFan configuration, normally `/etc/thinkfan.yaml` or `/etc/thinkfan.conf`;
4. the Hadalis helper at `/usr/libexec/inir-thinkfan`;
5. the Hadalis Polkit policy for privileged profile changes;
6. a working Polkit authentication agent when an interactive authorization prompt is required.

The Arch `inir-shell` packages treat `thinkfan` as an optional dependency. Installing Hadalis therefore does not by itself guarantee that `thinkfan.service` or a machine-specific ThinkFan configuration exists.

ThinkFan configuration is hardware-specific. Hadalis does not invent fan curves or sensor mappings automatically; configure and validate ThinkFan for the machine before enabling managed mode.

## Status contract

Status is intentionally unprivileged:

```bash
/usr/libexec/inir-thinkfan --status
```

The helper reports JSON containing:

- whether the `thinkfan` executable is available;
- whether `thinkfan.service` is installed;
- whether the service is active and enabled;
- the effective profile (`managed` while the service is active, otherwise `firmware`);
- the detected ThinkFan config path;
- fan RPM/level when the kernel exposes compatible ThinkPad ACPI telemetry;
- a machine-readable reason when the integration is unavailable or under firmware control.

Hadalis treats malformed output, an unsupported schema, helper launch failures, and status timeouts as unavailable state rather than assuming fan control succeeded.

## Switching profiles

The shell uses the privileged helper through `pkexec`. The equivalent commands are:

```bash
pkexec /usr/libexec/inir-thinkfan --apply managed
pkexec /usr/libexec/inir-thinkfan --apply firmware
```

`managed` performs the following checks/actions:

- requires the `thinkfan` executable;
- requires `thinkfan.service` to exist;
- runs `systemctl enable --now thinkfan.service`;
- verifies that the service became both active and enabled.

`firmware` runs `systemctl disable --now thinkfan.service` and verifies that the service is no longer active or enabled.

The helper returns failure when these postconditions are not met. After every apply attempt, the shell re-reads status through the unprivileged path instead of trusting the privileged command blindly.

## Hardware telemetry

Fan RPM and fan level are read only when `/proc/acpi/ibm/fan` is readable. This interface is hardware/kernel-specific. A missing RPM or level value does not by itself mean ThinkFan control is broken; the service state remains the authoritative ownership signal.

On systems without that interface, Hadalis can still report whether ThinkFan is installed, active and enabled, but RPM/level may remain unavailable.

## Troubleshooting

Check the helper and service independently before debugging the UI:

```bash
/usr/libexec/inir-thinkfan --status
systemctl status thinkfan.service
systemctl is-enabled thinkfan.service
command -v thinkfan
```

If the shell reports `ThinkFan helper is unavailable` or `/usr/libexec/inir-thinkfan` does not exist, the upstream `thinkfan` package alone is not enough: Hadalis also needs its bridge helper and Polkit policy. A repo-managed install can be repaired by rerunning the system-setup stage through `./setup install`; for a targeted repair from a current Hadalis checkout, use:

```bash
sudo make install-thinkfan-helper
```

Then verify the bridge directly with `/usr/libexec/inir-thinkfan --status` and refresh/restart the shell. Package-managed Arch installs should reinstall/update `inir-shell` or `inir-shell-git` rather than overwrite package-owned files with the Make target.

If `--status` reports `thinkfan-unavailable`, install ThinkFan and ensure `thinkfan` is in the system `PATH`.

If it reports `service-unavailable`, install or provide a valid `thinkfan.service` unit before requesting managed mode.

If managed mode fails to start, inspect the system service journal:

```bash
journalctl -u thinkfan.service -b
```

If the shell reports an apply-start failure, verify that `/usr/bin/pkexec`, the Hadalis helper, the Polkit policy, and an authentication agent are available.

If the shell reports an apply timeout, inspect ThinkFan/systemd directly before retrying. The UI intentionally times out privileged apply operations instead of leaving its state permanently busy.

For ThinkFan configuration or sensor/fan-curve errors, validate ThinkFan outside Hadalis first. Hadalis only switches service ownership; it does not replace ThinkFan's own hardware configuration and validation.

## Packaging notes

- Repo-managed `./setup install` installs `/usr/libexec/inir-thinkfan` and its Polkit policy during the system-setup stage; package-managed installs are left untouched.
- `make install` installs `/usr/libexec/inir-thinkfan` and its Polkit policy, with helper paths rewritten when the Makefile packaging variables request a non-default location.
- `inir-shell` and `inir-shell-git` install the helper/policy under the standard Arch system paths and list `thinkfan` as an optional dependency.
- Nix currently packages the shell/runtime but does not install the privileged helper/policy into `/usr/libexec` and `/usr/share/polkit-1/actions`.

The integration should therefore be treated as an optional capability whose availability is discovered at runtime rather than a shell startup requirement.
