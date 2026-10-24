#!/usr/bin/env python3
"""Environment check for the shared-agent-skills dispatcher.

Read-only probe: reports which script runtime and which agent skill directories are
available on this machine. It never installs, downloads, logs in, or changes any
configuration, and it never prints credential values.

Exit codes:
    0  ready       - a usable runtime was found
    1  partial     - a runtime exists but some agent directories are unreachable
    2  needs_setup- no usable runtime was found
    3  unavailable - the check itself could not run
"""

from __future__ import annotations

import json
import os
import platform
import shutil
import subprocess
import sys
from pathlib import Path

SKILL_ROOT = Path(__file__).resolve().parent.parent

AGENT_DIRS: list[tuple[str, str]] = [
    ("workbuddy", ".workbuddy/skills"),
    ("opencode", ".config/opencode/skills"),
    ("claude", ".claude/skills"),
    ("codex", ".codex/skills"),
    ("cursor", ".cursor/skills"),
    ("gemini", ".gemini/skills"),
    ("windsurf", ".codeium/windsurf/skills"),
    ("windsurf-alt", ".windsurf/skills"),
    ("copilot", ".agents/skills"),
]


def home_dir() -> Path:
    return Path(os.path.expanduser("~"))


def probe_powershell() -> dict:
    """Look for a Windows PowerShell interpreter and report its version."""
    result = {
        "id": "windows-powershell",
        "available": False,
        "version": None,
        "detail": "",
    }
    for candidate in ("powershell", "pwsh"):
        path = shutil.which(candidate)
        if not path:
            continue
        try:
            completed = subprocess.run(
                [path, "-NoProfile", "-Command", "$PSVersionTable.PSVersion.ToString()"],
                capture_output=True,
                text=True,
                timeout=20,
                check=False,
            )
        except (OSError, subprocess.SubprocessError) as exc:
            result["detail"] = f"{candidate} found but could not be probed: {exc.__class__.__name__}"
            continue
        version = (completed.stdout or "").strip().splitlines()
        if completed.returncode == 0 and version:
            result["available"] = True
            result["version"] = version[0].strip()
            result["detail"] = f"{candidate} is usable"
            return result
        result["detail"] = f"{candidate} found but the version probe failed"
    if not result["detail"]:
        result["detail"] = "no powershell or pwsh command on PATH"
    return result


def probe_bash() -> dict:
    """Look for a bash interpreter and report its version."""
    result = {
        "id": "unix-bash",
        "available": False,
        "version": None,
        "detail": "",
    }
    path = shutil.which("bash")
    if not path:
        result["detail"] = "no bash command on PATH"
        return result
    try:
        completed = subprocess.run(
            [path, "--version"],
            capture_output=True,
            text=True,
            timeout=20,
            check=False,
        )
    except (OSError, subprocess.SubprocessError) as exc:
        result["detail"] = f"bash found but could not be probed: {exc.__class__.__name__}"
        return result
    first = (completed.stdout or "").strip().splitlines()
    if completed.returncode == 0 and first:
        result["available"] = True
        result["version"] = first[0].strip()
        result["detail"] = "bash is usable"
    else:
        result["detail"] = "bash found but the version probe failed"
    return result


def probe_agents(base: Path) -> list[dict]:
    """Report which agent skill directories exist and whether they are readable."""
    found = []
    for agent_id, relative in AGENT_DIRS:
        directory = base / relative
        entry = {
            "id": agent_id,
            "path": str(directory),
            "exists": directory.is_dir(),
            "readable": False,
            "skill_count": 0,
        }
        if entry["exists"]:
            try:
                entries = list(directory.iterdir())
                entry["readable"] = True
                entry["skill_count"] = sum(1 for item in entries if item.is_dir())
            except OSError:
                entry["readable"] = False
        found.append(entry)
    return found


def probe_shared_root(base: Path) -> dict:
    """Report whether the shared root exists and is writable."""
    root = base / ".shared-agent-skills"
    entry = {
        "path": str(root),
        "exists": root.is_dir(),
        "writable": False,
        "skill_count": 0,
    }
    if entry["exists"]:
        try:
            entry["skill_count"] = sum(1 for item in root.iterdir() if item.is_dir())
            probe = root / ".write-probe"
            probe.mkdir(exist_ok=True)
            probe.rmdir()
            entry["writable"] = True
        except OSError:
            entry["writable"] = False
    else:
        parent = root.parent
        entry["writable"] = parent.is_dir()
    return entry


def probe_scripts() -> list[dict]:
    """Report which dispatcher scripts are present in this package."""
    scripts_dir = SKILL_ROOT / "scripts"
    entries = []
    for name in (
        "detect_agents.ps1",
        "detect_agents.sh",
        "share_skill.ps1",
        "share_skill.sh",
        "share_all.ps1",
        "share_all.sh",
        "unshare_skill.ps1",
        "unshare_skill.sh",
    ):
        path = scripts_dir / name
        entries.append({"name": name, "present": path.is_file()})
    return entries


def main() -> int:
    base = home_dir()
    powershell = probe_powershell()
    bash = probe_bash()
    agents = probe_agents(base)
    shared_root = probe_shared_root(base)
    scripts = probe_scripts()

    runtimes = [item for item in (powershell, bash) if item["available"]]
    missing_scripts = [item["name"] for item in scripts if not item["present"]]
    unreachable = [
        item["id"] for item in agents if item["exists"] and not item["readable"]
    ]
    detected = [item["id"] for item in agents if item["exists"]]

    if not runtimes:
        status = "needs_setup"
    elif missing_scripts or unreachable:
        status = "partial"
    else:
        status = "ready"

    payload = {
        "status": status,
        "platform": platform.system(),
        "skill_root": str(SKILL_ROOT),
        "runtimes": [powershell, bash],
        "selected_runtime": runtimes[0]["id"] if runtimes else None,
        "agents_detected": detected,
        "agents_unreachable": unreachable,
        "shared_root": shared_root,
        "scripts_missing": missing_scripts,
        "notes": [
            "Windows uses the .ps1 scripts; macOS and Linux use the .sh scripts.",
            "On Windows the bash variant cannot create junctions, so prefer the .ps1 variant there.",
        ],
    }
    print(json.dumps(payload, ensure_ascii=False, indent=2))

    if status == "ready":
        return 0
    if status == "partial":
        return 1
    if status == "needs_setup":
        return 2
    return 3


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception as exc:  # noqa: BLE001 - the probe must never crash the caller
        print(
            json.dumps(
                {
                    "status": "unavailable",
                    "detail": f"{exc.__class__.__name__}: {exc}",
                    "notes": ["The environment check itself failed; no configuration was changed."],
                },
                ensure_ascii=False,
                indent=2,
            )
        )
        sys.exit(3)
