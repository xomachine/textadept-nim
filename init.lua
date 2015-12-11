local textadept = require("textadept")
local events = require("events")
local nimsuggest_executable = "nimsuggest"
local nim_compiler = "nim"
local nimble_exe = "nimble"

-- list of active nimsuggest sessions
local active_sessions = {}

-- Starts new nimsuggest session when it doesn't exist
-- otherwise binds existing session to current buffer
local function nim_start_session(files)
  if active_sessions[files] == nil then
    active_sessions[files] = spawn(nimsuggest_executable.." --stdin --v2 "..files)
  end
  buffer.nimsuggest_files = files
end

-- Closes given nimsuggest session
local function nim_shutdown_session (nimhandle)
  print("Shutdown session: "..tostring(nimhandle))
  if nimhandle ~= nil and nimhandle:status() ~= "terminated" then
    nimhandle:write("quit\n\n")
    nimhandle:close()
  end
end

-- Checks if any nimsuggest session left without
-- binding to buffer.
-- All unbound sessions will be closed
local on_buffer_delete = function()
  local to_remove = {}
  for k, v in ipairs(active_sessions) do
    local keep = false
    for i, b in pairs(_BUFFERS) do
      if b.nimsuggest_files ~= nil then
        if b.nimsuggest_files == k then keep = true end
      end
    end
    if ~keep then table.insert(to_remove, k) end
  end
  for i, v in pairs(to_remove) do
    nim_shutdown_session(active_sessions[v])
    active_sessions[v] = nil
  end
end

local nim_shutdown_all_sessions = function()
  for k, v in ipairs(active_sessions) do
    nim_shutdown_session(v)
  end
end

-- Called when editor loads file.
-- Trying to get information about project and starts nimsuggest
local on_file_load = function()
  if buffer ~= nil and buffer:get_lexer(true) == "nim" then
    buffer.use_tabs = false
    buffer.tab_width = 2
    local root_files = {}
    local proj_root = io.get_project_root(buffer.filename)
    local srcdir = proj_root
    print("Project root: "..tostring(proj_root))
    -- Check if opened file is part of project
    if proj_root ~= nil then
      local proj_file = nil
      -- Search for project file
      lfs.dir_foreach(proj_root,
      function(n)
        if string.match(n, "%.nimble") or string.match(n, "%.babel") then
          print("Found: "..tostring(n))
          proj_file = n
        end
      end,
      "!.*","", 0, false)
      if proj_file ~= nil then
        buffer.project = proj_root
        -- Parse project file
        local backend = "c"
        for line in io.lines(proj_file) do
          local newsrc = string.match(line, "srcDir%s*=%s*(.+)$")
          backend = string.match(line, "backend%s*=%s*(.+)$") or backend
          if newsrc ~= nil then
            srcdir = lfs.abspath(newsrc, proj_root)
          end
        end
        buffer.nim_backend = backend
        -- Search for other sources in project
        lfs.dir_foreach(srcdir,
        function(n)
          table.insert(root_files, n)
        end,
        "!%.nim$", "", 0, false)
      end
      local files = ""
      if #root_files > 0 then
        files = table.concat(root_files," ")
      else
        files = buffer.filename
      end
      nim_start_session(files)
      print("Start session: "..tostring(files))
    end
  end
end


-- list of request responders
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
    return inside
  end,

  use = function(tokens) end,
  def = function(tokens) end,
}


-- Makes request to nimsuggest session bound to current buffer
local function do_request(command, pos)

  local dirtyname = ""
  local semicolon = ""
  if buffer.modify then
    dirtyname = os.tmpname()
    semicolon = ";"
    local tmpfile = io.open(dirtyname, "w")
    tmpfile:write(buffer:get_text())
    tmpfile:close()
  end
  local nimhandle = active_sessions[buffer.nimsuggest_files] 
  if nimhandle == nil or nimhandle:status() ~= "running" then
    print("Nimsuggest not started! Starting now...")
    nim_start_session(buffer.nimsuggest_files or buffer.filename)
  end
  local position = tostring(buffer.line_from_position(pos)+1)..
  ":".. tostring(buffer.column[pos]+1)
  local filename = buffer.filename
  local request = command.." "..filename..semicolon..dirtyname..":"..position
  print(request)
  nimhandle:write(request.."\n")
  local answer = ""
  local token_list = {}
  repeat
    answer = nimhandle:read()
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
      --for k, v in  pairs(tokens) do
      --  print (k..": "..v)
      --end
      table.insert(token_list, tokens)
    end
  until answer == nil
  os.remove(dirtyname)
  return token_list
end

-- list of additional actions on symbol encountering
-- for further use
local actions_on_symbol = {
  [40] = function(pos)
    local suggestions = do_request("con", pos)
    for i, v in pairs(suggestions) do
      local brackets = string.match(v.data, "%((.*)%)")
      print("Calltip: "..brackets)
      buffer:call_tip_show(pos, brackets)
    end
  end,
  [46] = function(pos)
    textadept.editing.autocomplete("nim")
  end,
}

-- Returns a list of suggestions for autocompletion
local function nim_complete(name)
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
  if #suggestions == 0 then
    return textadept.editing.autocompleters.word(name)
  end
  print("Shift = "..shift)
  return shift, suggestions
end

events.connect(events.QUIT, nim_shutdown_all_sessions)
events.connect(events.FILE_OPENED, on_file_load)
events.connect(events.BUFFER_DELETED, on_buffer_delete)
events.connect(events.CHAR_ADDED, function(ch)
  if buffer:get_lexer() ~= "nim" or ch > 90 then return end
  if actions_on_symbol[ch] ~= nil then
    actions_on_symbol[ch](buffer.current_pos)
  end
end)
textadept.editing.autocompleters.nim = nim_complete
textadept.run.compile_commands.nim = function () return nim_compiler.." "..buffer.nim_backend.." %p" end
textadept.run.run_commands.nim = function () return nim_compiler.." "..buffer.nim_backend.." --run %p" end
textadept.run.build_commands.nim = function () if buffer.project ~= nil then 
  return nimble_exe.." build --nimbledir "..buffer.project end end
