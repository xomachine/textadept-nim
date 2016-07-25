local check_type = require("textadept-nim.utils").check_type
local errortips = require("textadept-nim.errortips")
local parse_errors = errortips.parse_errors
local error_handler = errortips.error_handler
local get_root = require("textadept-nim.project").detect_project_root
local nimsuggest_executable = require("textadept-nim.constants").nimsuggest_exe

local _M = {}

-- There is placed active sessions
_M.active = {}
-- Filename-to-sessionname association
_M.session_of = {}



function _M:get_handle(filename)
  -- Creates new session for file if it isn't exist and returns
  -- handle for the session
  check_type("string", filename)
  local session_name = _M.session_of[filename] or get_root(filename)
  
  if _M.active[session_name] == nil 
  then
    _M.active[session_name] = {name = session_name}
  end
  local session = _M.active[session_name]

  if session.handle == nil or
    session.handle:status() ~= "running"
  then
    -- create new session
    local current_dir = session_name:match("^(.+)[/\\][^/\\]+$") or "."
    local current_handler = function(code)
      error_handler(_M.active[session_name], code)
    end
    session.handle = spawn(nimsuggest_executable.." --stdin --debug --v2 "..session_name, 
      current_dir, current_handler, parse_errors, current_handler)
    if session.handle == nil or
      session.handle:status() ~= "running"
    then
      error("Cann't start nimsuggest!")
    end
  end

  if session.files == nil
  then
    session.files = {}
  end
  session.files[filename] = true
  return session.handle
end

function _M:detach(filename)
  -- Stops nimsuggest session for filename if no other file uses it
  check_type("string", filename)
  local session_name = _M.session_of[filename]
  if session_name == nil
  then
    return
  end
  _M.session_of[filename] = nil
  local session = _M.active[session_name]
  if session ~= nil
  then
    session.files[filename] = nil
    if #session.files == 0
    then
      if session.handle ~= nil and session.handle:status() ~= "terminated"
      then
        session.handle:write("quit\n\n")
        session.handle:close()
      end
      _M.active[session_name] = nil
    end
  end
end

function _M:request(command, filename)
  -- Requesting nimsuggest to do command and returns
  -- parsed answer as a structure
  local nimhandle = _M:get_handle(filename)
  nimhandle:write(command.."\n")
  local message_list = {}
  repeat
    local answer = nimhandle:read()
    if answer == "" then
      break
    end
    table.insert(message_list, answer)
  until answer == nil
  return message_list
end

function _M:stop_all()
  -- Stops all nimsuggest sessions.
  -- Use at exit or reset only
  for file, session in pairs(_M.active)
  do
    if session.handle ~= nil and session.handle:status() ~= "terminated"
    then
      session.handle:write("quit\n\n")
      session.handle:close()
    end
  end
  _M.active = nil
  _M.session_of = nil
end

return _M
