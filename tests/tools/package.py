"""Build an installable addon ZIP using only files required by the TOC."""
from pathlib import Path
import argparse
import re
import zipfile

ROOT = Path(__file__).resolve().parents[2]
LOADER_FILES = ("Questboard.toc", "Bindings.xml")


def main():
    parser = argparse.ArgumentParser()
    kind = parser.add_mutually_exclusive_group()
    kind.add_argument("--curseforge", action="store_true", help="Build the single-folder CurseForge file")
    kind.add_argument("--legacy-loader", action="store_true", help="Build the optional saved-variable loader")
    args = parser.parse_args()
    toc = (ROOT / "Taskboard.toc").read_text(encoding="utf-8")
    version = re.search(r"^## Version: ([\w.-]+)$", toc, re.MULTILINE).group(1)
    files = ["Taskboard.toc", "Bindings.xml", "README.md", "docs/TESTING.md"]
    files += [line.strip().replace("\\", "/") for line in toc.splitlines()
              if line.strip() and not line.startswith("#")]
    suffix = "-Legacy-Loader" if args.legacy_loader else "-CurseForge" if args.curseforge else ""
    output = ROOT / "dist" / f"Taskboard-{version}{suffix}.zip"
    output.parent.mkdir(exist_ok=True)
    with zipfile.ZipFile(output, "w", zipfile.ZIP_DEFLATED) as archive:
        if args.legacy_loader:
            for name in LOADER_FILES:
                archive.write(ROOT / "compat/Questboard" / name, "Questboard/" + name)
        else:
            for name in files:
                path = (ROOT / name).resolve()
                if not path.is_relative_to(ROOT) or not path.is_file():
                    raise ValueError(f"Invalid or missing runtime file: {name}")
                archive.write(path, "Taskboard/" + name)
            if not args.curseforge:
                for name in LOADER_FILES:
                    archive.write(ROOT / "compat/Questboard" / name, "Questboard/" + name)
    with zipfile.ZipFile(output) as archive:
        assert archive.testzip() is None
        if args.legacy_loader:
            assert archive.namelist() == ["Questboard/" + name for name in LOADER_FILES]
        else:
            assert "Taskboard/Taskboard.toc" in archive.namelist()
        if args.curseforge:
            assert {name.split("/")[0] for name in archive.namelist()} == {"Taskboard"}
        else:
            assert all("Questboard/" + name in archive.namelist() for name in LOADER_FILES)
    print(output)


if __name__ == "__main__":
    main()
