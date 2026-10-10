#!/usr/bin/env python3
"""Verify that check/dry-run installer modes never execute installation commands."""
import os
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
DISTROS = ["arch", "debian", "ubuntu", "fedora", "gentoo", "void", "freebsd", "nix", "nixos"]

with tempfile.TemporaryDirectory(prefix="prismarine-installer-check-") as directory:
    fixture = Path(directory)
    binary = fixture / "bin"
    binary.mkdir()
    log = fixture / "mutations"
    environment = dict(os.environ, HOME=str(fixture), PATH=f"{binary}:/usr/bin:/bin", INSTALLER_TEST_LOG=str(log))
    # Package queries report everything missing. A fake native launcher keeps
    # detection deterministic and is never actually started.
    for name in ["pacman", "apt-get", "dpkg-query", "dnf", "rpm", "emerge", "portageq", "xbps-install", "xbps-query", "pkg"]:
        program = binary / name
        program.write_text("#!/bin/sh\nexit 1\n")
        program.chmod(0o755)
    for name in ["sudo", "cmake", "nix", "prismlauncher"]:
        program = binary / name
        program.write_text('#!/bin/sh\nprintf "%s\\n" "$0 $*" >> "$INSTALLER_TEST_LOG"\nexit 99\n')
        program.chmod(0o755)
    for distro in DISTROS:
        installer = ROOT / "install" / f"{distro}.sh"
        result = subprocess.run(["bash", str(installer), "--dry-run"], env=environment, text=True, capture_output=True)
        assert result.returncode == 0, (distro, result.stdout, result.stderr)
        assert "Would run:" in result.stdout, (distro, result.stdout)
        assert not log.exists(), f"{distro}: dry-run executed a mutating command"
        result = subprocess.run(["bash", str(installer), "--check"], env=environment, text=True, capture_output=True)
        assert result.returncode == (0 if distro in ["nix", "nixos"] else 1), (distro, result.stdout, result.stderr)
        assert not log.exists(), f"{distro}: dependency check executed a mutating command"
    print(f"All {len(DISTROS)} installers passed dry-run and dependency-check verification.")
