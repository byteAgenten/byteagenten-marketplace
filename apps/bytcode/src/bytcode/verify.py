"""Done-criteria verification for workflow phases."""

import subprocess
from pathlib import Path

from .config import Criterion, Phase


def _check_glob(pattern: str, project_dir: Path) -> tuple[bool, str]:
    """Check if at least one file matches the glob pattern."""
    matches = list(project_dir.glob(pattern))
    if matches:
        names = ", ".join(m.name for m in matches[:3])
        return True, f"glob ok: {names}"
    return False, f"no match: {pattern}"


def _check_jq(expression: str, file: str, project_dir: Path) -> tuple[bool, str]:
    """Check a jq expression against a JSON file."""
    filepath = project_dir / file
    if not filepath.exists():
        return False, f"file not found: {file}"
    try:
        result = subprocess.run(
            ["jq", "-e", expression, str(filepath)],
            capture_output=True,
            text=True,
            timeout=5,
        )
        if result.returncode == 0:
            return True, f"jq ok: {expression}"
        return False, f"jq failed: {expression}"
    except subprocess.TimeoutExpired:
        return False, f"jq timeout: {expression}"
    except FileNotFoundError:
        return False, "jq not installed"


def verify_phase(phase: Phase, project_dir: Path) -> tuple[bool, str]:
    """Verify all done-criteria for a phase. All must pass (compound AND)."""
    if not phase.criteria:
        return True, "no criteria"

    messages: list[str] = []
    for criterion in phase.criteria:
        if criterion.type == "glob":
            ok, msg = _check_glob(criterion.pattern, project_dir)
        elif criterion.type == "jq":
            ok, msg = _check_jq(criterion.pattern, criterion.file, project_dir)
        else:
            ok, msg = False, f"unknown criterion type: {criterion.type}"

        messages.append(msg)
        if not ok:
            return False, "; ".join(messages)

    return True, "; ".join(messages)
