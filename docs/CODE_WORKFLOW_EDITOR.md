# Workflow-first QML Code Editor

Status: research and architecture note; not implemented yet.

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
