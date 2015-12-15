local textadept = require("textadept")
local events = require("events")
local nimsuggest_executable = "nimsuggest"
local nim_compiler = "nim"
local nimble_exe = "nimble"

-- Keybinds:
-- API Helper key
local api_helper_key = "ch"
-- GoTo Definition key
local goto_definition_key = "cG"

-- list of active nimsuggest sessions
local active_sessions = {}
  local message_styles = {
    ["Error"] = 15, -- ORANGE
    ["Hint"]  = 3, -- PALE GREEN
    ["Warning"] = 13 -- YELLOW,
  }
-- Parses output of nimsuggest containing an error
-- and returns a table with error fields
local function parse_errors(answers)
  buffer:annotation_clear_all()
  local nested = nil
  local previous = nil
  for answer in answers:gmatch("[^\n]+") do
    local message = {}
    message.msgtype, message.text = answer:match("(%u%l+):(.*)")
    message.file, message.line, message.col = answer:match(
    "^([^%(]+)%s*%(([0-9]+),%s*([0-9]+)%)")
    -- If message should be added to previous for 
    -- recognizing its type
    if nested ~= nil then
      print("Nesting "..answer.." to "..nested.file)
      message.text = answer
      message.file = nested.file
      message.line = nested.line
      -- If message still untyped - look for next one
      -- otherwise reset "nested" and proceed next message
      -- in normal way
      if message.msgtype ~= nil then
        nested = nil
      else
        message.msgtype = "Info"
      end
    end
    -- If unable to parse string after parsed message - append it to the last message
    if message.msgtype == nil and message.file == nil and previous ~= nil then
      message = previous
      message.text = answer
      message.msgtype = "Info"
    end
    if message.file ~= nil and buffer.filename:match(message.file.."$") ~= nil then 
      previous = message
      -- If message has no type but associated with file
      -- it must be generic/template issue and its type
      -- will be found in next messages
      -- nested - place where message should be added to
      if message.msgtype == nil  then
        print("No message type for file: "..message.file)
        message.text = answer:match("%)(.*)")
        nested = message
        message.msgtype = "Info"
      end
      local line = tonumber(message.line) - 1
      local a = buffer.annotation_text[line]
      local text = message.msgtype..": " ..message.text
      if a:len() > 0 then
        buffer.annotation_text[line] = a.."\n"..text
      else
        buffer.annotation_text[line] = text
      end
      local style = message_styles[message.msgtype]
      if style ~= nil and buffer.annotation_style[line] < style then
        buffer.annotation_style[line] = style
      end
    end
  end
end

-- Starts new nimsuggest session when it doesn't exist
-- otherwise binds existing session to current buffer
local function nim_start_session(files)
  if active_sessions[files] == nil then
    active_sessions[files] = spawn(nimsuggest_executable.." --stdin "..files, nil, nil, parse_errors )
  end
  buffer.nimsuggest_files = files
end

-- Closes given nimsuggest session
local function nim_shutdown_session (nimhandle)
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
  for k, v in pairs(active_sessions) do
    local keep = false
    for i, b in ipairs(_BUFFERS) do
      if b.nimsuggest_files ~= nil then
        if b.nimsuggest_files == k then keep = true end
      end
    end
    if not keep then table.insert(to_remove, k) end
  end
  for i, v in pairs(to_remove) do
    nim_shutdown_session(active_sessions[v])
    active_sessions[v] = nil
  end
end

-- Stops all nimsuggest sessions
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
    local binary = ""
    -- Check if opened file is part of project
    if proj_root ~= nil then
      local proj_file = nil
      -- Search for project file
      lfs.dir_foreach(proj_root,
      function(n)
        if string.match(n, "%.nimble") or string.match(n, "%.babel") then
          proj_file = n
        end
      end,
      "!.*","", 0, false)
      if proj_file ~= nil then
        buffer.project = proj_root
        textadept.run.build_commands[buffer.project] = nimble_exe.." build"
        -- Parse project file
        local backend = "c"
        for line in io.lines(proj_file) do
          local newsrc = string.match(line, "srcDir%s*=%s*(.+)$")
          local newbinary = line:match("bin%s*=%s*(.+)$")
          backend = string.match(line, "backend%s*=%s*(.+)$") or backend
          if newsrc ~= nil then
            srcdir = lfs.abspath(newsrc, proj_root)
          end
          if newbinary ~= nil then
            binary = newbinary..".nim"
          end
        end
        if binary:len() > 0 then
          binary = lfs.abspath(binary, srcdir)
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
        -- binary should be passed last becouse nimsuggest parses config
        -- only from last file passed
        files = table.concat(root_files," ").." "..binary
      else
        files = buffer.filename
      end
      nim_start_session(files)
    end
  end
end

-- Parses output of nimsuggest containing a suggestion
-- and returns a table with suggestion fields
local function parse_suggestion(answer)
  if answer == nil then return end
  local suggestion = {}
  suggestion.reqtype, suggestion.stmtkind, suggestion.fullname, suggestion.data, suggestion.path,
  suggestion.line, suggestion.col, suggestion.comment = answer:match( 
  "(%l%l%l)%s+(sk%u%l+)%s+(%S+)%s+(.+)%s+(%S+)%s+(%d+)%s+(%d+)%s+\"(.*)\"")
  if suggestion.reqtype ~= nil then
    suggestion.modulename, suggestion.stmtname = suggestion.fullname:match("([^%.]+)%.(.+)")
    suggestion.comment = suggestion.comment:gsub("\\x0A", "\n")
    suggestion.comment = suggestion.comment:gsub("\\", "")
    if suggestion.modulename == nil then suggestion.stmtname = suggestion.fullname end
    return suggestion
  end
end


-- Makes request to nimsuggest session bound to current buffer
local function do_request(command, pos)
  if pos == nil then pos = 0 end
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
    nim_start_session(buffer.nimsuggest_files or buffer.filename)
    nimhandle = active_sessions[buffer.nimsuggest_files] 
  end
  local position = tostring(buffer.line_from_position(pos)+1)..
  ":".. tostring(buffer.column[pos]+1)
  local filename = buffer.filename
  local request = command.." "..filename..semicolon..dirtyname..":"..position
  nimhandle:write(request.."\n")
  local message_list = {}
  repeat
    local answer = nimhandle:read()
    if answer == "" then
      break
    end
    local message = parse_suggestion(answer)
    if message ~= nil then
      table.insert(message_list, message)
    end
  until answer == nil
  os.remove(dirtyname)
  return message_list
end

-- Puts cursor to declaration
local function gotoDeclaration(position)
  local answer = do_request("def", position)
  if #answer > 0 then
    local path = answer[1].path
    local line = tonumber(answer[1].line) - 1
    local col = tonumber(answer[1].col)
    if path ~= buffer.filename then
      ui.goto_file(path, false, view)
    end
    local pos = buffer:find_column(line, col)
    buffer:goto_pos(pos)
    buffer:vertical_centre_caret()
    buffer:word_right_end_extend()
  end
end

-- list of additional actions on symbol encountering
-- for further use
local actions_on_symbol = {
  [40] = function(pos)
    local suggestions = do_request("con", pos)
    for i, v in pairs(suggestions) do
      local brackets = string.match(v.data, "%((.*)%)")
      buffer:call_tip_show(pos, brackets)
    end
  end,
  [46] = function(pos)
    textadept.editing.autocomplete("nim")
  end,
}

-- Performs syntax check and shows errors
local function check_syntax()
  if buffer:get_lexer() ~= "nim" then return end
  local answers = do_request("chk")
  for i, v in pairs(answers) do
    print(tostring(v))
  end
end

-- Returns a list of suggestions for autocompletion
local function nim_complete(name)
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
    table.insert(suggestions, v.stmtname)
  end
  if #suggestions == 0 then
    return textadept.editing.autocompleters.word(name)
  end
  return shift, suggestions
end

keys.nim = { 

  -- Documentation loader on Ctrl-H
  [api_helper_key] = function()
    if buffer:get_lexer() == "nim"  then 
      if textadept.editing.api_files.nim == nil then
        textadept.editing.api_files.nim = {}
      end
      local answer = do_request("def", buffer.current_pos)
      if #answer > 0 then
        buffer:call_tip_show(buffer.current_pos,
        answer[1].stmtname.." - "..answer[1].data.."\n"..answer[1].comment)
      end
    end
  end,
  -- Goto definition on Ctrl-Shift-G
  [goto_definition_key] = function()
    gotoDeclaration(buffer.current_pos)
  end,
}

events.connect(events.FILE_AFTER_SAVE, check_syntax)
events.connect(events.QUIT, nim_shutdown_all_sessions)
events.connect(events.FILE_OPENED, on_file_load)
events.connect(events.FILE_OPENED, check_syntax)
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
