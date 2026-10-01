#!/usr/bin/env python3
"""Unit-check the repeated fake session wrapper without Qt or vendor access."""
from pathlib import Path
import os
import subprocess
import tempfile

repo = Path(__file__).resolve().parents[1]
source = (repo / "scripts/test-megaqml-race-repeat.sh").read_text(encoding="utf-8")
original = "bash scripts/test-megaqml-quickshell-smoke.sh ui-race"
assert source.count(original) == 1
assert "repetitions=8" in source
assert 'output="$(' in source and "race_repeat_first_failure" in source

with tempfile.TemporaryDirectory(prefix="megaqml-race-loop-") as scratch:
    temp = Path(scratch)
    counter = temp / "counter"
    fake = temp / "fake.sh"
    fake.write_text(
        "#!/usr/bin/env bash\nset -euo pipefail\n"
        'n="$(cat "$MEGAQML_TEST_COUNTER" 2>/dev/null || printf 0)"\n'
        'n="$((n+1))"\nprintf "%s\\n" "$n" > "$MEGAQML_TEST_COUNTER"\n'
        'if [[ "$MEGAQML_TEST_MODE" == fail && "$n" == 3 ]]; then\n'
        '  echo "quickshell_smoke_category=ui-race:race_stale_installed"\n'
        '  echo "PRIVATE_PATH_AND_PASSWORD_CANARY"\n'
        '  exit 88\n'
        'fi\n'
        'if [[ "$MEGAQML_TEST_MODE" == unknown && "$n" == 1 ]]; then\n'
        '  echo "quickshell_smoke_category=ui-race:private_path"\n'
        '  echo "PRIVATE_PATH_AND_PASSWORD_CANARY"\n'
        '  exit 88\n'
        'fi\n'
        'echo "PASS isolated Quickshell ui-race smoke"\n',
        encoding="utf-8")
    wrapper = temp / "wrapper.sh"
    wrapper.write_text(
        source.replace(original, 'bash "' + str(fake) + '" ui-race'),
        encoding="utf-8")
    for mode, status, expected in (
        ("pass", 0, ("race_repeat_passes=8",)),
        ("fail", 88, ("race_repeat_passes=2", "race_repeat_first_failure=3",
                      "race_repeat_failure_category=race_stale_installed")),
        ("unknown", 88, ("race_repeat_passes=0", "race_repeat_first_failure=1",
                         "race_repeat_failure_category=unclassified_failure")),
    ):
        counter.unlink(missing_ok=True)
        env = dict(os.environ, MEGAQML_TEST_COUNTER=str(counter),
                   MEGAQML_TEST_MODE=mode)
        child = subprocess.run(["bash", str(wrapper)], cwd=repo, env=env,
                               capture_output=True, text=True, timeout=8)
        assert child.returncode == status, (mode, child.returncode)
        assert "race_repeat_attempts=8" in child.stdout
        assert all(x in child.stdout for x in expected)
        assert child.stderr == ""
        assert "PRIVATE_PATH_AND_PASSWORD_CANARY" not in child.stdout
        assert int(counter.read_text()) == (8 if mode == "pass" else
                                            3 if mode == "fail" else 1)
print("PASS MegaQML race repetition shell with private diagnostics withheld")
