#!/usr/bin/env python3
"""Stage a committed Hadalis tree and instrument only its temporary copy.

Never point this at the installed shell. The explicit destination must not exist.
No production source file in the checkout is modified by this harness.
"""
import argparse
import hashlib
import io
import json
from pathlib import Path
import shutil
import subprocess
import tarfile

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[1]


def replace_once(text, old, new):
    if text.count(old) != 1:
        raise ValueError(f"instrumentation anchor is not unique: {old!r}")
    return text.replace(old, new, 1)


def prepare(destination, revision):
    revision = subprocess.check_output(['git', 'rev-parse', revision + '^{commit}'], cwd=REPO, text=True).strip()
    destination.mkdir(parents=True, exist_ok=False)
    tree = destination / 'config'
    tree.mkdir()
    archive = subprocess.check_output(['git', 'archive', revision], cwd=REPO)
    with tarfile.open(fileobj=io.BytesIO(archive)) as tar:
        tar.extractall(tree, filter='data')
    probe = tree / 'workflowprobe'
    probe.mkdir()
    for path in sorted((HERE / 'runtime').glob('*.qml')):
        shutil.copyfile(path, probe / path.name)
    (probe / 'qmldir').write_text('module qs.workflowprobe\nsingleton RuntimeRegistry 1.0 RuntimeRegistry.qml\nRuntimeTarget 1.0 RuntimeTarget.qml\nPickerProbe 1.0 PickerProbe.qml\n')
    modifications = []
    modules = [('BarContent', 'bar'), ('Media', 'bar/media'), ('ClockWidget', 'bar/clock'), ('Resources', 'bar/resources')]
    for name, target in modules:
        path = tree / f'modules/bar/{name}.qml'
        original = path.read_text()
        injected = f'    id: root\n    RuntimeTarget {{ runtimeObject: root; targetId: "{target}" }}\n'
        if name == 'Media':
            injected += '    property string probeSensitiveSentinel: "DO_NOT_EXPORT_PRIVATE_VALUE"\n'
            injected += '    readonly property string probeBirthId: Date.now().toString() + "-" + Math.random().toString(36).slice(2)\n'
            if 'Component.onDestruction:' in original:
                raise ValueError('Media now has a destruction handler; review instrumentation')
            injected += '    Component.onDestruction: console.info("WORKFLOW_MEDIA_DESTROYED", probeBirthId, String(root))\n'
        text = replace_once(original, '    id: root\n', injected)
        if name == 'Media':
            text = replace_once(text, '    function toggleExpanded(): void {\n',
                                '    function toggleExpanded(): void {\n        RuntimeRegistry.mediaActions++\n')
        path.write_text('import qs.workflowprobe\n' + text)
        modifications.append(str(path.relative_to(tree)))
    path = tree / 'modules/bar/Bar.qml'
    text = path.read_text()
    text = replace_once(text, '                    || ShellEditSession.active\n',
        '                    || ShellEditSession.active\n                    || (RuntimeRegistry.pickHold && RuntimeRegistry.heldOutputs.includes(outputName))\n')
    # Imports must follow pragma declarations.
    text = replace_once(text, 'import QtQuick\n', 'import QtQuick\nimport qs.workflowprobe\n')
    path.write_text(text)
    modifications.append(str(path.relative_to(tree)))
    shell_template = (HERE / 'runtime/ProbeShell.qml').read_text()
    shell_text = replace_once(
        shell_template,
        '// WORKFLOW_PROBE_IMPORT: prepare-runtime.py replaces this marker only in the\n'
        '// isolated exported runtime after creating config/workflowprobe/qmldir.\n',
        'import qs.workflowprobe\n'
    )
    (tree / 'shell.qml').write_text(shell_text)
    modifications.append('shell.qml')
    for name in ('xdg-config', 'xdg-state', 'xdg-cache', 'xdg-data'):
        (destination / name).mkdir()
    config = destination / 'xdg-config/illogical-impulse'
    config.mkdir()
    (config / 'config.json').write_text(json.dumps({
        'panelFamily':'ii', 'appearance':{'globalStyle':'material','animations':False},
        'bar':{'autoHide':{'enable':True, 'pushWindows':False},
               'modules':{'media':True,'clock':True,'resources':False},
               'layout':{'migrated':True,'left':[], 'centerLeft':['media'],
                         'center':['clock'],'centerRight':[],'right':[]}},
        'media':{'popupMode':'bar'},'bootGreeting':{'enable':False},
        'settingsUi':{'overlayMode':True}
    }))
    manifest = {'source_revision':revision,'instrumented_files':modifications,
                'probe_sha256':{p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted((HERE/'runtime').glob('*.qml'))},
                'driver_sha256':{p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in (HERE/'prepare-runtime.py',HERE/'run-runtime.py',HERE/'virtual-pointer.c')},
                'policy':'Temporary copy only; actual Bar/Media/Clock implementations; no production registration.'}
    (destination / 'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
    return manifest


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('destination', type=Path)
    parser.add_argument('--revision', default='HEAD')
    args = parser.parse_args()
    print(json.dumps(prepare(args.destination.resolve(), args.revision), indent=2))
