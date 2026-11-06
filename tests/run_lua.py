"""Run the script tests using an installed OBS LuaJIT runtime (Windows x64)."""
import ctypes
import os
from pathlib import Path
import sys
import tempfile

if os.name != 'nt' or ctypes.sizeof(ctypes.c_void_p) != 8:
    raise SystemExit('These integration tests require 64-bit Python on Windows.')

project = Path(__file__).resolve().parents[1]
obs_bin = Path(os.environ.get('OBS_BIN', r'C:\Program Files\obs-studio\bin\64bit'))
os.environ['OBS_BIN'] = str(obs_bin)
os.chdir(project)

with os.add_dll_directory(str(obs_bin)), tempfile.TemporaryDirectory(prefix='obs-router-test-') as test_root:
    os.environ['OBS_ROUTER_TEST_ROOT'] = test_root
    obs_lib = ctypes.CDLL(str(obs_bin / 'obs.dll'))
    dll = ctypes.CDLL(str(obs_bin / 'lua51.dll'))
    dll.luaL_newstate.restype = ctypes.c_void_p
    dll.luaL_openlibs.argtypes = [ctypes.c_void_p]
    dll.luaL_loadfile.argtypes = [ctypes.c_void_p, ctypes.c_char_p]
    dll.lua_pcall.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.c_int, ctypes.c_int]
    dll.lua_tolstring.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.c_void_p]
    dll.lua_tolstring.restype = ctypes.c_char_p
    dll.lua_close.argtypes = [ctypes.c_void_p]
    filename = sys.argv[1] if len(sys.argv) > 1 else 'tests/test_organizer.lua'
    state = dll.luaL_newstate()
    if not state:
        raise SystemExit('Unable to allocate Lua state.')
    try:
        dll.luaL_openlibs(state)
        code = dll.luaL_loadfile(state, filename.encode('utf-8'))
        if not code and '--syntax' not in sys.argv:
            code = dll.lua_pcall(state, 0, -1, 0)
        if code:
            print(dll.lua_tolstring(state, -1, None).decode('utf-8', errors='replace'), flush=True)
        else:
            print('PASS', filename, flush=True)
    finally:
        dll.lua_close(state)
    if code:
        raise SystemExit(1)
