# Workflow-first QML Code Editor

Status: Phase 0 A–E investigation is complete within the documented prototype
scope. Phase 1 production work is now in progress: Reference -> Code Workflow,
primitive session persistence, horizontal ii Bar runtime registration, production
picker, Geometry canvas, Source Preview and a source-backed semantic projection IR
now form the production read-only foundation. Selected reviewed anchors gain
transient CST byte-range evidence when native parser capability is present;
missing/ambiguous anchors fail closed and no ranges are persisted into the IR
manifest. Generic semantic extraction and stable Arch parser promotion remain unfinished.
The first literal-property transform now has preview, semantic identity, exact
artifacts, a qualified atomic commit/rollback lifecycle and guarded user-triggered
Apply. Direct bindings now have a preview-only identifier/member-expression
subset, while direct-binding Apply and broader writes remain disabled. The
2K edge-editing gate is restricted to reviewed data edges that can re-resolve to
that semantic binding subset; visual propagation edges are not mutation targets.
Disconnect now has verified preview-only deletion semantics. Connect uses an
explicit reviewed-target selection plus coordinator-backed preview history in
Settings: identity is parent semantic anchor + absent binding name + source
expression, and the two parser requests use a same-SHA primitive handoff. An
isolated qmllint-backed research proof can establish bool compatibility for the
first reviewed fixture. Cycle research now has two fail-closed layers: a
same-object parser closure and a source-backed local-singleton fallback that
resolves the real Clock dependency through Config.qml to the literal
bar.verbose terminal. A research-only qualification coordinator can now compose
that acyclic evidence with the qmllint type proof only when both describe the
same Clock SHA and exact Connect candidate SHA, then reverify both Clock and
Config hashes after proof generation. The transaction now defines a
non-authorizing promotion boundary that can retain only an allowlisted primitive
safety snapshot and re-hash its Clock/Config dependencies across history/reload.
Research proof generators remain outside the runtime payload, no promotion UI is
exposed, and TYPE/CYCLE UNKNOWN continue to block Connect writes. A research-only
2K-M preparation helper can now re-run that qualification, reconstruct the exact
candidate from current parser state and stage mode-0600 rollback/candidate/
manifest files outside the runtime tree without changing source or authorizing
Apply.
The on-demand parser boundary still degrades to reviewed IR when native
capability is absent.
Curve sustained-memory acceptance remains HOLD. Phase 2 can write only the
qualified literal-property subset; package-managed/read-only source and every
unsupported semantic construct remain fail-closed.
See [feasibility evidence](CODE_WORKFLOW_FEASIBILITY.md),
[Phase 1 status](CODE_WORKFLOW_PHASE1.md),
[Phase 2 status](CODE_WORKFLOW_PHASE2.md) and
[Phase 0 continuation constraints](CODE_WORKFLOW_HANDOFF.md).

This document records the design direction for a Hadalis code editor that exposes the running Quickshell/QML shell as an editable workflow/dataflow graph.

## Product decision

**The graph is the editor.**

This feature must not become a conventional text editor with a graph panel attached to it. It is not intended to reproduce VS Code, Zed, Vim, Monaco, or a file-tree + text-buffer + terminal workflow inside Settings.

The primary authoring surface is a visual workflow canvas:

- QML components are represented as semantic nodes or collapsible subflows.
- properties and bindings are ports and data wires;
- signals and handlers are event wires;
- functions, configuration writes, IPC calls, and external effects are action nodes;
- Loader/LazyLoader behavior is represented as lifecycle/instantiation flow;
- source text exists as supporting evidence, patch preview, diagnostics, and an escape hatch for expressions that cannot be represented honestly in the graph.

A user should be able to understand and modify the important behavior of a selected Hadalis module without first locating the file or reading a full QML document.

The central interaction model is:

~~~text
running shell
    |
    | Pick component
    v
semantic runtime target
    |
    +---- runtime state/values
    |
    +---- source/CST analysis
              |
              v
       workflow graph model
              |
      visual graph editing
              |
              v
      minimal source patches
              |
       validate + apply
              |
       Quickshell reload
              |
      stable target rebind
~~~

## Where it belongs in Hadalis

The user-facing page belongs in Settings -> Reference, above Shortcuts.

At the time of this research, Settings keeps historical numeric page slots stable and the Reference category contains:

~~~text
Reference
|- Shortcuts  [9]
'- About      [13]
~~~

The new page must be appended to the page registry rather than inserted before page 9. Page indices can be persisted externally, and the repository deliberately keeps retired indices 18, 19, 21, 27, and 28 in place for compatibility.

The expected arrangement is therefore:

~~~text
Reference
|- Code Workflow   [new appended index; 29 at research time]
|- Shortcuts       [9]
'- About           [13]
~~~

The registry entry should be non-essential so Easy Mode can remain a user-oriented settings surface:

~~~qml
{
    key: "code-workflow",
    name: Translation.tr("Code Workflow"),
    icon: "account_tree",
    desc: Translation.tr("Inspect and edit live QML as a workflow"),
    essential: false,
    component: "modules/settings/CodeWorkflow.qml"
}
~~~

The exact numeric index must be resolved again from the current dev HEAD when implementation begins.

## Repository constraints that shape the design

### 1. Settings pages are lazy and cached

Both the standalone Settings window and the Settings overlay use SettingsPageHost. The host keeps only a small number of pages resident and asynchronous-loads non-current pages.

The workflow editor must therefore keep important session state outside the page instance. Navigating away from Code Workflow must not destroy the selected runtime target, graph history, dirty transformations, or picker result.

Session state belongs in a singleton/service, not inside CodeWorkflow.qml.

### 2. ContentPage is the wrong root for the canvas

ContentPage is a StyledFlickable designed for vertically stacked settings cards. It adds page margins, a maximum content width, and a vertical scrolling contract.

A workflow canvas needs the opposite:

- full available width and height;
- its own infinite/pannable coordinate space;
- wheel zoom and pointer pan;
- independently scrollable side panels;
- no outer Flickable stealing gestures.

CodeWorkflow.qml should therefore use a full-bleed Item as its root and manage its own panes. It can still reuse Hadalis visual tokens and shared controls, but it should not wrap the canvas in ContentPage.

### 3. The broad iiPerimeter runtime is retired

The current connected-surface contract explicitly says not to recreate the old modules/perimeter runtime, feature registry, cutover policy, or panel-slot composition system.

The workflow editor must have its own narrowly scoped semantic registry. A CodeWorkflowRegistry is an inspection/editing registry only; it must not become another shell composition owner and must not be built on a resurrected PerimeterFeatureRegistry.

### 4. Hadalis already has separate editing domains

Hadalis separates desktop-widget editing from persistent shell-layout editing. ShellEditSession is a useful architectural precedent because it owns a dedicated session state instead of overloading the edited components themselves.

Code Workflow should follow the same separation:

~~~text
widgetEditMode
    -> desktop widget placement

ShellEditSession
    -> persistent panel geometry/placement

CodeWorkflowSession
    -> QML behavior/dataflow inspection and editing
~~~

These modes should be mutually exclusive where their overlays would conflict.

### 5. BarContent already exposes a semantic component boundary

BarContent.qml is an excellent first implementation target. It already has semantic module IDs and a mapping from IDs to component factories:

~~~text
leftSidebarButton
activeWindow
resources
media
workspaces
clock
utilButtons
battery
rightSidebarButton
tray
timer
shellUpdate
weather
spacer
~~~

This is much more useful than recursively exposing every Item, Rectangle, RowLayout, Text, and MouseArea.

The first working version should instrument the Bar semantic modules before attempting generic whole-shell introspection.

## The workflow editor is not a source editor

The following UI direction is explicitly out of scope as the primary experience:

~~~text
+-----------+----------------------+----------------+
| File tree | full text editor     | symbols        |
|           | QML lines            | outline        |
|           | cursor/selection     |                |
+-----------+----------------------+----------------+
| terminal / diagnostics                             |
+----------------------------------------------------+
~~~

That is a conventional IDE layout. Recreating it would duplicate tools users already have and would not solve the requested problem.

The intended layout is:

~~~text
+------------------------------------------------------------------------------+
| CODE WORKFLOW     LIVE   Bar > Media             [Pick] [Pin] [Fit] [100%]  |
+--------------------+--------------------------------------+------------------+
| TARGETS / ADD      |                                      | INSPECTOR        |
|                    |          WORKFLOW CANVAS             |                  |
| Search...          |                                      | Properties       |
|                    |  +-----------+      +-------------+  | Runtime          |
| Bar                |  | MPRIS     |----->| Media       |  | Connections      |
|  Workspaces        |  +-----------+      |             |  | Diagnostics      |
|  Clock             |                     | player   o--+ |                  |
| *Media             |                     +------|------+ |                  |
|  Tray              |                            v        |                  |
|  Utilities         |                     +-------------+  |                  |
|                    |                     | PlayerCtrl  |  |                  |
| Dashboard          |                     +-------------+  |                  |
| Sidebars           |                                      |                  |
| Dock               |                                      |                  |
+--------------------+--------------------------------------+------------------+
| Source Preview | Patch | Diagnostics        (optional, collapsible drawer)  |
+------------------------------------------------------------------------------+
~~~

The canvas remains visually dominant at every supported size.

## Workspace layout

### Context bar

The top bar is always visible and answers four questions:

1. Are we inspecting a live runtime target or a static source graph?
2. Which semantic component/subflow is open?
3. Which output/runtime instance is selected?
4. Are there unapplied graph transformations?

Suggested controls:

~~~text
[LIVE] Bar > Media > PlayerControl
DP-1
[Pick component] [Pin] [Undo] [Redo] [Fit] [-] 100% [+]
Dirty: 2
[Apply workflow]
~~~

Apply should be explicit. Moving a node on the canvas must never write source code.

### Left pane: Targets and Add

The left pane is not a filesystem explorer.

It has two purposes:

**Targets**

A semantic tree of inspectable running features:

~~~text
Bar
  Workspaces
  Clock
  Media
  Tray
  Utilities

Left Sidebar
  Widgets
  AI
  Music

Right Sidebar
  Controls
  Calendar
  Weather

Dashboard
Dock
Waffle
~~~

The tree may show availability/residency status for lazy components.

**Add**

A node palette for graph-authoring operations:

~~~text
Component
Property / constant
Condition
Transform
Signal event
Action
Config write
Service source
Loader / lifecycle
Script expression
Comment / group
~~~

Recent targets and recently used node types can appear at the bottom.

On narrow widths the left pane collapses before the canvas is reduced.

### Center pane: workflow canvas

The canvas is the primary editor.

Required interactions:

- pan on empty space;
- wheel/gesture zoom centered around pointer;
- fit selection / fit graph;
- box selection;
- multi-select;
- drag nodes;
- drag a wire from an output port to a compatible input port;
- disconnect/reconnect wires;
- create a node by dropping from the palette;
- context action to expand upstream/downstream dependencies;
- double-click a component/subflow to drill into it;
- breadcrumb navigation back out of a subflow;
- collapse component internals;
- optional minimap/navigation view for large flows.

Graph layout metadata is user-state only. Node x/y coordinates, collapsed state, pane widths, zoom, and viewport do not belong in QML source and must not dirty the repository.

### Right pane: semantic inspector

The right pane edits the selected graph object rather than acting as a text outline.

Suggested tabs:

~~~text
Properties | Runtime | Connections | Diagnostics
~~~

Examples:

**Properties**

~~~text
Node: Media
Type: Component
Source: modules/bar/Media.qml

player            <binding>
compact           false
visible           true
~~~

**Runtime**

~~~text
Instance: bar/media@DP-1
visible: true
width: 164
height: 36
player.identity: mpd
player.playbackState: Playing
~~~

**Connections**

~~~text
player
<- MprisController.activePlayer

clicked
-> openMediaPopup

visible
<- Config.options.bar.modules.media && useShortenedForm < 2
~~~

**Diagnostics**

Parser errors, unsafe transforms, unresolved service references, reload failures, stale runtime target warnings, and source-conflict warnings belong here.

On narrow widths the inspector collapses into a drawer. The canvas remains the main surface.

### Bottom drawer: supporting source evidence

The bottom drawer may contain:

~~~text
Source Preview | Patch | Diagnostics
~~~

It is intentionally secondary.

Source Preview is read-only by default and can use the syntax-highlighting infrastructure already present in modules/sidebarLeft/aiChat/MessageCodeBlock.qml.

Patch shows exactly what graph transformations will change before Apply.

Diagnostics shows parser/reload/validation output.

A small Script/Expression node may expose an inline expression field for logic that cannot be visualized safely. That field is an escape hatch, not a full editor.

There should be no permanent full-file editor, file tree, terminal, or command palette that shifts the product back toward a conventional IDE.

## Workflow semantics for QML

QML is not purely sequential. A truthful workflow representation has to model declarative composition, reactive property dependencies, events, imperative effects, and object lifecycle separately.

### Edge types

The graph should distinguish at least four edge classes.

#### Data / binding edge

Represents a reactive QML binding.

~~~text
MprisController.activePlayer
            |
            v
       Media.player
~~~

A data wire means the destination value is derived from the source/expression and reevaluates when dependencies change.

#### Event / signal edge

Represents signal emission and a handler path.

~~~text
MouseArea.clicked
       |
       v
togglePlayback()
~~~

Event wires should look different from binding wires. They are directional occurrences, not reactive values.

#### Action / effect edge

Represents an imperative side effect:

~~~text
button.clicked
      |
      v
Config.setNestedValue(...)
~~~

Other action/effect nodes include:

- service method calls;
- IPC calls;
- Quickshell.execDetached;
- state mutation;
- popup open/close actions;
- file/process operations.

#### Lifecycle / instantiation edge

Represents conditional object creation/residency and dynamic component selection.

Examples:

~~~text
enabled panel condition
        |
        v
LazyLoader.active
        |
        v
module instance
~~~

or:

~~~text
module id
   |
   v
sourceComponent lookup
   |
   v
Loader
~~~

Lifecycle flow is important in Hadalis because both panel composition and Settings rely heavily on LazyLoader/Loader behavior.

### Composition is primarily grouping, not wiring

Parent/child QML structure should not create a wire between every visual object. Doing so would produce unreadable graphs.

Composition should normally be represented by:

- component/subflow containment;
- group frames;
- breadcrumbs;
- collapsed component nodes;
- drill-down navigation.

Only semantically important instance relationships should become explicit graph edges.

### Port rules

Most properties belong as ports/rows inside a component node rather than as standalone nodes.

Example:

~~~text
+-----------------------------------+
| PlayerControl.qml       COMPONENT |
+-----------------------------------+
o player                            |
o compact                           |
|                                   |
| STATE                             |
| playing              true         |
| position             01:42        |
|                                   |
| EVENTS                            |
| togglePlayback                  o |
| next                            o |
+-----------------------------------+
~~~

Use standalone property/transform nodes only when they clarify a real transformation or are shared by multiple destinations.

### Node taxonomy

The initial node model should support:

| Node kind | Meaning |
| --- | --- |
| Component/Subflow | A semantic QML component or reusable flow |
| Service/Source | Config, Appearance, MprisController, NiriService, etc. |
| Constant/Property | Literal/input value when independent representation is useful |
| Transform | Derived expression or value transformation |
| Condition/Branch | Boolean gating or event branch |
| Event | Signal source |
| Action/Effect | Function call, mutation, IPC, process or external effect |
| Loader/Lifecycle | Loader, LazyLoader, active/source/sourceComponent behavior |
| Adapter/Bridge | External integration or data normalization boundary |
| Script/Expression | Opaque imperative/expression escape hatch |
| Comment/Group | Human documentation and visual organization |

A node may expose runtime status without changing its static semantic type.

## Editing operations and generated QML

Graph operations should translate to constrained source transformations.

### Connect data output to property input

Intent:

~~~text
MprisController.activePlayer -> Media.player
~~~

Possible QML result:

~~~qml
player: MprisController.activePlayer
~~~

### Set a literal property

Editing a port value generates or changes a literal assignment/binding.

~~~text
compact = true
~~~

becomes the appropriate QML property assignment at the source anchor.

### Connect a signal to an action

A signal wire may generate an inline handler when the action is local and unambiguous:

~~~qml
onClicked: root.togglePlayback()
~~~

When the signal target is external or a Connections object is semantically required, the transform should generate/update Connections rather than forcing an inline handler.

### Add a condition

A condition node may map to:

- a declarative binding expression;
- a ternary expression;
- a guard in a signal handler;
- Loader.active.

The editor must choose a representation based on the surrounding flow and show the generated patch. It must not pretend all branches have one QML equivalent.

### Add a component

Dropping a component inside a component/subflow group may create a child object declaration.

The node must know its legal parent/source location. Arbitrary drag placement on the canvas is not sufficient evidence for a source insertion point.

### Loader editing

A Loader/LazyLoader node exposes lifecycle ports such as:

~~~text
active
source
sourceComponent
loaded item
~~~

This is particularly valuable in Hadalis because module residency is often the reason a target exists or disappears at runtime.

### Delete/disconnect

Disconnecting a binding or deleting a node is potentially destructive. The editor must show the affected source patch and any now-unbound/default property state before Apply.

## Visual workflow rules

### Direction

Default graph flow is left-to-right:

~~~text
sources/services -> transformations/conditions -> component state -> events/actions/effects
~~~

Secondary branches can grow vertically.

This matches common workflow/dataflow conventions and reduces wire crossings.

### Component/subflow collapse

Large QML components must collapse into one node with only their public/semantic ports visible.

Double-click drills into the subflow. The breadcrumb becomes the navigation mechanism.

This is essential for Hadalis. Exposing every child object in BarContent or DashboardContent at once would be unusable.

### Relevant-first expansion

Opening a target should show:

- the selected component;
- direct upstream dependencies;
- direct downstream effects;
- its most important child/subflow boundaries.

Everything else stays collapsed.

A command can expand one additional upstream/downstream hop. The editor should enforce a visible-node budget rather than rendering a whole shell graph by default.

### Wire readability

Prefer stable routed curves or orthogonal segments. Crossing detection and rerouting can be improved later.

Semantic differentiation should be restrained:

- data/binding wire;
- event wire;
- effect wire;
- lifecycle wire;
- error/stale state.

Do not turn every service/type into a different neon color. Hadalis theme tokens should own most visual identity.

### Runtime motion

Runtime tracing should be subtle and diagnostic:

- a changed property port may pulse briefly;
- an event wire may animate once when the signal fires;
- a hot path may show a small count/rate badge;
- stale/unavailable nodes dim instead of disappearing abruptly;
- parser/runtime errors use the error token.

Do not animate every reactive reevaluation continuously; that would create noise and unnecessary rendering cost.

## Live component picking

### Do not use activeFocusItem as the picker

Keyboard focus is not a reliable definition of the visual component the user wants. Many meaningful QML Items never take keyboard focus.

The picker must use intentionally registered semantic targets.

### Semantic target registration

Inspectable modules should register stable metadata such as:

~~~qml
CodeWorkflowTarget {
    targetId: "bar/media"
    label: "Media"
    sourcePath: "modules/bar/Media.qml"
    runtimeObject: root
    parentTargetId: "bar"
}
~~~

The exact API is not fixed yet, but the contract should include:

- stable target ID;
- human label;
- source path;
- parent/subflow target ID;
- runtime object reference when in the main shell process;
- output/window/instance identity;
- screen-space geometry provider;
- semantic tags;
- inspectable flag;
- allowlisted runtime properties;
- sensitive-property markers.

Registration must be semantic and intentional. Do not recursively register every QQuickItem.

### Geometry and hit testing

QQuickItem coordinates can be mapped to global/screen coordinates. Registered targets should publish a screen-space rect when their geometry/window changes.

During pick mode, a per-output overlay can compare pointer position against the registered rects and choose the most specific eligible target.

Selection precedence should favor:

1. visible/enabled registered targets;
2. the target on the pointer's output;
3. deeper semantic target;
4. smaller containing rect;
5. explicit priority override when necessary.

This avoids trying to run recursive childAt() traversal across multiple independent layer-shell windows.

### Picker interaction

Expected flow:

~~~text
Press Pick component
        |
        v
workflow session enters pick mode
        |
        v
hover a registered shell component
        |
        +-> outline + label + source path
        |
click
        |
        +-> click is consumed by picker overlay
        +-> selectedTargetId is locked
        +-> pick mode exits
        +-> graph loads/recenters
~~~

Escape cancels without changing the current target.

The overlay must consume the selection click so inspecting Media does not also open the Media popup.

### Multi-output

The picker should follow the same general per-screen surface pattern already used by other Hadalis editing overlays.

Runtime target identity must distinguish semantic ID from instance ID:

~~~text
semantic: bar/media
instance: bar/media@DP-1
~~~

The graph normally keys source semantics by semantic ID while Runtime shows the selected instance.

### Self-inspection exclusion

The following must be non-inspectable by default:

- Code Workflow Settings page;
- picker overlay;
- workflow HUD;
- Settings chrome;
- workflow node/edge delegates.

Otherwise the tool can recursively select its own implementation instead of the shell target beneath it.

Developer-only opt-in self-inspection can be considered later.

## Overlay Settings versus standalone Settings

This is a critical architecture boundary.

### Overlay Settings

The Material Settings overlay is loaded by the main shell. In this mode the workflow page can communicate with the main-shell CodeWorkflowSession/Runtime service directly.

However, Settings itself covers a large part of the desktop. Pick mode should therefore temporarily suspend/hide the Settings overlay:

~~~text
Code Workflow page
   |
   | Pick
   v
capture editor/session viewport state
   |
hide Settings overlay
   |
run picker over live shell
   |
lock target
   |
restore Settings directly to Code Workflow
   |
restore graph context + load target
~~~

The operation should feel like browser DevTools element picking, not like closing the editor permanently.

### Standalone Settings window

settings.qml is a standalone Settings application/window path and must not assume it can dereference QObject instances owned by the main shell.

The architecture must therefore separate runtime authority from editor presentation.

Proposed long-term boundary:

~~~text
MAIN SHELL
+--------------------------+
| CodeWorkflowRuntime      |
| semantic target registry |
| picker                   |
| runtime observers        |
| runtime snapshots        |
+------------+-------------+
             |
             | IPC / local stream
             |
+------------v-------------+
| Code Workflow UI         |
| Settings overlay OR      |
| standalone settings      |
+--------------------------+
~~~

The main shell remains authoritative for runtime targets.

A minimal IPC surface could expose JSON/string functions conceptually like:

~~~text
codeWorkflow.listTargets()
codeWorkflow.beginPick()
codeWorkflow.cancelPick()
codeWorkflow.selected()
codeWorkflow.snapshot(targetId)
codeWorkflow.graphRuntime(targetId)
~~~

The exact names should be chosen during implementation and added through the normal IpcHandler registry tooling.

For an MVP, standalone Settings may poll a compact runtime snapshot only while the workflow page is visible. If real-time signal tracing becomes important, replace polling with a small local stream/socket mechanism rather than increasing polling frequency indefinitely.

Do not serialize raw QObject pointers across processes.

### Implementation staging option

The lowest-risk path is:

1. make live workflow inspection work in the in-process Settings overlay;
2. keep static source workflow view available everywhere;
3. add the standalone runtime bridge once the graph/runtime protocol is stable.

This avoids designing the first graph model around cross-process serialization before its semantics are proven.

## Static analysis and source round-trip

### Do not use regex as the source model

Regex is acceptable for tiny diagnostics or searches. It is not acceptable as the canonical editor parser.

The editor must preserve:

- comments;
- whitespace outside modified ranges;
- source order;
- object nesting;
- property bindings;
- inline components;
- signal handlers;
- Connections blocks;
- JavaScript bodies;
- Loader/sourceComponent structure.

### Required parser output

The source analyzer needs a lossless or source-range-preserving CST/AST representation with:

- node type;
- source path;
- exact start/end range;
- parent range;
- identifiers;
- property declarations/assignments;
- signal declarations and handlers;
- function declarations;
- object/component instantiations;
- Loader/LazyLoader-relevant bindings;
- JavaScript expression/body ranges;
- comments/trivia association where possible.

The workflow domain model must be separate from parser nodes. Parser details can change without forcing UI node IDs to change.

### Candidate parser research

tree-sitter-qmljs is a plausible candidate because it exposes a QML/JS grammar and incremental syntax tree.

It must not be adopted blindly. Known grammar edge cases, including grouped-binding ambiguity, mean it needs a corpus test against Hadalis before it can be trusted for writes.

Other parser approaches may be evaluated if they provide better QML fidelity. The design should depend on the required source-range contract, not on one library name.

The existing qmlformat-based repository checks remain useful for validation, but qmlformat is not the workflow editor's semantic model.

### Minimal-patch rule

Graph edits should generate the smallest practical source patch.

Do not pretty-print or rewrite an entire QML file for a one-property graph change.

Example:

~~~diff
-    visible: root.useShortenedForm < 2
+    visible: root.useShortenedForm < 2 && MprisController.activePlayer !== null
~~~

Unrelated spacing/comments remain untouched.

### Conflict protection

When a file is parsed, record an identity such as content hash plus source revision.

Immediately before Apply:

1. re-read the file;
2. compare it to the parsed base;
3. if it changed externally, stop;
4. reparse/rebase the graph transformation;
5. ask the user to review the regenerated patch.

Never overwrite a concurrent external edit silently.

### Unsupported/opaque constructs

When a QML or JavaScript construct cannot be round-tripped safely, represent it as an opaque Script/Expression node.

The node may allow a constrained inline edit of that exact source range only when validation is reliable. Otherwise it is read-only.

Honest partial support is preferable to a visual model that silently changes program meaning.

## Apply and reload lifecycle

### Editing is transactional

Graph manipulation changes an in-memory transformation model.

It does not immediately modify source.

Workflow state:

~~~text
clean
  |
graph edit
  v
dirty transformations
  |
  +-> Undo/Redo
  |
  +-> Patch Preview
  |
Apply workflow
  v
source conflict check
  |
minimal patches
  |
syntax validation
  |
atomic write
  |
Quickshell reload
  |
runtime re-registration
  |
stable target rebind
  v
clean
~~~

### Stable IDs matter

Runtime QObject identity is ephemeral across reload.

Do not key editor history to object pointers.

Use stable semantic IDs and stable source node IDs, for example:

~~~text
targetId: bar/media
instanceId: bar/media@DP-1
nodeId: modules/bar/Media.qml::binding:visible:<stable-anchor>
~~~

Exact source-node ID generation needs a parser spike, but the important rule is that it survives routine reload and unrelated source shifts as well as reasonably possible.

### Reload success

After Quickshell reload completes:

- runtime targets re-register;
- the session resolves selectedTargetId again;
- runtime object/instance is rebound;
- the graph keeps its viewport and selected semantic node;
- dirty state clears only after the applied source is confirmed.

### Reload failure

On reload/parse failure:

- keep the graph transformation history;
- show the parser/reload diagnostics;
- keep the patch/source evidence available;
- do not claim the workflow was applied successfully.

A future implementation may offer an automatic source rollback from the exact pre-apply snapshot, but it must first check that no other actor changed the file in the meantime.

### Package-managed source

Hadalis supports repo-synced and package-managed installation paths.

The workflow editor must surface writability explicitly:

~~~text
Writable source
Read-only/package-managed source
Static/source unavailable
~~~

It must not silently invoke privilege escalation to edit /usr/share paths.

Read-only mode still provides useful graph inspection and runtime tracing.

## Undo/redo model

Undo and redo should operate on semantic workflow commands:

~~~text
Connect port
Disconnect port
Change literal
Add condition
Add action
Delete node
Move node
Collapse subflow
~~~

Only semantic source-changing operations enter the source transformation history.

Pure presentation operations such as pan, zoom, node x/y movement, panel resizing, and collapse state can have a lightweight UI history or immediate metadata persistence but do not mark source dirty.

## Workflow metadata persistence

Graph presentation metadata must remain separate from both Config and QML source.

Persist per-user editor metadata in state/cache, keyed by source/workflow identity:

- node positions;
- collapsed subflows;
- viewport and zoom;
- pane widths;
- recent targets;
- pinned target;
- optional custom comments/groups that are explicitly editor-only.

The exact state path should use Hadalis/Quickshell state infrastructure chosen at implementation time.

Changing graph layout must never produce a source-code diff.

## Runtime inspection policy

### Allowlist, do not dump QObject blindly

ObjectUtils is not an inspector and intentionally strips objectName, children, parent, object, and metaObject-like properties.

The workflow runtime should expose an allowlisted semantic property set from each target plus a small safe base set such as visibility/geometry where appropriate.

Do not enumerate every QObject property and send it to the UI by default.

### Sensitive values

Targets/services can contain private data.

The runtime registry needs a sensitive-property mechanism. Values such as passwords, tokens, provider API keys, credentials, clipboard content, and private user text must not appear merely because a component references them.

Suggested target metadata:

~~~text
runtimeProperties: [...]
sensitiveProperties: [...]
runtimeSummary: {...safe derived values...}
~~~

Sensitive data remains redacted in the graph, Runtime pane, logs, and IPC snapshots.

### Security-sensitive surfaces

Do not enable live picking over:

- lock-screen password input;
- polkit/authentication secrets;
- session/credential prompts;
- other explicitly sensitive entry controls.

Screen lock should cancel picker mode.

## Performance constraints

A workflow editor can easily become more expensive than the component it is debugging. Avoid that.

### Semantic registry only

Do not walk and serialize the full QObject/QQuickItem tree every frame.

Register semantic targets intentionally and update geometry only when relevant geometry/window state changes or at a throttled rate during pick mode.

### Subscribe only to visible runtime data

Runtime property tracing should prioritize:

- selected target;
- visible graph nodes;
- selected inspector node;
- explicit trace/watch ports.

Collapsed/offscreen dependencies do not need high-frequency updates.

### Node budget

Use a practical visible graph budget. When expansion would exceed it, collapse dependency groups or ask the user to open another subflow.

The exact number must be benchmarked, but the design target should be a focused workflow rather than hundreds of simultaneously animated objects.

### Event tracing

Signal/event animations should be sampled/batched. A high-frequency signal must not schedule a QML animation for every emission.

### Edge rendering

Canvas, Shape, or another QML-native renderer can be evaluated for wires. The chosen implementation must be benchmarked with realistic graphs before adding heavy shadow/blur effects to every edge.

## Styling and interaction details

The editor should use Hadalis theme tokens, not invent an unrelated IDE theme.

Suggested visual rules:

- component nodes use normal elevated surfaces;
- service/source nodes use a restrained secondary treatment;
- selected nodes use primary outline/accent;
- event/data/effect/lifecycle ports use distinct shape/icon plus modest color differences;
- warning/error markers use existing semantic colors;
- runtime-active state can use a small pulse or edge tracer;
- dirty nodes show a compact dot/badge;
- read-only nodes show a lock indicator.

Ports should align with the property/event row they represent. Do not place all sockets in an arbitrary cluster on the node edge.

Hovering a wire should highlight both endpoints and show its semantic description.

Selecting a port should show:

- current source/binding;
- runtime value;
- generated QML mapping;
- diagnostics;
- usages/dependents when available.

## Empty state

The first view should teach the workflow interaction instead of showing an empty infinite canvas.

Suggested empty state:

~~~text
                    [account_tree]

                  Inspect live QML

Pick a component from the running shell to see its
bindings, events, services and actions as a workflow.

                [ Pick component ]

Recent targets
Bar / Media
Dashboard / Weather
Left Sidebar / Music
~~~

Static source browsing can be offered as a secondary action, but not as a file-tree-first editor.

## Recommended architecture

Names are provisional, but responsibilities should remain separated.

### services/CodeWorkflowSession.qml

Owns editor/session state:

- active target ID;
- selected runtime instance;
- pick mode;
- pinned state;
- graph/subflow breadcrumb;
- selection;
- dirty transformation stack;
- undo/redo;
- restore state after Settings/picker transition.

It must not own shell composition.

### services/CodeWorkflowRegistry.qml

Main-shell semantic target registry:

- register/unregister targets;
- stable target IDs;
- runtime object references;
- geometry;
- output/window instance identity;
- source path;
- runtime allowlists;
- sensitivity metadata.

This is intentionally unrelated to the retired perimeter feature registry.

### services/CodeWorkflowRuntime.qml

Main-shell runtime authority:

- picker orchestration;
- safe runtime snapshots;
- runtime trace subscriptions;
- target resolution after reload;
- IPC facade for standalone Settings.

This may be combined with Session for a small MVP, but the conceptual boundary should remain clear.

### Source analysis backend

A parser/helper layer owns:

- source loading;
- CST/AST parse;
- domain graph extraction;
- minimal-patch generation;
- conflict detection;
- syntax validation;
- atomic writes.

This may start as an external helper process if that is safer/easier than implementing parsing in QML JavaScript.

### modules/codeWorkflow/

Suggested UI files:

~~~text
modules/codeWorkflow/
  CodeWorkflowCanvas.qml
  WorkflowNode.qml
  WorkflowPort.qml
  WorkflowEdge.qml
  WorkflowGroup.qml
  WorkflowMinimap.qml
  WorkflowTargetTree.qml
  WorkflowPalette.qml
  WorkflowInspector.qml
  WorkflowSourcePreview.qml
  WorkflowPatchPreview.qml
  WorkflowDiagnostics.qml
  WorkflowPickerOverlay.qml
  WorkflowTarget.qml
~~~

The final file split should follow measured complexity; this list is a responsibility map, not a requirement to create every file immediately.

### modules/settings/CodeWorkflow.qml

Thin Settings page shell:

- full-bleed page root;
- context bar;
- left pane;
- canvas;
- inspector;
- bottom drawer;
- binds to CodeWorkflowSession/runtime/backend services.

It should not contain parser logic or runtime registry logic.

## Interaction with existing Hadalis editors

Code Workflow must not replace:

- BarModuleOrderEditor for ordinary module arrangement;
- Shell Layout editor for moving/resizing persistent surfaces;
- desktop widget edit mode;
- Dashboard layout editor.

Those are user-facing layout editors.

Code Workflow is a developer/reference surface for understanding and changing QML behavior.

Where useful, a semantic workflow node may link to an existing layout editor rather than duplicating its specialized UX.

## First implementation target: Bar

Bar is the recommended first vertical slice because BarContent already exposes stable semantic module IDs and Loader-backed module composition.

A useful first graph for Media could be:

~~~text
             +------------------+
             | Config.bar.*     |
             +--------+---------+
                      |
                      v
+----------------+  +-------------------+   +------------------+
| MprisController|->| Media             |-->| Media popup      |
| activePlayer   |  |                   |   | / PlayerControl  |
+----------------+  | visible           |   +------------------+
                    | player            |
                    | clicked           |
                    +---------+---------+
                              |
                              v
                     +------------------+
                     | GlobalStates /   |
                     | popup action     |
                     +------------------+
~~~

The first version does not need to expose every inner Rectangle or animation.

Success means a maintainer can:

1. pick Media from the running Bar;
2. see why it is visible;
3. see which service supplies its player;
4. see its click/event path;
5. drill into PlayerControl if registered;
6. change a safe binding/literal visually;
7. inspect the generated patch;
8. apply and survive reload while preserving the workflow context.

## Platform-derived design rules (research pass 2)

This section tightens the design after a second pass over the current Hadalis tree and primary documentation for Quickshell, Niri, Qt/QML, workflow editors, projectional editors, Tree-sitter, and LSP tooling.

These are implementation rules, not optional inspiration.

### The UX is projectional, while QML text remains canonical

The requested editor is closer to a projectional/structured editor than to a conventional text editor.

Projectional editors such as JetBrains MPS manipulate a structured program model and render a chosen projection of that model. That is the right interaction analogy for Code Workflow: the user edits semantic concepts through graph nodes, ports, subflows, inspectors and contextual actions.

Hadalis cannot copy MPS literally because existing QML files remain the canonical persisted representation and must stay normal Git-reviewable source.

Use this hybrid contract:

~~~text
canonical QML text
      |
      v
lossless CST + source map
      |
      v
semantic workflow IR
      |
      v
workflow projection
      |
 user command
      |
      v
semantic transformation
      |
      v
minimal source patch
      |
      v
canonical QML text again
~~~

Rules:

- The workflow graph is the primary editing projection.
- The semantic workflow IR is the primary in-memory edit model.
- QML text remains the persistent source of truth.
- The CST/source map preserves exact ranges, comments and untouched formatting.
- Never create a second persisted AST that can silently diverge from QML.
- Reparse after every successful Apply and reconcile the workflow model from resulting source.
- Unsupported syntax becomes an opaque Script/Expression construct instead of being rewritten optimistically.

This is intentionally neither a text-editor clone nor a fully AST-persisted language workbench.

References:

- https://www.jetbrains.com/help/mps/mps-faq.html
- https://www.jetbrains.com/help/mps/editor.html
- https://www.jetbrains.com/help/mps/basic-notions.html

### Hard constraints and soft diagnostics

Structured editing should distinguish operations that are structurally impossible from temporarily invalid drafts.

Hard constraints reject the operation before it mutates the workflow model. Examples:

- connecting an event output to an incompatible data input;
- placing a construct where the QML grammar/source anchor cannot legally contain it;
- recursive subflow creation;
- writing to a read-only runtime output;
- modifying package-managed source in write mode;
- exposing a sensitive target/property.

Soft diagnostics keep the draft visible but block Apply until resolved. Examples:

- unresolved identifier;
- missing required property;
- stale source anchor after an external edit;
- temporarily disconnected required input;
- an unsupported expression that must become an opaque node.

Do not destroy user work merely because the draft is not currently applicable.

### Contextual creation is part of the workflow language

The global Add palette is useful but must not be the only authoring path.

Required contextual actions:

- drag from an output port -> show compatible destinations/transforms/actions;
- drag from an input port -> show compatible sources/transforms;
- Quick Add on empty canvas -> show constructs legal in the current subflow;
- Quick Add on a wire -> show transforms/conditions/adapters that can be inserted into that connection;
- Add inside a component group -> show child constructs legal at that source anchor.

This follows the useful parts of Node-RED Quick Add and Blueprint pin-driven node creation.

References:

- https://nodered.org/docs/user-guide/editor/workspace/nodes
- https://dev.epicgames.com/documentation/unreal-engine/nodes-in-unreal-engine

### QML bindings are reactive dependencies, not execution arrows

Qt defines property bindings as relationships that are reevaluated when dependencies change.

Therefore:

- data/binding edges mean reactive dependency;
- event edges mean signal occurrence;
- effect/action edges mean imperative consequence;
- lifecycle edges mean instantiation/residency;
- ordinary binding wires must never be described as execution order;
- graph layout must never invent left-to-right execution between independent bindings.

For example:

~~~qml
visible: root.enabled && service.ready
~~~

may expand to:

~~~text
root.enabled ----+
                 +--> AND transform --> visible
service.ready ---+
~~~

or remain one collapsed expression node when expansion adds noise.

Reference:

- https://doc.qt.io/qt-6.8/qtqml-syntax-propertybinding.html

### Assignment and binding are different edit commands

Quickshell's QML guide highlights an important rule: assigning a plain value to a property that currently has a binding removes that binding, while an explicit binding stays reactive.

The workflow UI must therefore distinguish:

~~~text
Bind to...
Set literal and replace binding
Disconnect binding
Restore previous binding
~~~

Dragging a data wire to a property means create/replace a reactive binding, not copy the source's current runtime value once.

When a literal replaces an existing binding, Patch Preview must say so explicitly.

Reference:

- https://quickshell.org/docs/guide/qml-language/

### Scope and ComponentBehavior must be part of semantic resolution

Identifier resolution depends on QML component/object scope. Qt documents ComponentBehavior: Bound as a guarantee that nested components stay in their original context; the default behavior is Unbound.

The analyzer must retain:

- file/component scopes;
- nested and inline component boundaries;
- ids and import aliases;
- ComponentBehavior pragma;
- object/property scope;
- JavaScript lexical scope inside handlers/functions.

Matching identifier text is not enough evidence to create an editable semantic wire.

Reference:

- https://doc.qt.io/qt-6.8/qtqml-documents-structure.html

### Use four primary edge grammars

Blueprint's distinction between data and execution pins is useful, but QML needs a four-way mapping:

~~~text
DATA / BINDING
  reactive dependency

EVENT
  signal occurrence

EFFECT / ACTION
  imperative call or mutation

LIFECYCLE
  loader/instance residency
~~~

Only event/effect paths may use execution-like visual treatment. Normal property bindings do not get execution pins.

Reference:

- https://dev.epicgames.com/documentation/unreal-engine/nodes-in-unreal-engine

### Subflows are foundational, not cosmetic

Node-RED and Blueprint both use collapsed subgraphs to control complexity.

Code Workflow rules:

- semantic QML components can appear as collapsed subflows;
- meaningful public properties/signals become boundary ports;
- internals stay hidden until drill-down;
- Enter/double-click opens the subflow;
- breadcrumb returns to parent;
- expansion is scoped to the current graph rather than the entire shell;
- recursion is rejected;
- reusable semantic components and editor-only visual groups remain distinct.

References:

- https://nodered.org/docs/user-guide/editor/workspace/subflows
- https://dev.epicgames.com/documentation/unreal-engine/nodes-in-unreal-engine

### Reroutes, groups and alignment are editor metadata

Reroute nodes, visual groups, comments, alignment, distribution and grid placement improve readability but do not change QML semantics unless the user explicitly invokes a source-level transformation.

Therefore they do not mark source dirty.

References:

- https://nodered.org/docs/user-guide/editor/workspace/arrange
- https://nodered.org/docs/developing-flows/documenting-flows

## Quickshell 0.3.x rules

Hadalis contains explicit Quickshell 0.3 compatibility behavior. Code Workflow must target the installed runtime contract and feature-detect optional/newer APIs.

### Never force LazyLoader completion just to inspect

Quickshell 0.3.1 distinguishes asynchronous loading from forced synchronous completion. Its documentation also warns that reading a loader item while loading can force completion and block.

The inspector must not materialize a dormant Hadalis feature merely because Code Workflow is open.

The target registry needs lifecycle state even when runtimeObject is absent:

~~~text
static-known
unloaded
loading
resident
stale/unloading
error
~~~

For an unloaded target, show static workflow/source information and lifecycle conditions. Runtime values attach only when the object already exists or the user explicitly requests loading.

Do not read LazyLoader.item for discovery.

Reference:

- https://quickshell.org/docs/v0.3.1/types/Quickshell/LazyLoader/

### Stable semantic identity must not depend on QObject identity

QML objects are ephemeral across reload.

Use separate identities:

~~~text
targetId   = stable semantic feature
instanceId = target plus output/instance
runtimeRef = current nullable QObject reference
sourceId   = source construct anchor
~~~

Quickshell Reloadable IDs and PersistentProperties may improve reload continuity for Code Workflow-owned UI, but they do not replace targetId/sourceId.

Phase 0 runtime correction: persist only primitive values (serialize viewport
metadata as a JSON string). A `property var` JS object in PersistentProperties
lost its usable value across actual QQmlEngine replacement in the probe. Never
persist QObject references or engine-owned QJSValue objects. Restore semantic IDs
and deserialize metadata after the persistence loaded signal, before attaching
new runtime instances. This is covered by three source-triggered ordinary reloads
in Spike E, including a selected module that remains unloaded.

References:

- https://quickshell.org/docs/v0.2.1/types/Quickshell/Reloadable/
- https://master.quickshell.org/docs/types/Quickshell/PersistentProperties

### Picker geometry is owned by QML/Quickshell

QsWindow item mapping helpers are not reactive by themselves. Quickshell exposes windowTransform to invalidate mappings when window transforms change, and TransformWatcher can invalidate relationships when geometry along an item path changes.

A target geometry adapter should therefore depend on:

- target x/y/width/height/visible;
- QsWindow.windowTransform when mapping to window/global space;
- TransformWatcher when parent-chain transforms can move the target;
- output/screen identity;
- devicePixelRatio when crossing logical/physical coordinate boundaries.

Do not poll mapToGlobal for every target every frame.

Do not use Niri as the authority for inner-QML geometry.

References:

- https://quickshell.org/docs/v0.3.1/types/Quickshell/QsWindow/
- https://quickshell.org/docs/v0.2.1/types/Quickshell/TransformWatcher/

### Picker input exists only while Pick mode is active

Quickshell Region/QsWindow masks support click-through window areas.

Normal Code Workflow operation must not leave a screen-wide input surface resident.

During Pick mode the selection click must be consumed so clicking Media/Clock/etc. does not also trigger the underlying control.

Recommended transient surface:

~~~text
one PanelWindow per connected output
full-output geometry
exclusiveZone 0 / no reservation
overlay layer
stable namespace quickshell:code-workflow-picker
transparent visuals
pointer interception only while PICKING
destroy/hide immediately after select or cancel
~~~

References:

- https://quickshell.org/docs/v0.3.1/types/Quickshell/Region/
- https://quickshell.org/docs/v0.3.1/types/Quickshell/QsWindow/

### Never use Exclusive keyboard focus for the picker

Quickshell defines None, OnDemand and Exclusive keyboard-focus modes. Exclusive locks other windows out; OnDemand has documented focus-retention caveats on some systems.

Code Workflow must never use Exclusive.

Prototype two acceptable paths:

1. Pointer-first picker with keyboardFocus None and explicit pointer/cancel affordance.
2. Transient Escape-capable picker with OnDemand only while picking, destroyed immediately afterward and live-tested for correct Niri focus restoration.

Reference:

- https://quickshell.org/docs/v0.3.0/types/Quickshell.Wayland/WlrKeyboardFocus/

### Niri requires Overlay for picker visibility over fullscreen

Niri documents that focused fullscreen windows can cover top-layer surfaces. Overlay-layer surfaces remain above fullscreen windows, and top/overlay surfaces remain above Niri Overview.

The transient picker should therefore use the overlay layer.

This rule applies to the picker only; it is not a reason to move normal Hadalis surfaces to Overlay.

References:

- https://github.com/niri-wm/niri/wiki/Layer%E2%80%90Shell-Components
- https://github.com/niri-wm/niri/wiki/Fullscreen-and-Maximize

### Give the picker a stable namespace

WlrLayershell.namespace identifies a layer-shell surface to external tools and cannot be changed after connection.

Use a stable namespace such as:

~~~text
quickshell:code-workflow-picker
~~~

This helps Niri diagnostics, layer rules and self-inspection filtering.

Reference:

- https://quickshell.org/docs/v0.3.0/types/Quickshell.Wayland/WlrLayershell/

### IpcHandler is a scalar control plane

Quickshell IpcHandler registers explicitly typed scalar arguments/returns such as string, int, bool, real and color. It is not a direct arbitrary JS-object transport.

If standalone Settings uses IpcHandler, rich payloads must be encoded as strings, for example JSON text:

~~~text
listTargets(): string
snapshot(targetId): string
graphRuntime(targetId): string
beginPick(): void
cancelPick(): void
event(payload: string)
~~~

Do not send raw QObject references or claim arbitrary arrays/objects are native return types.

High-rate runtime tracing should use a dedicated local stream/socket if it becomes necessary rather than repeated subprocess-style IPC snapshot calls.

Reference:

- https://git.outfoxxed.me/quickshell/quickshell/src/branch/master/src/io/ipchandler.hpp

### Atomic file writes still need a transaction protocol

Quickshell FileView atomicWrites uses a replacement file and rename for a successful single-file write.

Code Workflow still needs:

1. source revision/hash conflict check;
2. semantic transform;
3. parse/validation;
4. atomic write;
5. reload observation;
6. post-write parse;
7. target rebind;
8. failure/rollback handling.

Atomic per-file writes do not make a multi-file transformation atomic. Defer multi-file graph edits until a transaction strategy exists.

Reference:

- https://quickshell.org/docs/v0.3.1/types/Quickshell.Io/FileView/

### One owner controls reload

Quickshell watches config files by default and exposes reloadCompleted/reloadFailed. A soft reload attempts window reuse; hard reload recreates.

For the first writable one-file path:

~~~text
atomic source write
      |
      v
normal Quickshell file watcher
      |
      v
wait for reloadCompleted or reloadFailed
      |
      v
rebind semantic target
~~~

Do not write the file and immediately issue a second explicit reload that races the watcher.

If future multi-file transaction support temporarily disables watching, the transaction controller may issue one explicit soft reload after all files commit. Hard reload is fallback, not the normal Apply action.

Reference:

- https://quickshell.org/docs/types/Quickshell/Quickshell/

### Workflow presentation state is not product Config

Node positions, viewport, zoom, collapsed scopes, pane sizes, recent targets and editor-only comments are editor state.

Prefer existing Hadalis persistence where appropriate or the Quickshell per-shell state directory. Do not add product Config keys solely for canvas layout.

Reference:

- https://quickshell.org/docs/types/Quickshell/Quickshell/

## Niri-derived rules

### Niri provides compositor context, not semantic QML discovery

Niri IPC is useful for outputs, workspaces, focused window/output and layer-shell diagnostics.

It cannot identify an inner QML Media, Clock or Sidebar component under the pointer.

Keep the ownership split:

~~~text
QML/Quickshell semantic registry
    -> target identity and target geometry

Niri
    -> compositor context and layer-surface diagnostics
~~~

### Use event streams instead of polling

Niri's event stream sends complete current state first and then updates. Niri recommends direct UNIX-socket access for more complex integrations.

If Code Workflow needs extra compositor context beyond the existing NiriService, extend/reuse the event-driven service rather than adding an editor polling loop.

Consumers must tolerate related updates that are not always atomic.

Reference:

- https://github.com/niri-wm/niri/wiki/IPC

### Treat Niri JSON as an extensible protocol

Use machine-readable JSON, not human-formatted niri msg output.

Parsers should tolerate additive fields/variants and avoid exact full-object comparisons.

Reference:

- https://github.com/niri-wm/niri/wiki/IPC

### niri msg layers is diagnostic identity, not component geometry

Layer namespaces are useful to verify that the picker exists on the expected output/layer with the expected identity.

Inner QML component rectangles remain QML/Quickshell-owned.

Reference:

- https://github.com/niri-wm/niri/wiki/Configuration%3A-Layer-Rules

### Pick interaction should be immediate

Niri's design principles favor immediate, predictable actions.

Therefore:

- Pick enters immediately;
- hovered semantic target highlights immediately;
- click selects immediately;
- cancel exits immediately;
- there is no second confirmation for target picking.

Source mutation still uses explicit Apply because it changes code.

Reference:

- https://github.com/niri-wm/niri/wiki/Design-Principles

## Source-analysis and diagnostics rules

### Tree-sitter may be the CST layer, not the semantic graph

Tree-sitter is designed for incremental concrete-syntax parsing and range-aware reparsing. Those are useful properties for preserving source positions and editing efficiently.

A QML grammar does not automatically provide QML/Hadalis semantics such as:

- import/type resolution;
- ComponentBehavior context rules;
- property compatibility;
- singleton semantics;
- Loader targets;
- semantic target IDs;
- safe rewrite transformations.

If tree-sitter-qmljs passes a Hadalis corpus spike, use it as the CST/range layer under a separate semantic analyzer.

Never expose raw CST nodes directly as the product workflow model.

References:

- https://tree-sitter.github.io/tree-sitter/
- https://tree-sitter.github.io/tree-sitter/using-parsers/3-advanced-parsing.html

### Every source-backed transform is revisioned

A source-backed semantic node needs at least:

~~~text
sourcePath
base revision/content hash
construct kind
source start/end range
semantic anchor
~~~

Before Apply, re-read current source and re-resolve the semantic anchor. Never trust stale byte ranges after an external edit.

### qmlls/LSP is optional enrichment

LSP is useful for diagnostics, definitions, references and type information.

Quickshell's own setup documentation recommends qmlls but documents limitations around malformed structure, Quickshell Singleton handling, Quickshell type documentation and root imports.

Therefore:

~~~text
CST + Hadalis/QML semantic analyzer
    = authoritative graph + rewrite model

qmlls/LSP
    = optional diagnostics/navigation enrichment
~~~

Code Workflow must still work when qmlls is absent.

References:

- https://microsoft.github.io/language-server-protocol/
- https://quickshell.org/docs/guide/install-setup/

## Revised workspace rules

### Canvas stays dominant

Node-RED treats the central workspace as the place where flows are built and sidebars as supporting tools. Code Workflow should follow that hierarchy.

Normal desktop proportions:

~~~text
context bar                                44-52 px
Targets/Add pane                          200-240 px
workflow canvas                           dominant remaining area
semantic inspector                       280-340 px
Source/Patch/Diagnostics drawer           closed by default
~~~

Source Preview does not receive a default half-screen split.

References:

- https://nodered.org/docs/user-guide/editor/
- https://nodered.org/docs/user-guide/editor/workspace/

### Minimap is conditional

A navigator/minimap is useful only when graph extent exceeds the viewport.

It should be toggleable, non-semantic, hidden for small graphs and hidden/collapsed before reducing the main canvas on narrow layouts.

### Standardize node state badges

Use compact status badges:

~~~text
DIRTY   semantic source transformation pending
ERROR   diagnostic blocks or warns Apply
LIVE    runtime instance resident
LOAD    runtime target loading
OFF     static/unloaded target
LOCK    read-only/package-managed source
STALE   runtime object lost during reload/rebind
~~~

Dirty never means the user merely moved a node.

### Selection supports graph reasoning

Required selection/navigation tools:

- lasso/marquee;
- additive multi-select;
- select upstream dependencies;
- select downstream dependents/effects;
- focus connected path;
- fit selection.

These matter more here than text-editor multi-cursor behavior.

### Wire insertion is first-class

Quick Add on a wire can insert a compatible transform/condition/adapter.

~~~text
A --------> B

A --> Transform --> B
~~~

The semantic backend chooses the legal QML representation. Node position never determines source execution or insertion semantics.

### Runtime tracing is diagnostic

Runtime behavior may be shown through restrained tracing:

- brief event/effect wire animation;
- small pulse when a watched data value changes;
- rate/count badge for high-frequency activity;
- no execution animation on ordinary binding edges;
- tracing throttled/disabled when Code Workflow is not visible.

## Picker state machine

Use an explicit state machine:

~~~text
IDLE
  |
  v
PREPARING
  - save editor target/viewport
  - suspend conflicting edit modes
  - hide/suspend Settings surface if needed
  |
  v
PICKING
  - per-output overlays
  - semantic hover resolution
  - click consumed
  |
  +-- cancel ------+
  |                |
  +-- select --> LOCKED
                    |
                    v
                 RESTORING
                    |
                    v
                   IDLE
~~~

Rules:

- one picker session at a time;
- screen lock/security surfaces cancel Pick;
- widget edit and Shell Layout edit cannot compete with Pick;
- output removal reconciles overlays;
- failed selection keeps the previous target;
- restore the editor only after the Code Workflow page is ready.

## Apply state machine

Source mutation also uses explicit states:

~~~text
CLEAN
  |
semantic edit
  v
DIRTY
  |
Apply
  v
VALIDATING
  |
  +-- error --> DIRTY + diagnostics
  |
  v
WRITING
  |
  v
WAITING_FOR_RELOAD
  |
  +-- reload failed --> APPLY_FAILED
  |
  v
REBINDING
  |
  +-- target no longer resident --> APPLIED_STATIC
  |
  v
CLEAN
~~~

A valid change can intentionally make a target unload. Source-applied and runtime-resident are separate states.

## Revised MVP gate

Do not start writable graph transforms until the read-only Bar prototype proves all of these:

1. semantic registration;
2. reactive geometry tracking;
3. per-output picker lifecycle;
4. picker clicks never leak to underlying controls;
5. dormant LazyLoaders remain dormant;
6. source-to-workflow parsing;
7. correct binding versus event/effect semantics;
8. subflow drill-down;
9. safe runtime-property overlay;
10. reload/rebind continuity.

The first writable transformations should remain narrow:

- literal-to-literal replacement;
- simple direct binding replacement from a compatible source;
- direct binding disconnect with an explicit fallback value;
- unambiguous existing signal -> existing compatible action connection.

New arbitrary JavaScript, component creation, complex conditions and multi-file edits remain later phases.

## Research-pass-2 review failures

An implementation should fail review if any of these occur:

- opening Code Workflow instantiates dormant LazyLoaders;
- an ordinary QML binding is presented as execution order;
- replacing a binding with a literal is silent;
- target geometry depends on niri msg layers;
- picker uses Exclusive keyboard focus;
- an invisible picker overlay intercepts input outside Pick mode;
- standalone Settings expects raw QObject transfer;
- IpcHandler is treated as an arbitrary object transport;
- a source write races file-watch reload with a second immediate reload;
- canvas metadata changes QML source;
- qmlls is treated as the canonical parser/rewriter;
- raw CST nodes become product graph nodes;
- ComponentBehavior/scope is ignored during resolution;
- package-managed source triggers automatic privilege escalation;
- Source Preview dominates the workspace by default;
- node placement implies QML execution order;
- unsupported syntax is rewritten merely because a parser accepted it.

## Implementation-readiness rules (research pass 3)

This pass focuses on the remaining implementation questions: graph rendering/input, parser-backend boundaries, live-surface stability during picking, keyboard/accessibility, and the exact Phase 0 proof plan.

The design is now sufficiently specified to enter implementation feasibility work. The remaining unknowns are empirical performance/parser/runtime questions that must be answered by prototypes rather than by more architecture speculation.

### Repository corpus confirms that the semantic analyzer must cover real QML, not a toy subset

The current Hadalis tree contains broad use of:

- pragma ComponentBehavior: Bound;
- inline component declarations;
- Loader and LazyLoader;
- Connections and Binding;
- explicit Qt.binding rebinding;
- property aliases and required properties;
- Behavior, State and Transition;
- Variants;
- IpcHandler;
- Process and FileView.

Bar/Media is representative rather than artificially simple: it combines Config bindings, Mpris service state, Timers, Connections, local functions, MouseArea event paths, popups, property transforms and imperative effects.

Therefore the parser spike must run against a representative Hadalis corpus rather than a few synthetic examples. A parser that accepts a trivial Item with properties is not sufficient evidence.

The initial corpus should include at minimum:

- modules/bar/BarContent.qml
- modules/bar/Media.qml
- modules/dashboard/DashboardContent.qml
- modules/overview/OverviewNiriWidget.qml
- modules/settings/SettingsPageHost.qml
- services/NiriService.qml
- services/ShellEditSession.qml
- one Waffle composition file
- one file with explicit Qt.binding
- one file with Binding
- one file with inline component declarations and nested Component/Loader boundaries
- one file with State/Transition
- one file with Variants/LazyLoader

Phase 0 correction: nested inline component **declarations** are not supported
by QML. Keep them as a negative validation fixture, not a required valid corpus
example. Tree-sitter 0.3.1 and qmlformat 6.11.2 accept this construct;
qmllint 6.11.2 emits a `[syntax]` diagnostic but can still exit zero. Validation
must consume diagnostics, not only parse success or process exit status.
See [Qt inline components](https://doc.qt.io/qt-6/qtqml-documents-definetypes.html)
and [the Phase 0 evidence](CODE_WORKFLOW_FEASIBILITY.md).

### Parser backend decision: separate syntax engine, semantic analyzer and validator

No one parser/tool should be asked to do all jobs.

Use three layers:

~~~text
CST / source ranges
    |
    v
Hadalis QML semantic analyzer
    |
    v
Workflow IR

plus independently:

qmlformat/qmllint/qmlls
    -> validation and optional diagnostics
~~~

#### Tree-sitter-qmljs is the leading CST candidate, not yet a committed dependency

Tree-sitter is a good fit for source-range-preserving incremental parsing. The current tree-sitter-qmljs grammar is derived from Qt's QML/JS grammar and provides Rust bindings.

However, the grammar documents an important ambiguity: grouped property-binding syntax can parse as an object definition. This means the workflow semantic analyzer must disambiguate using QML context/type knowledge or mark the construct opaque.

Phase 0 must test the current grammar against the Hadalis corpus and record:

- files parsed without error;
- unsupported constructs;
- ambiguous constructs;
- comment/range preservation;
- byte-for-byte no-op round trip;
- stability of semantic anchors after unrelated line insertions.

Do not add the parser as a permanent runtime dependency until packaging is proven across supported Hadalis install paths.

#### Do not add Node.js as a new runtime requirement just for parsing

Hadalis does not currently depend on Node.js as a core shell runtime dependency.

Although tree-sitter-qmljs has an npm package, that is not sufficient reason to make the workflow editor depend on a Node process.

Candidate parser-helper implementations should be evaluated in this order:

1. a small native/Rust helper using the tree-sitter-qmljs crate;
2. a Python helper only if a maintainable QML grammar binding can be packaged cleanly through the existing Hadalis Python environment;
3. another standalone implementation if it materially reduces deployment risk.

The transport contract is more important than the helper language.

#### The parser helper should be persistent and request/response driven

Quickshell Process supports long-running processes and streaming stdout parsers. If the source analyzer lives outside QML, prefer one persistent helper while Code Workflow is active instead of spawning a process for every graph operation.

Conceptual JSON-lines protocol:

~~~text
request:
  parse sourcePath revision
  analyze sourcePath revision
  previewTransform command baseRevision
  validatePatch patch
  applyTransform command baseRevision

response:
  requestId
  ok
  revision
  diagnostics
  semanticGraph or patch
~~~

The QML service owns process lifecycle, restart/backoff and request IDs.

The helper does not get arbitrary filesystem write authority by default. Source writes remain under one explicit transaction owner.

### qmlformat, qmllint and qmlls have separate roles

The repository already treats qmlformat 6.8 or newer as a syntax parser/validation gate when available.

Keep that role.

If qmllint is available and can resolve the relevant imports/types, it may add semantic diagnostics before Apply.

qmlls can provide optional definitions/references/usages where reliable.

Neither qmlformat nor qmlls becomes the graph model.

The private Qt QML DOM/parser implementation must not become a hard runtime ABI dependency. The workflow editor should rely on public command-line/tooling contracts or its own packaged CST backend.

### Wire rendering: use retained Qt Quick shapes before considering custom scene-graph code

Qt Quick Shape is a better first implementation than Canvas for a dynamic workflow graph.

Qt documents that Shape renders vector paths through the scene graph rather than software-rasterizing them into an image texture. It also warns that geometry-based Shape rendering retriangulates changed paths, and recommends avoiding many separate Shape items.

Initial renderer contract:

~~~text
WorkflowEdgeLayer
  one/few Shape items
    many ShapePath paths
      cubic or quadratic routed wires
~~~

Prefer batching many wires into a small number of Shape items grouped by visual semantics/state.

Request Shape.CurveRenderer only when the installed Qt supports it and benchmark the actual renderer selected at runtime. The curve renderer avoids retessellation cost when zooming, but the editor must still work with the normal geometry renderer.

Shape asynchronous preprocessing can be tested for large graph refreshes, but asynchronous rendering must not create stale hit targets or selection feedback.

#### Canvas is not the default edge renderer

Canvas remains useful for experiments and tiny overlays, but a large, frequently changing graph should not depend on repainting a raster-backed Canvas for all edges.

Do not choose Canvas merely because drawing cubic lines is easy.

#### Edge hit-testing is separate from edge painting

Open stroked wires are not naturally represented by Shape fill containment.

Use an editor-side hit-test structure:

1. coarse edge bounding box / spatial bucket;
2. distance-to-segment or distance-to-Bezier approximation;
3. closest compatible edge wins within a small screen-space tolerance.

Hit tolerance should remain approximately constant in screen space as the canvas zoom changes.

Do not create a large invisible painted stroke for every edge solely for mouse picking if it harms scene-graph cost.

### Graph input should use Pointer Handlers, not a nest of competing MouseAreas

Qt Pointer Handlers are designed to arbitrate pointer grabs between gestures and can operate with target set to null.

Recommended interaction architecture:

~~~text
canvas viewport
  DragHandler       -> pan
  WheelHandler      -> pointer-centered zoom
  PinchHandler      -> touch/touchpad zoom + pan

node
  TapHandler        -> selection/open
  DragHandler       -> move node metadata only

port
  TapHandler        -> select/connect by keyboard/pointer
  DragHandler       -> create/reconnect wire

empty canvas
  TapHandler        -> clear selection / contextual Quick Add
~~~

Use grabPermissions deliberately where node-drag, wire-drag and canvas-pan overlap.

TapHandler's default DragThreshold policy is useful because it can observe taps passively without immediately stealing the pointer from drag gestures.

Avoid duplicating one gesture through both MouseArea and PointerHandler unless a measured compatibility problem requires it.

### View transform is editor state, not Item geometry mutation

Maintain one logical graph coordinate system:

~~~text
graph-space node positions
        |
canvas transform
        |
screen-space rendering
~~~

Pan/zoom transforms the graph view. It must not rewrite every node's semantic position, source range or source representation.

Node drag changes only graph-layout metadata.

A pointer-centered zoom function must preserve the graph point under the cursor while the scale changes.

### ScriptModel is useful for stable delegate churn

Quickshell ScriptModel can generate incremental model operations from changing JavaScript lists so Repeater/ListView consumers do not recreate all delegates on every list update.

Use it where node/target lists are naturally represented as unique-value lists and where its uniqueness requirement can be guaranteed by stable IDs.

Do not force ScriptModel onto the edge renderer if a more compact custom model/path batch is cheaper.

### Niri integration is already largely solved by NiriService

Current Hadalis NiriService already:

- connects to NIRI_SOCKET through DankSocket;
- starts Niri EventStream;
- parses JSON incrementally;
- owns outputs/workspaces/windows/focus state;
- exposes compositor actions separately.

Code Workflow should consume that service rather than introduce another Niri event socket.

Only add data to NiriService if it is generally compositor state that belongs there. Code Workflow-specific semantic target state remains in CodeWorkflowRuntime/Registry.

### Picking must preserve visible surfaces without loading hidden ones

A new repo-specific interaction hazard was found.

The ii Bar can auto-hide based on hover state. When a full-output picker overlay starts intercepting the pointer, the underlying Bar no longer receives hover and can retract while the user is trying to select it.

The picker therefore needs a narrowly scoped presentation hold.

Rules:

- Pick mode may keep an already-resident inspectable surface visible while selection is in progress.
- Pick mode must not instantiate a dormant LazyLoader or open a closed Dashboard/Sidebar merely so it becomes pickable.
- Bar/Dock/other auto-hide surfaces may include a Code Workflow pick-hold condition analogous to the existing ShellEditSession hold behavior.
- The hold ends immediately when selection/cancel finishes.
- Closed/unloaded targets remain available from the static Targets tree.
- Ephemeral popups are excluded from the first picker milestone unless their lifecycle can be frozen without changing product behavior.

This creates a clean distinction:

~~~text
presentation hold
  keep an already-existing surface from retracting

load/open
  create or reveal a feature that was not present
~~~

Pick mode may do the first, not the second.

### Settings surface handoff must avoid self-selection

When the in-shell Settings overlay/focus surface launches Pick mode:

1. save Code Workflow navigation, selected target and viewport;
2. enter PREPARING;
3. hide/suspend Settings input/visual surface;
4. activate picker overlays;
5. select/cancel;
6. destroy picker input surfaces;
7. restore Settings directly to Code Workflow;
8. restore workflow viewport;
9. apply the newly selected target only after restoration is ready.

The Settings surface itself and picker windows remain non-inspectable by default.

Standalone Settings triggers the main-shell picker through the runtime bridge and does not attempt to create a picker in its own process.

### Accessibility and keyboard interaction are part of the editor contract

A visual workflow editor cannot be pointer-only.

Qt Quick exposes Accessible metadata/actions and KeyNavigation/focus-scope primitives. Code Workflow nodes, ports and toolbar actions must expose meaningful accessibility names/descriptions/roles.

Minimum keyboard model:

- Tab/Shift+Tab moves between major editor regions and actionable controls.
- Arrow keys navigate spatially between nodes or ports in the active graph scope.
- Enter opens/edits the selected node or drills into a component subflow.
- Escape exits contextual mode/subflow operation before leaving the page.
- Delete removes a selected editable semantic node/connection only after the normal safety rules.
- Ctrl+Z / Ctrl+Shift+Z perform semantic undo/redo.
- Ctrl+0 fits/resets the graph view; plus/minus zoom.
- A keyboard command opens contextual Quick Add.
- A keyboard command can move focus to Targets and Inspector without requiring pointer use.

Graph focus should use a FocusScope so internal node focus does not unpredictably steal focus from Settings chrome.

Accessibility text must describe semantics, for example:

~~~text
Media.player
Input property
Bound to MprisController.activePlayer
Runtime value: mpd
~~~

Do not encode critical meaning through wire color alone; edge kind also needs shape/icon/label/accessible description.

### Graph size and performance are benchmark gates, not guessed constants

Do not bake an arbitrary maximum node count into product semantics before measurement.

Phase 0 must benchmark at least:

- small graph;
- representative Bar/Media subflow;
- intentionally dense stress graph;
- node drag while connected wires update;
- continuous pan;
- continuous wheel/pinch zoom;
- multi-select;
- runtime value updates;
- event trace bursts.

Measurements should capture:

- UI-frame smoothness;
- main-thread stalls;
- delegate/object count;
- edge-update cost;
- memory growth;
- behavior under fractional scaling.

The product can later impose a visible-node budget based on measured limits, using subflow collapse and dependency-hop expansion rather than silently dropping semantic nodes.

### Phase 0 prototype order

Implement feasibility in this order so each spike answers one independent risk.

#### Spike A: parser corpus

No UI.

Output:

- corpus parse report;
- ambiguity/unsupported report;
- semantic-extraction proof for bindings, handlers, Connections, Loaders and component boundaries;
- no-op source preservation proof.

#### Spike B: graph renderer/input sandbox

No live shell integration.

Output:

- pan/zoom canvas;
- 20-100 representative nodes and routed wires;
- node drag;
- wire hit-test;
- selection/lasso;
- subflow navigation;
- keyboard focus proof;
- performance notes for Shape renderer variants.

#### Spike C: semantic runtime registry on ii Bar

Read-only.

Output:

- register Bar semantic modules;
- stable target/instance IDs;
- safe runtime-property snapshots;
- unloaded/resident states;
- no LazyLoader forced active.

#### Spike D: picker lifecycle

Read-only.

Output:

- per-output Overlay picker;
- QML-owned geometry tracking;
- presentation hold for existing auto-hide Bar;
- no click leakage;
- Settings hide/restore;
- output removal handling;
- cancel/lock-screen handling;
- no Exclusive keyboard focus.

#### Spike E: reload/rebind

Read-only source mutation can be simulated externally for this spike.

Output:

- selected semantic target survives ordinary Quickshell reload;
- runtimeRef is replaced safely;
- target becoming unloaded becomes static mode;
- stale target produces an explicit state rather than null-reference errors.

Only after A-E succeed should the first source-writing transform be implemented.

### Definition of research-ready

Architecture research is considered complete enough for implementation when the following are true:

- product model is fixed as workflow-first/projectional;
- QML semantic edge types are defined;
- source-of-truth/round-trip rules are defined;
- parser candidates and rejection criteria are defined;
- renderer/input strategy is defined;
- picker lifecycle and Niri/Quickshell ownership are defined;
- lazy/resident behavior is defined;
- Settings overlay/standalone boundary is defined;
- security/sensitive-data policy is defined;
- accessibility/keyboard baseline is defined;
- validation and Phase 0 proof sequence are defined.

At that point, unresolved questions must be answered by code/profiling/live-runtime spikes rather than additional document-only research.


## Roadmap

### Phase 0 - feasibility spikes

No product UI commitments yet.

- evaluate a source parser against a representative Hadalis QML corpus;
- verify lossless source ranges/minimal patches;
- test semantic target geometry across Bar/popup/sidebar layer-shell windows;
- test per-output picker overlay;
- benchmark simple node/edge rendering;
- confirm reload/rebind behavior using stable target IDs.

Exit criterion: no fundamental parser, picker, or reload blocker.

### Phase 1 - read-only live workflow

Scope: ii Bar first.

- Reference -> Code Workflow page;
- semantic registry;
- Pick component;
- graph canvas;
- component/service/binding/event/lifecycle nodes;
- safe runtime property values;
- subflow drill-down;
- Source Preview;
- no source writes.

Exit criterion: graph is useful for troubleshooting without reading the source file first.

### Phase 2 - safe visual editing subset

Support only transforms that can be generated and reversed reliably:

- literal property value;
- direct property binding;
- connect/disconnect a simple data dependency;
- connect signal to an existing action;
- add/remove a simple Connections handler;
- explicit Apply;
- patch preview;
- undo/redo;
- source conflict protection.

Exit criterion: workflow edits round-trip without formatting unrelated code.

### Phase 3 - component and lifecycle authoring

- add/remove component instances in known parents;
- Loader/LazyLoader lifecycle;
- conditions/branches;
- reusable/collapsible subflows;
- more robust diagnostics and generated patch explanation.

### Phase 4 - cross-process and shell-wide coverage

- standalone Settings runtime bridge;
- left/right sidebars;
- Dashboard;
- Dock;
- Waffle;
- lazy/on-demand targets;
- multi-output runtime instances;
- richer runtime event tracing.

Waffle remains a supported independent panel family. Coverage must be implemented deliberately rather than assuming ii component structure applies to it.

### Phase 5 - advanced transformations

Only after the workflow model is proven:

- safer Script/Expression editing;
- reusable user-defined workflow transformations;
- dependency search;
- impact preview;
- graph diff between revisions.

This phase must still preserve the product invariant: workflow remains the editor.

## Validation strategy

### Static/contracts

Add focused tests for:

- new page is appended and historical page indices do not shift;
- Reference orders Code Workflow before Shortcuts;
- Easy Mode hides the non-essential workflow page;
- no dependency on retired modules/perimeter runtime;
- semantic target IDs are unique;
- sensitive properties are never serialized;
- parser corpus parses representative Hadalis QML;
- parse -> no-op transform -> output is byte-identical;
- minimal graph transform changes only expected ranges;
- external source conflict is detected;
- stable IDs survive unrelated source movement where promised;
- graph metadata changes do not modify QML;
- picker excludes its own UI;
- source validation rejects malformed generated patches;
- existing Waffle and Settings contracts remain intact.

The normal repository gate remains:

~~~bash
bash scripts/validate-maintainer-local.sh
~~~

### Live acceptance

Static tests cannot prove the picker or runtime behavior.

Live checks should cover:

- horizontal and vertical ii Bar;
- multiple semantic modules on the same Bar;
- a connected popup;
- both sidebars;
- lazy/on-demand component unload/reload;
- multiple monitors;
- fractional scaling;
- Settings overlay hide/pick/restore;
- picker click does not trigger the underlying control;
- Escape cancels;
- shell lock cancels;
- successful source apply + Quickshell reload + target rebind;
- failed reload diagnostics;
- concurrent external source edit conflict;
- package-managed read-only mode;
- Waffle once its phase is implemented.

## Explicit non-goals / no-go list

Do not let implementation drift toward any of the following:

1. A conventional VS Code/Zed/Vim-like text editor as the main surface.
2. A file tree plus giant TextArea with a decorative graph view.
3. Monaco/WebEngine as the editor core.
4. A terminal embedded under the graph.
5. Graph nodes that simply mirror every QQuickItem/QObject child.
6. activeFocusItem as the generic component selection mechanism.
7. Regex as the canonical QML parser/rewriter.
8. Reformatting an entire file for small graph changes.
9. Autosaving QML because a node was dragged on the canvas.
10. Source semantics encoded in node x/y positions.
11. Raw QObject dumps over IPC.
12. Sensitive values exposed through runtime inspection.
13. Cross-process raw object-pointer assumptions.
14. Reintroduction of the retired iiPerimeter/module registry architecture.
15. Treating Waffle as legacy or assuming ii graph adapters work unchanged.
16. Silent privilege escalation for package-managed source.
17. Pretending unsupported JavaScript/QML constructs are visually editable when round-trip safety is unknown.

## Research references

The workflow conventions in this design were cross-checked against the following primary references:

- Node-RED editor workspace: https://nodered.org/docs/user-guide/editor/workspace/
- Node-RED nodes and ports: https://nodered.org/docs/user-guide/editor/workspace/nodes
- Node-RED subflows: https://nodered.org/docs/user-guide/editor/workspace/subflows
- Node-RED flow documentation/layout guidance: https://nodered.org/docs/developing-flows/documenting-flows
- Unreal Engine Blueprint node/pin/wire model: https://dev.epicgames.com/documentation/unreal-engine/nodes?application_version=4.27
- Qt QML property bindings: https://doc.qt.io/qt-6.8/qtqml-syntax-propertybinding.html
- Qt QML document structure: https://doc.qt.io/qt-6.8/qtqml-documents-structure.html
- Qt meta-object system: https://doc.qt.io/qt-6.8/metaobjects.html
- QObject runtime/introspection APIs: https://doc.qt.io/qt-6.8/qobject.html
- QQuickItem coordinate/item APIs: https://doc.qt.io/qt-6.8/qquickitem.html
- QQuickWindow focus semantics: https://doc.qt.io/qt-6.8/qquickwindow.html
- Quickshell runtime/reload API: https://quickshell.outfoxxed.me/docs/types/Quickshell/Quickshell/
- tree-sitter-qmljs candidate grammar: https://www.npmjs.com/package/tree-sitter-qmljs and https://docs.rs/tree-sitter-qmljs/latest/tree_sitter_qmljs/

These references inform interaction patterns and technical feasibility. They are not dependencies and do not override Hadalis repository contracts.

## Decision summary

The implementation should proceed only if it preserves all of these invariants:

- **Workflow canvas is the primary code-authoring surface.**
- **Raw source is secondary preview/patch/escape-hatch material.**
- **Semantic component registration beats raw QObject-tree dumping.**
- **Static source analysis and runtime inspection are separate inputs to one graph model.**
- **Graph edits become minimal, reviewable, conflict-checked source patches.**
- **Source writes are explicit and transactional.**
- **Runtime selection survives Quickshell reload through stable IDs.**
- **Settings overlay and standalone Settings are treated as different runtime contexts.**
- **Sensitive data and security surfaces are excluded by design.**
- **No retired perimeter composition architecture is reintroduced.**
- **Waffle remains a first-class separate family.**

If a future implementation choice makes the text buffer the authoritative editor and reduces the graph to a visualization, it violates this design even if the feature is still named Code Workflow.
