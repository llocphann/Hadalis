# Cloud Storage — Buttons, Dropdowns, Dialogs and Responsive QML UX (research round 4)

**RESEARCH ONLY. No Rust/QML/runtime code, package changes, terminal commands or MEGA-account operations were executed.**  
Review date: 2026-09-30; Hadalis dev audit baseline: `ba1f6cda9b30f787777fb7d333fe90fcbe039ad8`. This document refines the [76-command/ten-domain functional design](CLOUD_STORAGE_MEGACMD_FULL_DESIGN.md), [upstream CLI source audit](CLOUD_STORAGE_MEGACMD_SOURCE_AUDIT.md) and [cross-client/SDK decisions](CLOUD_STORAGE_MEGACMD_PROTOCOL_DECISIONS.md). For exact buttons and dropdown choices in each section, see [the control and workflow matrix](CLOUD_STORAGE_MEGACMD_UX_CONTROL_MATRIX.md). Sizes here are **suggested design tokens**, not verified rendering measurements.

## 1. Fit with actual Hadalis UI — source-audited

| Existing component | Verified behavior | Cloud Storage use |
| --- | --- | --- |
| [`ContentPage.qml`](../modules/common/widgets/ContentPage.qml) | Shared scroll area; margins adapt to 16/24/32px and content is centered up to about 1,200px. | Use existing page; responsive rules depend on **available inner width**. Never force a second full-page scroll container. |
| [`SettingsMaterialPreset.qml`](../modules/common/widgets/SettingsMaterialPreset.qml), [`AbyssStyle.qml`](../modules/abyss/looks/AbyssStyle.qml) | Adaptive card radii, colors, opacity, font size and motion including Abyss-specific layers. | Design via theme tokens, not a new MEGA-themed gradient/card system. Shared Settings page works in Abyss/Waffle without conditional hand-drawn skins everywhere. |
| [`SettingsTaskNavigator.qml`](../modules/common/widgets/SettingsTaskNavigator.qml) + [`ConfigSelectionArray.qml`](../modules/common/widgets/ConfigSelectionArray.qml) | A flow-based segmented chooser which would wrap excessively with ten lengthy labels. | **Five primary groups** at wide widths; one compact group combo on narrow hosts; within each group keep 1–3 canonical child sections. |
| [`SettingsCardSection.qml`](../modules/common/widgets/SettingsCardSection.qml), [`SettingsGroup.qml`](../modules/common/widgets/SettingsGroup.qml) | Card sections are search-aware/collapsible. Collapsed content has input disabled, avoiding hidden click targets. | Standard page/card structure, no shadow "popup app" inside Settings. |
| [`RippleButton.qml`](../modules/common/widgets/RippleButton.qml), [`DialogButton.qml`](../modules/common/widgets/DialogButton.qml), [`AbyssButton.qml`](../modules/abyss/looks/AbyssButton.qml) | Shared buttons already style themselves for Abyss; simple dedicated AbyssButton is a separate popup idiom. | Use shared Settings controls for ordinary card actions; no sprinkling dedicated popup buttons into universal Settings. |
| [`StyledComboBox.qml`](../modules/common/widgets/StyledComboBox.qml), [`WSettingsDropdown.qml`](../modules/waffle/settings/WSettingsDropdown.qml) | Existing shared combo draws **one** chevron, caps popup height near 300px, scrolls long models and provides Abyss pill style. Waffle-specific row has its own renderer. | Reuse shared combo in the common Cloud Storage page. Don't reintroduce duplicate arrow, clipped labels, unstyled Qt menus or unverified Waffle conditional overrides. |
| [`ContextMenu.qml`](../modules/common/widgets/ContextMenu.qml), [`PopupToolTip.qml`](../modules/common/widgets/PopupToolTip.qml) | Lazy anchored menu with configurable hover/focus/outside policies; tooltip suppresses stale hover after click and accounts for keyboard focus. | Overflow opens **only on click/right-click/keyboard**, not hover; tooltip on compact icon buttons; close anchored menu before action that removes its source row. |
| [`WindowDialog.qml`](../modules/common/widgets/WindowDialog.qml), [`SelectionDialog.qml`](../modules/common/widgets/SelectionDialog.qml) | Existing shared dialog has embedded/liquid-host support. Its ordinary background press calls dismiss, with no built-in vendor-operation awareness. | Reuse appearance/hosting, but an eventual destructive dialog must implement **busy dismissal protection** or use a staged inline confirm; never assume the current dialog is a transaction lock. |
| [`SettingsNote.qml`](../modules/common/widgets/SettingsNote.qml), [`NoticeBox.qml`](../modules/common/widgets/NoticeBox.qml), [`MaterialPlaceholderMessage.qml`](../modules/common/widgets/MaterialPlaceholderMessage.qml) | Inline warning, actionable note and empty states exist. | Disabled buttons have a **visible inline reason**, not only a tooltip. |
| [`SettingsTaskLoadingState.qml`](../modules/common/widgets/SettingsTaskLoadingState.qml), [`SettingsPageHost.qml`](../modules/settings/SettingsPageHost.qml) | Short loading delay ~90ms, cached lazy page host. | Tie polling to **actual active page and section**, not `Component.onCompleted` or cached Loader residency. |

The current registry ends at index **35** (Automation) at the audited source revision. Future `cloud-storage` should append a stable key (tentative index 36, reverify when authorized). It will require the existing [registry's](../modules/settings/SettingsPageRegistry.qml) non-Abyss and Waffle applicability checks to explicitly allow the new index, alongside both families' Features & Services category, Settings search and saved-layout migrations. Do not reuse retired numeric slots or add ten root Settings entries.

## 2. Information architecture: avoid ten oversized tabs

Keep **ten stable child route IDs**, organized in five user-intent groups:

| Top-level (navigation) | Child screens (stable IDs) | Default |
| --- | --- | --- |
| Overview | Overview (`overview`) | Overview |
| Files | Drive (`drive`); Transfers (`transfers`) | Drive |
| Sync & Backup | Sync Folders (`sync`); Backups (`backups`) | Sync Folders |
| Sharing | Sharing (`sharing`); Contacts (`contacts`) | Sharing |
| Advanced | Mounts & Local Access (`mounts`); Account & Security (`security`); Preferences & Diagnostics (`preferences`) | Mounts |

Suggested deep-link scheme: existing `cloud-storage` Settings key + canonical child `section`. A route/search result resolves the parent group automatically, then reveals and focuses the target SettingsCardSection. Retain the ten-domain research model but **do not** draw ten top-level segmented buttons.

**Adaptive layout based on ContentPage's actual inner width, not monitor pixels:** Wide ≥960 logical px: show up to five group chips and use two-column overview/detail cards where semantically useful. Regular 640–959: show chips if they still fit on one row in current typography, otherwise collapse to group combo. Compact <640: one labeled `Area` ComboBox for five groups and a second `Section` combo or a two-choice segmented bar for children. These breakpoints are provisional: test at 100/125/150/200% text scale in standalone Settings, Abyss overlay, SettingsFocus and Waffle.

Conceptual header:  
`Cloud Storage                        [Installed, disconnected] [Connect]`  
`Area: [Overview | Files | Sync & Backup | Sharing | Advanced]`  
`Files > [Drive] [Transfers]                        [Refresh] [⋮]`  
`[Account/source state, last successful observation, actionable error strip]`  
`[SettingsCardSection / SettingsGroup content without nested full-window scrolling]`

Connect is a deliberate opt-in action that **may start MEGAcmd**; closing Settings does **not** stop external sync/backups. No auto-launch by simply opening the page; even a seemingly read-only normal vendor client can spawn the server. Other sections show the single shared Connect CTA only while disconnected.

## 3. Control selection and visual hierarchy

| Pattern | Recommended existing primitive | Exact UI policy |
| --- | --- | --- |
| One primary action in active card | Text-labeled themed `RippleButton` / `DialogButton` | "Connect", "Upload", "New sync", "New backup"; **one prominent CTA**, not 4 equal-color controls. |
| Secondary common action | Low-emphasis labeled button | "Refresh", "View issues", "Browse"; keep 2–3 per compact action row. |
| Compact repetitive actions | 36px+ icon button plus `PopupToolTip` and keyboard accessible name | "⋮", Refresh, Expand. Hover changes tint only; **hover never expands Cloud Storage controls or opens a submenu**. |
| Destructive / external security mutation | Clearly labeled button that **opens a review/confirmation**, never performs immediately | File delete, sync removal, bulk transfer cancellation, session revoke/logout, public shares and writable mount. |
| 2–3 frequent exclusive view modes | `ConfigSelectionArray`/`SelectionGroupButton` or `PillTabBar` within its appropriate compact context | List/Grid, Active/Completed, All/Upload/Download; no state-changing side effects on selection. |
| 4–8 **bounded, static** values | `StyledComboBox` | Sort key, filter target, filter scope, plan-gated share access levels, units; checked selection and no duplicate chevron. |
| Dynamic hundreds/thousands of choices | Searchable **folder/contact picker** derived from existing `SelectionDialog` only after search/virtualization design | Show breadcrumb, account, permission, stable identity, bounded results; never load a huge full remote tree into StyledComboBox. |
| Boolean **safe reversible preference** | `SettingsSwitch` / `ConfigSwitch` with description | Auto-refresh while visible (future), limited view preferences. **NOT** "Delete", "Logout", "Public access" or irreversible backup retention. |
| Numeric count | `ConfigSpinBox` plus units/help | Retention count, connection limit where installed capabilities verify range. |
| Rate | Number field + units combo + "Unlimited" mode, optional `StyledSlider` with Apply | Upload/download limits separate; no new vendor command at every slider drag tick. |
| Busy/empty/warning | `SettingsTaskLoadingState`, `MaterialPlaceholderMessage`, `SettingsNote` and action notice | "No results" differs from "Permission denied", "Unsupported parser" and "Not yet requested". |

Use `Appearance.colors`, `SettingsMaterialPreset`, `AbyssStyle` and `Appearance.animationsEnabled` as the color/radius/animation source. No fixed RGB "MEGA red", arbitrary shadow or separate blur shader. Proposed desktop hit area at least **36px** for row buttons and **40–44px** for primary/destructive touch-like targets where room permits, scaled to typography; W3C's [24 CSS-pixel target guidance](https://www.w3.org/WAI/WCAG22/Understanding/target-size-minimum) is a design reference, **not a claim that web CSS units certify native Qt accessibility**. Focus visible without clipped text; theme accent/error/surface tokens rather than hardcoded state colors.

### Button state contract (applies to every domain)

| State | UI | Behavior |
| --- | --- | --- |
| Ready | Icon + verb, visible role/focus | Mouse, Space, Enter dispatch the operation **once**. |
| Hover/focus | Subtle token tint; focus ring visible | Tooltip also available by **keyboard focus**; no layout motion or hover-triggered destructive action. |
| Disabled | Lower emphasis **and adjacent reason** | "Cannot pause: status unverified" is readable without hovering a disabled target. |
| Validating | Label unchanged, spinner/status beneath | Cancel before dispatch; parameters and account checked against fresh observed data. |
| Awaiting confirmation | Risk/identity/context review; Cancel default | No backend mutation until final explicit click; don't pre-focus Delete. |
| Dispatching | Busy indicator, repeated click blocked | External vendor action accepted/pending is **not** yet confirmed success. |
| Outcome unknown | Warning chip + `Recheck` (read-only) | **No automatic retry** after ambiguous timeout for writes; vendor may already have acted. |
| Confirmed | Authoritative row/chip update + brief nonsecret toast | Only after a fresh vendor read verifies the requested postcondition. |

Rows that disappear after a menu action must first close their anchored menu and move focus to persistent status or nearest parent. No active invisible input inside collapsed SettingsCardSection (already guarded by existing component).

## 4. Dropdowns, context menus and popovers

**Dropdown = choosing a value; menu = choosing an action.** A combo labeled "Sync status: Running/Synced" is misleading because the former is a run-state and the latter data status, neither a setting. Display status as distinct chips and action buttons "Pause sync"/"Enable sync". Similarly, a "Delete" dropdown *option* must never directly execute deletion.

Dropdown model rules: finite values, localized labels, stable item IDs independent of translated names, no snap-back to item 0 while an unsupported saved value is temporarily missing. The selected unavailable value is displayed as "Unsupported by installed MEGAcmd" with reason. Cap popup height/scroll like `StyledComboBox`, clamp/flip to current Settings host/available screen edges, preserve focus and current field text; if bound account or model changes during editing, close menu safely with "Account changed: review selection" rather than silently selecting a different remote folder.

Context menu: action on click/right-click/keyboard Menu key, never hover; one open menu at a time. In a row show only one pinned primary action plus `⋮`. Menu items cannot require long risk text: the **menu item opens** a scoped dialog/inline review instead. The existing ContextMenu has hover-loss closing behavior and Popup has Escape/outside policies—ensure keyboard navigation keeps menu alive, and test against actual standalone/overlay/focus anchor geometry. [Qt's Popup focus and closePolicy documentation](https://doc.qt.io/qt-6/qml-qtquick-controls-popup.html) is reference, not evidence current Hadalis uses all possible policies.

**Small popover:** sorter, view, safe selection. **Searchable dialog:** remote folder, target account/contact, path with duplicate names, multi-selected destination. **Full confirmation within current Settings host:** hazardous actions. No popup detached from owner surface just because Abyss has liquid transitions; respect currently used host and use `WindowDialog`'s embedded/liquid behavior only where its geometry really permits it. Existing WindowDialog background click dismisses: destructive in-flight actions require a future **guard** or inline staged confirmation. Do not reopen a reverted global confirmation redesign.

## 5. Forms and explanatory text

Long local/remote path inputs need **persistent field labels above**, not placeholder-only. Local "Browse" may require host file-picker integration; **no compatible picker was established in existing inspected source**. Until verified, offer a manually entered path only with Rust canonicalization/permission/nesting/symlink checks. Remote picker displays account, breadcrumb, root (Cloud Drive/Incoming shares/Rubbish), permission, and stable handle only after CLI output is safely parsed; arbitrary parsed names never authorize destructive writes.

Validation: format checks on blur/Next; remote existence checks on explicit review or bounded deliberate request, **not per keystroke vendor spawn**. Preserve form draft when changing child sections unless user explicitly discards. An account switch invalidates remote target IDs and shows a reason before clearing dependent fields. Show inline conflicts (duplicate name, unsafe path, unknown remote identity, another client possibly owning folder). Keyboard and screen reader labels describe each validation state.

**Toolbar:** compact action placement never covers long breadcrumb text. The primary action remains visible in compact mode; secondary actions collapse into a **safe-only** `⋮` menu. Do not hide the only warning/confirmation in a tooltip. Avoid making a mode toggle where consequences vary (e.g. "Enabled" when Disabled sync is re-created like a new sync).

## 6. Status chips, loading and error presentation

Separate three **orthogonal** sync indicators: `RUN_STATE` (Pending/Loading/Running/Suspended/Disabled), `STATUS` (None/Synced/Pending/Syncing/Processing), and error/issue count. Running **does not** mean Synced; "0 issues" only after successful `sync-issues` read. Backups preserve vendor distinctions `ONGOING/INCOMPLETE/ABORTED/MISCARRIED/SKIPPED`. Transfers preserve direction (upload/download) and provenance (manual/sync/backup). Each card has its **own** last successful observation timestamp; a fresh quota value does not authenticate old transfer status.

Display state dictionary: Installed/disconnected, Connecting, Signed out, Ready, Offline, Unresponsive, Unsupported, Stale, Error. A value with no observation displays "Unknown", **not** false 0/green. Header global errors get a restrained `SettingsNote` and actionable Recheck; row validation errors display adjacent to row/form; long command errors expand on deliberate user action; no automatic popups on every polling failure. Diagnostics preview only allows explicitly redacted data; never show secret link fragments, passwords, session IDs or raw vendor logs as tooltip content.

Use shared loading indicator after its short threshold (~90ms); slow operation shows current activity, not fictional percent animation. Source refresh updates only the active section/summary and should not rebuild an open dropdown or move keyboard focus on every polling tick. When page is hidden/cached by SettingsPageHost, **stop Hadalis polling**, not the independent vendor service.

## 7. Accessibility, responsive and interaction acceptance

- **Keyboard map:** Tab/Shift+Tab in visual order; Space/Enter on focused buttons; arrows and Enter in combobox; Escape closes **one overlay level** and restores focus to opener. Escaping a busy dialog must **never imply vendor mutation was cancelled**. File-row Delete key never directly removes files. No invented Ctrl+D=delete or Ctrl+L=logout.
- **Focus visibility:** selected option, focused button and active field get visible outline and accessible names. Scroll focused controls out from under sticky status/selection strip; see [WCAG 2.2 focus-not-obscured](https://www.w3.org/TR/wcag/#focus-not-obscured-minimum) as UX guidance.
- **Path labels:** visually elide with deliberate detail expansion; escaped/unknown Unicode, 300-character filenames, translated Vietnamese and 200% typography must not truncate the only distinguishing part of a path. No untrusted vendor strings rendered as HTML.
- **Color:** icons + words + timestamps; contrast and theme check in dark/light Abyss (including surface opacity), Waffle and default. Honor disabled animations; do not animate idle UI just to mimic sync activity.
- **Responsive:** no horizontal scrollbar needed to access essential action; row controls stack under metadata on compact widths. Multi-select action bar cannot cover focused rows. If there is drag-and-drop later, same operation exists in a labeled button.
- **Critical flows:** menu closes before its source row is deleted; account switch while a chooser is open cancels stale target; long vendor operation loses page visibility without duplicate dispatch; confirmation stays tied to its originating task; no optimistic green/success after helper process exit.

### Future visual/interaction verification (not performed)

- [ ] 10 routes in 5 groups accessible at <640, 640–959, ≥960 measured **inner content width** and 100/125/150/200% font scale.
- [ ] One chevron per combo; selected option checked; popup bounded/clamped in standalone, Abyss overlay, SettingsFocus and Waffle.
- [ ] All buttons and icon-only actions keyboard focusable and labeled, hover no layout shift, disabled with readable reason; destructive actions cannot execute from overflow selection alone.
- [ ] Modal/inline confirmations show scope, keep focus, resist busy-state dismissal and distinguish Cancel-before-dispatch from unknown-after-dispatch.
- [ ] Empty/error/stale/unsupported states unique, status chips legible at all text scales; no hidden poller or menu in a stale cached Loader.
- [ ] Owner approves real UI visuals after a separately authorized implementation; no visual acceptance is claimed by this research.

**Primary references:** Source files linked above, official [MEGAcmd 2.6.0 command guide](https://github.com/meganz/MEGAcmd/blob/6505327a5a7a0e94f26f611f83b024aeeb63582c/UserGuide.md), [Qt Popup behavior](https://doc.qt.io/qt-6/qml-qtquick-controls-popup.html) and [W3C pointer-target guidance](https://www.w3.org/WAI/WCAG22/Understanding/target-size-minimum).
