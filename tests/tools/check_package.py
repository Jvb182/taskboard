"""Verify release ZIP contents and run the Lua suite against the packaged addon."""
from pathlib import Path
import re
import subprocess
import sys
import tempfile
import zipfile

ROOT = Path(__file__).resolve().parents[2]


def check_zip(path, expected):
    with zipfile.ZipFile(path) as archive:
        actual = set(archive.namelist())
        assert actual == expected, f"{path.name}: unexpected paths: {actual ^ expected}"
        assert archive.testzip() is None, f"{path.name}: CRC failure"
        for name in expected:
            source = ROOT / name
            if name.startswith("Taskboard/"):
                source = ROOT / name.removeprefix("Taskboard/")
            elif name == "Questboard/Questboard.toc":
                source = ROOT / "compat/Questboard/Questboard.toc"
            assert archive.read(name) == source.read_bytes(), f"{path.name}: stale {name}"


def main():
    toc = (ROOT / "Taskboard.toc").read_text(encoding="utf-8")
    version = re.search(r"^## Version: ([\w.-]+)$", toc, re.MULTILINE).group(1)
    runtime = {"Taskboard/Taskboard.toc", "Taskboard/Bindings.xml",
               "Taskboard/README.md", "Taskboard/docs/TESTING.md"}
    runtime.update("Taskboard/" + line.strip().replace("\\", "/") for line in toc.splitlines()
                   if line.strip() and not line.startswith("#"))
    loader = {"Questboard/Questboard.toc"}
    dist = ROOT / "dist"
    cf = dist / f"Taskboard-{version}-CurseForge.zip"
    check_zip(cf, runtime)
    check_zip(dist / f"Taskboard-{version}.zip", runtime | loader)
    check_zip(dist / f"Taskboard-{version}-Legacy-Loader.zip", loader)

    with tempfile.TemporaryDirectory(prefix="taskboard-package-") as tmp:
        with zipfile.ZipFile(cf) as archive:
            archive.extractall(tmp)
        subprocess.run([sys.executable, str(ROOT / "tests/run.py"),
                        "--addon-root", str(Path(tmp) / "Taskboard")],
                       cwd=ROOT, check=True)
    print("Package contents and packaged-addon tests passed")


if __name__ == "__main__":
    main()
