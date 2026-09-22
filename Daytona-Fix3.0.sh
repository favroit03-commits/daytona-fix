cd /daytona-fix

python3 - <<'PY'
from pathlib import Path
import shutil
import subprocess

path = Path("Daytona-Fix3.0.sh")
original = path.read_text()

start = '[[ -r /dev/tty ]] || die "Run from an interactive terminal."'
end = 'unset USER_ENC PASS_ENC'

if original.count(start) != 1 or original.count(end) != 1:
    raise SystemExit("Expected block nahi mila; file unchanged.")

begin = original.index(start)
finish = original.index(end, begin) + len(end)

replacement = r'''# Non-interactive: credentials are optional, but must be supplied together.
GOST_USER="${GOST_USER:-}"
GOST_PASS="${GOST_PASS:-}"

if [[ -n "$GOST_USER" && -z "$GOST_PASS" ]] ||
   [[ -z "$GOST_USER" && -n "$GOST_PASS" ]]; then
    die "Set both GOST_USER and GOST_PASS, or leave both empty."
fi

encode_component() {
    python3 -c \
        'import sys; from urllib.parse import quote; print(quote(sys.stdin.read(), safe=""))'
}

FORWARD="mwss://${HOST}:443?secure=true&path=/ws"

if [[ -n "$GOST_USER" ]]; then
    USER_ENC="$(printf '%s' "$GOST_USER" | encode_component)"
    PASS_ENC="$(printf '%s' "$GOST_PASS" | encode_component)"
    FORWARD="mwss://${USER_ENC}:${PASS_ENC}@${HOST}:443?secure=true&path=/ws"
fi

unset GOST_USER GOST_PASS USER_ENC PASS_ENC'''

updated = original[:begin] + replacement + original[finish:]

# Check Bash syntax before changing the original file.
subprocess.run(["bash", "-n"], input=updated, text=True, check=True)

backup = path.with_name(path.name + ".before-no-prompt.bak")
if backup.exists():
    raise SystemExit(f"Backup already exists: {backup}; file unchanged.")

shutil.copy2(path, backup)
path.write_text(updated)
print(f"Prompt removed. Backup: {backup}")
PY
