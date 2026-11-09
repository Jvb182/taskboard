"""Runs the Taskboard test suite in Lua 5.1 (the version WoW uses) via lupa.

    pip install lupa
    python tests/run.py            # all specs
    python tests/run.py parser_spec   # one spec
"""
import os
import sys
import argparse
import json
from pathlib import Path

try:
    import lupa.lua51 as lupa_lua51
except ImportError:
    sys.exit("lupa is required: pip install lupa")

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__))).replace("\\", "/") + "/"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("spec", nargs="?")
    parser.add_argument("--report-json", type=Path, help="Write named test results for coverage review")
    parser.add_argument("--addon-root", type=Path, default=Path(ROOT),
                        help="Load runtime files from this Taskboard folder (for packaged ZIP tests)")
    args = parser.parse_args()
    addon_root = args.addon_root.resolve()
    if not (addon_root / "Taskboard.toc").is_file():
        parser.error(f"Missing Taskboard.toc in addon root: {addon_root}")
    lua = lupa_lua51.LuaRuntime(unpack_returned_tuples=True)
    g = lua.globals()
    g.QB_TEST_ROOT = ROOT + "tests/"
    g.QB_ADDON_ROOT = addon_root.as_posix() + "/"
    if args.spec:
        g.QB_ONLY = args.spec
    failed = lua.execute('return dofile(QB_TEST_ROOT .. "run.lua")')
    if args.report_json:
        result = g.QB_RESULT
        report = {"passed": result.passed, "failed": result.failed,
                  "tests": [dict(row.items()) for _, row in result.tests.items()]}
        args.report_json.parent.mkdir(parents=True, exist_ok=True)
        args.report_json.write_text(json.dumps(report, indent=2), encoding="utf-8")
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
