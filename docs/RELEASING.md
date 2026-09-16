# Releasing Hadalis

Hadalis develops on `dev` and publishes stable releases from `stable`. Release publication is intentionally fail-closed: the release helper validates repository/package state, stages or reuses a GitHub draft release, syncs the Wiki, and only then makes the GitHub release public.

## Release preparation

Prepare release changes on `dev` first, validate them, then promote the intended release commit to `stable` using the project's normal deliberate stable-promotion process.

For release `X.Y.Z`, update these files together before tagging:

- `VERSION` -> `X.Y.Z`
- `CHANGELOG.md` -> a dated `## [X.Y.Z] - YYYY-MM-DD` section
- `distro/arch/inir-shell/PKGBUILD` -> `pkgver=X.Y.Z`
- `distro/arch/inir-meta/PKGBUILD` -> `pkgver=X.Y.Z`
- `sdata/dist-arch/inir-deps/PKGBUILD` -> `pkgver=X.Y.Z`
- `distro/arch/inir-shell/PKGBUILD` -> default `_source_ref` must be exactly `vX.Y.Z`
- the affected Arch `.SRCINFO` files -> regenerate them so committed package metadata matches the PKGBUILDs

`inir-deps` is the dependency-tracker meta-package that the source installer builds after dependency setup. Keep its committed `pkgver` aligned with `VERSION`; the installer stages a temporary recipe when it needs to inject the current version and must not rewrite the tracked PKGBUILD in-place.

The non-VCS `inir-shell` package must use the release tag as its committed default source ref. Do not leave `_source_ref` pointing at `stable`, `dev`, or another movable branch for a release. Do not try to bake the release commit SHA into the same release commit; the release tag is the immutable package identity used by the publication preflight.

After changing the source ref, regenerate `distro/arch/inir-shell/.SRCINFO`. Its source entry must resolve to the same tag archive, for example:

```text
.../archive/vX.Y.Z.tar.gz
```

Keep the package archive filename tagged as well; `scripts/release.sh publish` checks both the PKGBUILD default source ref and the committed `.SRCINFO` source entry.

## Validate before promotion

Run the repository checks that cover packaging, generated state, install lifecycle, documentation, QML startup, the Equalizer Phase 1 service boundary, and optional dependency boundaries:

```bash
make test-local
bash scripts/test-packaging-contract.sh
bash scripts/test-nix-module-contract.sh
bash scripts/test-doctor-dependency-routing.sh
bash scripts/test-equalizer-boundary-contract.sh
bash scripts/test-equalizer-service-contract.sh
bash scripts/test-optional-audio-deps-contract.sh
bash scripts/test-make-install-lifecycle.sh
bash scripts/verify-docs.sh
fish scripts/qml-check.fish --all
python3 scripts/lib/generate-ipc-registry.py --check
```

These Equalizer checks validate the current Phase 1 backend/service contract: disabled-by-default behavior, lifecycle/protocol guards, and the boundary that keeps backend execution out of Media presentation code. Future Equalizer presentation work such as the full UI, spectrum, presets surface, or multi-band redesign is not a release prerequisite here.

Preview the release notes before tagging:

```bash
scripts/release.sh notes X.Y.Z
```

The notes command is location-independent. When an output path is supplied, a relative path remains relative to the caller's current working directory.

## Tag the stable release commit

After the release-prep commit has been promoted to `stable`, use a clean checkout whose `HEAD` is exactly the commit to release. Create and push the release tag:

```bash
git switch stable
git pull --ff-only origin stable
git tag -a vX.Y.Z -m "vX.Y.Z"
git push origin vX.Y.Z
```

Do not move the tag after publication. `scripts/release.sh publish` requires all of the following before it stages a GitHub release:

- `VERSION` equals `X.Y.Z`
- release Arch package and dependency-tracker `pkgver` values equal `X.Y.Z`
- the checkout is clean, including untracked files
- `HEAD` equals `vX.Y.Z^{commit}`
- the tag commit is contained in `origin/stable`
- the tag exists on the remote and resolves to the same commit as the local tag
- `distro/arch/inir-shell/PKGBUILD` defaults `_source_ref` to exactly `vX.Y.Z`
- `distro/arch/inir-shell/.SRCINFO` points at the same tag archive
- GitHub CLI (`gh`) is available and authenticated for the repository
- the GitHub Wiki feature is enabled so repository docs can be synchronized
- the Wiki repository has been initialized with at least one page and is reachable with non-interactive Git credentials
- local Git `user.name` and `user.email` are configured so Wiki sync can create a commit when docs differ
- packaging, Nix, doctor dependency-routing, Equalizer Phase 1 boundary/service, optional-audio dependency, Makefile install/uninstall lifecycle, and documentation contracts all pass

The helper queries repository metadata and probes the Wiki Git remote before running the release contracts. If the Wiki feature is disabled, its repository is not initialized/accessible, credentials cannot reach it, or Git author identity is missing, publication stops before a draft release is created. Resolve the host prerequisite rather than bypassing the sync step.

## Publish

From that clean release checkout, run:

```bash
scripts/release.sh publish X.Y.Z
```

The publication sequence is:

1. Validate version, checkout, remote tag, package source identity, GitHub/Wiki publication prerequisites, packaging/dependency contracts, Equalizer Phase 1 backend/service boundaries, staged install/uninstall lifecycle, and documentation consistency.
2. Generate release notes.
3. Create a GitHub draft release, or reuse an existing draft for the same tag.
4. Sync repository docs to the GitHub Wiki.
5. Publish the staged draft release.

A published release with the same tag is never overwritten by the helper.

## Recovery and reruns

The publish command is designed to be rerunnable before final publication. If an earlier attempt created the draft but Wiki sync or the final publish step failed, run the same command again:

```bash
scripts/release.sh publish X.Y.Z
```

The existing draft is refreshed with the current generated title/notes and reused. The helper verifies that staging still leaves a draft before Wiki publication begins.

Disabled/uninitialized/inaccessible Wiki state and missing Git author identity are detected during preflight and do not create a draft. If Wiki sync becomes unavailable after preflight, the GitHub release remains a draft rather than becoming public with unsynchronized docs. If the final GitHub publish call fails after Wiki sync has completed, the draft remains available for the next retry; rerunning the same command completes the normal sequence.

If the release is already public, the helper stops instead of editing or replacing it. Corrections after publication should therefore follow a deliberate follow-up release or other maintainer-approved recovery path rather than mutating published release history ad hoc.

## Package metadata after release

The release tag is the source identity for the non-VCS Arch package. Development can continue on `dev` after publication, but do not silently retarget a published package recipe to a moving branch. Any later package recipe change for the same upstream version should use the normal Arch `pkgrel` mechanism and keep `.SRCINFO` synchronized with the PKGBUILD.
