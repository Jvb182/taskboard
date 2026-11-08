"""Build an installable addon ZIP using only files required by the TOC."""
from pathlib import Path
import argparse
import re
import zipfile

ROOT = Path(__file__).resolve().parents[2]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--curseforge", action="store_true", help="Build the single-folder CurseForge file")
    args = parser.parse_args()
    toc = (ROOT / "Taskboard.toc").read_text(encoding="utf-8")
    version = re.search(r"^## Version: ([\w.-]+)$", toc, re.MULTILINE).group(1)
    files = ["Taskboard.toc", "Bindings.xml", "README.md", "docs/TESTING.md"]
    files += [line.strip().replace("\\", "/") for line in toc.splitlines()
              if line.strip() and not line.startswith("#")]
    output = ROOT / "dist" / f"Taskboard-{version}{'-CurseForge' if args.curseforge else ''}.zip"
    output.parent.mkdir(exist_ok=True)
    with zipfile.ZipFile(output, "w", zipfile.ZIP_DEFLATED) as archive:
        for name in files:
            path = (ROOT / name).resolve()
            if not path.is_relative_to(ROOT) or not path.is_file():
                raise ValueError(f"Invalid or missing runtime file: {name}")
            archive.write(path, "Taskboard/" + name)
        if not args.curseforge:
            archive.write(ROOT / "compat/Questboard/Questboard.toc", "Questboard/Questboard.toc")
    with zipfile.ZipFile(output) as archive:
        assert archive.testzip() is None
        assert "Taskboard/Taskboard.toc" in archive.namelist()
        if args.curseforge:
            assert {name.split("/")[0] for name in archive.namelist()} == {"Taskboard"}
        else:
            assert "Questboard/Questboard.toc" in archive.namelist()
    print(output)


if __name__ == "__main__":
    main()
