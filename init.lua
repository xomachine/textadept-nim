print("Hello nim!")
local textadept = require("textadept")
local events = require("events")
local nim_executable = "nimsuggest"

local input_pipe = nil
local output_pipe = nil
function nim_start_server(file)
  local tmp_fname = os.tmpname()
  print("created tmp file with name "..tmp_fname)
  local in_stream = io.popen(--"tail -f "..tmp_fname.." | "..
    nim_executable.." --stdin --v2 "..file .." >> "..tmp_fname
    , "w")
  local o_stream = io.open(tmp_fname, "r")
  local nim_shutdown_server = function()
    in_stream:write("quit\n\n")
    in_stream:flush()
    in_stream:close()
    o_stream:close()
    os.remove(tmp_fname)
  end
  if io.type(in_stream) ~= "file" then
    print("Error! Cannot start nim process")
  end
  if io.type(o_stream) ~= "file" then
    print("Error! Cannot open output stream")
  end
  in_stream:setvbuf("no")
  o_stream:setvbuf("no")
  events.connect(events.QUIT, nim_shutdown_server)
  return in_stream, o_stream
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
  if io.type(input_pipe) ~= "file" or io.type(output_pipe) ~= "file" then
    print("Nimsuggest not started! Starting now...")
    input_pipe, output_pipe = nim_start_server(buffer.filename)
  end
  local position = tostring(buffer.line_from_position(pos)+1)..
    ":".. tostring(buffer.column[pos]+1)
  local filename = buffer.filename
  local request = command.." "..filename..dirtyname..":"..position
  print(request)
  input_pipe:write(request.."\n")
  input_pipe:flush()
  local no_wait = false
  local answer = nil
  local token_list = {}
  repeat
    repeat
      answer = output_pipe:read()
      -- instead of timer, required replacement
    until no_wait or answer ~= nil
    no_wait = true
    if answer == nil then
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
  local token_list = do_request(command, buffer.current_pos)
  for i, v in pairs(token_list) do
    if requests[v.reqtype] ~= nil then
      table.insert(suggestions, requests[v.reqtype](v))
    end
  end
  print("Shift = "..shift)
  return shift, suggestions
end
textadept.editing.autocompleters.nim = nim_complete
