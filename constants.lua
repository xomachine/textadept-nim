local _M = {}

_M.nimsuggest_exe = "nimsuggest"..(WIN32 and ".exe" or "")
_M.nim_compiler_exe = "nim"..(WIN32 and ".exe" or "")
_M.nimble_exe = "nimble"..(WIN32 and ".exe" or "")

return _M