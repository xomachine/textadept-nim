local check_type = require("textadept-nim.utils").check_type
local sessions = require("textadept-nim.sessions")
local highlight_errors = require("textadept-nim.errortips").highlight_errors

local function parse_suggestion(answer)
  -- Parses output of nimsuggest containing a suggestion
  -- and returns a table with suggestion fields
  if answer == nil then return end
  local suggestion = {}
  local tail = ""
  suggestion.request, suggestion.skind, tail =
    answer:match("^(%l+)\t(sk%u%a+)\t(.*)$")
  if suggestion.request == "highlight"
  then
    suggestion.line, suggestion.column, suggestion.length =
      tail:match("^(%d+)\t(%d+)\t(%d+)%s*$")
  elseif suggestion.request ~= nil
  then
    suggestion.fullname, suggestion.type, suggestion.file, suggestion.line,
      suggestion.column, suggestion.comment, suggestion.length =
      tail:match("^([^\t]*)\t([^\t]*)\t([^\t]+)\t(%d+)\t(%d+)\t\"(.*)\"\t(%d+)")
    if suggestion.fullname == nil then return end
    suggestion.modulename, suggestion.functionname, suggestion.name =
      suggestion.fullname:match("^([^%.]+)%.*([^%.]-)%.([^%.]+)$")
    suggestion.name = suggestion.name or suggestion.fullname
    suggestion.comment = suggestion.comment:gsub("\\x0A", "\n")
    suggestion.comment = suggestion.comment:gsub("\\", "")
  else
    return
  end
  suggestion.line = tonumber(suggestion.line)
  suggestion.column = tonumber(suggestion.column)
  return suggestion
end

local function make_request(command, pos)
  -- Request nimsuggest session to do a command then returns parsed answer
  local filename = buffer.filename
  local dirtyname = buffer.modify and
                    ((WIN32 and os.getenv("TEMP") or "")..os.tmpname()) or
                    filename
  if buffer.modify then
    local tmpfile = io.open(dirtyname, "w")
    tmpfile:write(buffer:get_text())
    tmpfile:close()
  end
  local position = pos ~= nil and (":"..tostring(buffer.line_from_position(pos)+1)..
    ":".. tostring(buffer.column[pos]+1)) or "" -- TODO: check it's correctness
  local request = command.." "..filename..";"..dirtyname..position
  local answers = sessions:request(request, filename)
  if dirtyname ~= filename
  then
    os.remove(dirtyname)
  end
  local suggestion_list = {}
  for i, answer in pairs(answers)
  do
    local suggestion = parse_suggestion(answer)
    table.insert(suggestion_list, suggestion)
  end
  return suggestion_list
end

local _M = {}

function _M.check()
  -- Requests nimsuggest to check buffer
  local answer = make_request("chk")
  highlight_errors(answer)
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
  return make_request("use", pos)
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