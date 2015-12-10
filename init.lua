print("Hello nim!")
local textadept = require("textadept")
local events = require("events")
local nim_executable = "nimsuggest"

local handler = nil
function nim_start_server(file)
  local handle = spawn(nim_executable.." --stdin --v2 "..file)
  local nim_shutdown_server = function()
    handle:write("quit\n\n")
    handle:close()
    handle:wait()
  end
  events.connect(events.QUIT, nim_shutdown_server)
  return handle
end

local requests = {
  sug = function(tokens) 
      local modulename, stmtname = string.match(tokens.fullname,
      "([^%.]+)%.(.+)")
      if modulename == nil then return tokens.fullname end
      return stmtname 
    end,
  con = function(tokens)
    local inside = string.match(tokens.data,
    "proc%s+%((.*)%)")
    local modulename, stmtname = string.match(tokens.fullname,
    "([^%.]+)%.(.+)")
    local point_pos = buffer.current_pos - 2 - string.len(stmtname)
    if point_pos > 0 and buffer.char_at[point_pos] == 46 then
      local pre_arg = do_request("sug", point_pos - 2)
      for i, v in ipairs(pre_arg) do
        print("PreArgDef: "..v.stmtkind.." - "..v.fullname)
      end
      inside = string.gsub(inside,"[^,]+,?%s*", "", 1)
    end
    inside = string.gsub(inside,"var%s+", "")
    inside = string.gsub(inside,",", "")
    inside = string.gsub(inside,":%s+", ":")
    return inside
  end,

  use = function(tokens) end,
  def = function(tokens) end,
}

function do_request(command, pos)

  local dirtyname = ""
  if handler == nil or handler:status() ~= "running" then
    print("Nimsuggest not started! Starting now...")
    handler = nim_start_server(buffer.filename)
  end
  local position = tostring(buffer.line_from_position(pos)+1)..
    ":".. tostring(buffer.column[pos]+1)
  local filename = buffer.filename
  local request = command.." "..filename..dirtyname..":"..position
  print(request)
  handler:write(request.."\n")
  local answer = ""
  local token_list = {}
  repeat
      answer = handler:read()
    no_wait = true
    if answer == "" then
      break
    end
    print("Answer: "..answer)
    local tokens = {}
    tokens.reqtype, tokens.stmtkind, tokens.fullname, tokens.data, tokens.path,
    tokens.line, tokens.col, tokens.comment = string.match(answer, 
    "(%l%l%l)%s+(sk%u%l+)%s+(%S+)%s+(.+)%s+(%S+)%s+(%d+)%s+(%d+)%s+(\".*\")")
    if tokens.reqtype ~= nil then
      for k, v in  pairs(tokens) do
        print (k..": "..v)
      end
      table.insert(token_list, tokens)
    end
  until answer == nil
  return token_list
end

function nim_complete(name)
  print("Nim autocompleter call")
  local  command = "sug"
  local shift = 0
  for i = 1, buffer.column[buffer.current_pos] do
    local c = buffer.char_at[buffer.current_pos - i]
    if (c >= 32 and c <= 47)or(c >= 58 and c <= 64)then
      shift = i - 1
      break
    end
  end
  local suggestions = {}
  local token_list = do_request(command, buffer.current_pos-shift)
  for i, v in pairs(token_list) do
    if requests[v.reqtype] ~= nil then
      table.insert(suggestions, requests[v.reqtype](v))
    end
  end
  print("Shift = "..shift)
  return shift, suggestions
end
textadept.editing.autocompleters.nim = nim_complete
