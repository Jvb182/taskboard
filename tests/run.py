"""Runs the Questboard test suite in Lua 5.1 (the version WoW uses) via lupa.

    pip install lupa
    python tests/run.py            # all specs
    python tests/run.py parser_spec   # one spec
"""
import os
import sys

try:
    import lupa.lua51 as lupa_lua51
except ImportError:
    sys.exit("lupa is required: pip install lupa")

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__))).replace("\\", "/") + "/"


def main():
    lua = lupa_lua51.LuaRuntime(unpack_returned_tuples=True)
    g = lua.globals()
    g.QB_TEST_ROOT = ROOT + "tests/"
    g.QB_ADDON_ROOT = ROOT
    if len(sys.argv) > 1:
        g.QB_ONLY = sys.argv[1]
    failed = lua.execute('return dofile(QB_TEST_ROOT .. "run.lua")')
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
