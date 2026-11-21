"""Lua CLI subset for CI, using Lua 5.1 (the addon language baseline)."""
import pathlib
import sys
from lupa.lua51 import LuaRuntime

lua = LuaRuntime(unpack_returned_tuples=True)
args = sys.argv[1:]
if args and args[0] == '-e':
    lua.execute(args[1])
else:
    root = pathlib.Path(__file__).resolve().parent.parent
    script = pathlib.Path(args[0]) if args else root / 'tests/run.lua'
    lua.globals().arg = lua.table_from(args[1:] if args else [str(root)])
    lua.execute(script.read_text(encoding='utf-8'))
