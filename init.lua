print("Hello nim!")
--local buffer = require("buffer")
local textadept = require("textadept")
local events = require("events")
--for k, v in pairs(textadept.editing.autocompleters) do 
  --print(k..":"..tostring(v))
--end
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


function nim_complete(name)
  local dirtyname = ""
  print("Nim autocompleter call")
  if io.type(input_pipe) ~= "file" or io.type(output_pipe) ~= "file" then
    print("Nimsuggest not started! Starting now...")
    input_pipe, output_pipe = nim_start_server(buffer.filename)
  end
  local prev_char = ''
  if buffer.current_pos > 0 then
    prev_char = buffer.char_at[buffer.current_pos-1]
  end
  print(prev_char)
  local position = tostring(buffer.line_from_position(buffer.current_pos)+1)..
    ":".. tostring(buffer.column[buffer.current_pos])
  local filename = buffer.filename
  local command = ""
  if prev_char == 40 then
    command = "con"
  elseif prev_char == 46 then
    command = "sug"
  else
    command = "def"
  end
  local request = command.." "..filename..dirtyname..":"..position
  print(request)
  input_pipe:write(request.."\n")
  input_pipe:flush()
  local no_wait = false
  local answer = nil
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
    for k in string.gmatch(answer, "%S+") do
      table.insert(tokens, k)
      --print(tostring(k))
    end
  until answer == nil
end
textadept.editing.autocompleters.nim = nim_complete
