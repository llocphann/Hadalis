"""Private, dark Niri window for Qt tests that require a layer-shell backend."""
from contextlib import contextmanager
from pathlib import Path
import os, re, shutil, signal, subprocess, time


def run_qs(folder: Path, env: dict, timeout: int = 25):
    """Bound and clean up the test's whole process group, retaining diagnostics."""
    command = ["dbus-run-session", "--", "qs", "-p", str(folder), "--no-color"]
    log = folder / "native-test-qs.log"
    with log.open("wb") as stream:
        process = subprocess.Popen(command, env=dict(env,QT_NO_XDG_DESKTOP_PORTAL="1"), stdout=stream,
                                   stderr=subprocess.STDOUT, start_new_session=True)
    try:
        code = process.wait(timeout=timeout)
    except subprocess.TimeoutExpired:
        if process.poll() is None:
            os.killpg(process.pid, signal.SIGTERM)
            try: process.wait(timeout=3)
            except subprocess.TimeoutExpired:
                os.killpg(process.pid, signal.SIGKILL); process.wait(timeout=3)
        code = 124
    return subprocess.CompletedProcess(command, code, log.read_text(errors="replace"), "")


@contextmanager
def private_wayland(folder: Path):
    niri = shutil.which("niri")
    host_display = os.environ.get("WAYLAND_DISPLAY", "")
    if not niri or not host_display:
        yield None
        return
    config = folder / "native-test.kdl"
    config.write_text('layout {\n background-color "#111820"\n}\n'
                      'overview {\n backdrop-color "#111820"\n}\n')
    env = dict(os.environ, NIRI_CONFIG=str(config), RUST_LOG="niri=info")
    env.pop("NIRI_SOCKET", None)
    for kind in ["config", "state", "cache", "data"]:
        env[f"XDG_{kind.upper()}_HOME"] = str(folder / kind)
        (folder / kind).mkdir(exist_ok=True)
    log = folder / "native-test-niri.log"
    process = None
    try:
        with log.open("wb") as stream:
            process = subprocess.Popen([niri], env=env, stdout=stream,
                                       stderr=subprocess.STDOUT, start_new_session=True)
        deadline = time.monotonic() + 12
        while time.monotonic() < deadline:
            if process.poll() is not None:
                raise RuntimeError("Private Niri exited: " + log.read_text()[-2000:])
            text = log.read_text(errors="replace")
            displays = re.findall(r"listening on Wayland socket:\s*(wayland-[0-9]+)", text)
            sockets = re.findall(r"IPC listening on:\s*(/\S+?\.sock)(?:\s|$)", text)
            if displays and sockets and displays[-1] != host_display:
                socket = Path(sockets[-1])
                if socket.is_socket() and str(socket) != os.environ.get("NIRI_SOCKET"):
                    env.update(WAYLAND_DISPLAY=displays[-1], NIRI_SOCKET=str(socket),
                               QT_QPA_PLATFORM="wayland")
                    for key in ["QS_CONFIG_NAME", "QS_CONFIG_PATH", "QS_MANIFEST"]:
                        env.pop(key, None)
                    yield env
                    return
            time.sleep(.1)
        raise RuntimeError("Private Niri did not publish a distinct socket: "
                           + log.read_text(errors="replace")[-2400:])
    finally:
        if process is not None and process.poll() is None:
            try:
                os.killpg(process.pid, signal.SIGTERM)
                process.wait(timeout=4)
            except subprocess.TimeoutExpired:
                os.killpg(process.pid, signal.SIGKILL)
                process.wait(timeout=3)
            except ProcessLookupError:
                pass
