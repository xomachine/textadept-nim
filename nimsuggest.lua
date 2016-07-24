local check_type = require("textadept-nim.utils").check_type
local sessions = require("textadept-nim.sessions")



local function make_request(command, pos)
  -- Request nimsuggest session to do a command then returns parsed answer
  local filename = buffer.filename
  local dirtyname = buffer.modify and os.tmpname() or filename
  if buffer.modify then
    local tmpfile = io.open(dirtyname, "w")
    tmpfile:write(buffer:get_text())
    tmpfile:close()
  end
  local position = pos ~= nil and (":"..tostring(buffer.line_from_position(pos)+1)..
    ":".. tostring(buffer.column[pos]+1)) or "" -- TODO: check it's correctness
  local request = command.." "..filename..";"..dirtyname..position
  local answer = sessions:request(request, filename)
  if dirtyname ~= filename
  then
    os.remove(dirtyname)
  end
  return answer
end

local _M = {}

function _M.check()
  -- Requests nimsuggest to check buffer
  make_request("chk")
  make_request("debug")
  -- Required to turn off debug mode what automaticaly enabled after chk
end

function _M.suggest(pos)
  check_type("number", pos)
  return make_request("sug", pos)
end



function _M.context(pos)
  check_type("number", pos)
  return make_request("con", pos)
end

function _M.definition(pos)
  check_type("number", pos)
  return make_request("def", pos)
end

function _M.usage(pos)
  check_type("number", pos)
  local messages = make_request("use", pos)
end

function _M.def_and_use(pos)
  check_type("number", pos)
  return make_request("dus", pos)
end

function _M.outline()
  return make_request("outline")
end

function _M.highlight()
  return make_request("highlight")
end

return _M