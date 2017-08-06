local _M = {}

local exe_tail = (WIN32 and ".exe" or "")
_M.nimsuggest_exe = "nimsuggest"..exe_tail
_M.nim_compiler_exe = "nim"..exe_tail
_M.nimble_exe = "nimble"..exe_tail
local TA_MAJOR, TA_MINOR = _RELEASE:match("^Textadept%s+([0-9]+)%.([0-9]+).*$")
_M.VERMAGIC = tonumber(TA_MAJOR) * 100 + tonumber(TA_MINOR)

return _M