local textadept = require("textadept")
local events = require("events")
local nimsuggest_executable = "nimsuggest"
local nim_compiler = "nim"
local nimble_exe = "nimble"
local icons = require("textadept-nim.icons")
local nimsuggest = require("textadept-nim.nimsuggest")
-- Windows executable names 
if WIN32 then
  nimsuggest_executable = nimsuggest_executable .. ".exe"
  nim_compiler = nim_compiler .. ".exe"
  nimble_exe = nimble_exe .. ".exe"
end

-- Keybinds:
-- API Helper key
local api_helper_key = "ch"
-- GoTo Definition key
local goto_definition_key = "cG"

-- list of active nimsuggest sessions
local active_sessions = {}
-- colors of compiller messages
local message_styles = {
  ["Error"] = 15, -- ORANGE
  ["Hint"]  = 3, -- PALE GREEN
  ["Warning"] = 13 -- YELLOW,
}

local function check_executable(exe)
  return (nil ~= io.popen(exe.. " -v"):read('*all'))
end

local function nim_start_session(files)
  -- Starts new nimsuggest session when it doesn't exist
  -- otherwise binds existing session to current buffer
  if active_sessions[files] == nil then
    local current_dir = io.get_project_root(buffer.filename) or buffer.filename:match("^([%p%w]-)[^/\\]+$") or "."
    active_sessions[files] = spawn(nimsuggest_executable.." --stdin "..files, current_dir , error_handler, parse_errors, error_handler)
    if active_sessions[files] == nil or active_sessions[files]:status() ~= "running" then
      error("Cannot start nimsuggest!")
    end
  end
  buffer.nimsuggest_files = files
end

local function nim_shutdown_session (nimhandle)
  -- Closes given nimsuggest session
  if nimhandle ~= nil and nimhandle:status() ~= "terminated" then
    nimhandle:write("quit\n\n")
    nimhandle:close()
  end
end

local on_buffer_delete = function()
  -- Checks if any nimsuggest session left without
  -- binding to buffer.
  -- All unbound sessions will be closed
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

local nim_shutdown_all_sessions = function()
  -- Stops all nimsuggest sessions
  for k, v in ipairs(active_sessions) do
    nim_shutdown_session(v)
  end
end

local on_file_load = function()
  -- Called when editor loads file.
  -- Trying to get information about project and starts nimsuggest
  if buffer ~= nil and buffer:get_lexer(true) == "nim" then
    buffer.use_tabs = false
    buffer.tab_width = 2
    buffer.nim_backend = "c"
  end
end



local function gotoDeclaration(position)
  -- Puts cursor to declaration
  local answer = nimsuggest.definition(position)
  if #answer > 0 then
    local path = answer[1].file
    local line = tonumber(answer[1].line) - 1
    local col = tonumber(answer[1].column)
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
    local suggestions = nimsuggest.context(pos)
    for i, v in pairs(suggestions) do
      local brackets = v.type:match("%((.*)%)")
      buffer:call_tip_show(pos, brackets)
    end
  end,
  [46] = function(pos)
    textadept.editing.autocomplete("nim")
  end,
}

local function check_syntax()
  -- Performs syntax check and shows errors
  if buffer:get_lexer() ~= "nim" then return end
  nimsuggest.check()
end

local function nim_complete(name)
  -- Returns a list of suggestions for autocompletion
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
  local token_list = nimsuggest.suggest(buffer.current_pos-shift)
  for i, v in pairs(token_list) do
    table.insert(suggestions, v.name.."?"..icons[v.skind])
  end
  if #suggestions == 0 then
    return textadept.editing.autocompleters.word(name)
  end
  icons:register()
  return shift, suggestions
end

if check_executable(nimsuggest_executable) then
  events.connect(events.FILE_AFTER_SAVE, check_syntax)
  events.connect(events.QUIT, nim_shutdown_all_sessions)
  events.connect(events.FILE_OPENED, on_file_load)
  events.connect(events.FILE_OPENED, check_syntax)
  events.connect(events.BUFFER_DELETED, on_buffer_delete)
  events.connect(events.CHAR_ADDED, function(ch)
    if buffer:get_lexer() ~= "nim" or ch > 90 or actions_on_symbol[ch] == nil
    then return end
    actions_on_symbol[ch](buffer.current_pos)
  end)
  keys.nim = { 
    -- Documentation loader on Ctrl-H
    [api_helper_key] = function()
      if buffer:get_lexer() == "nim"  then 
        if textadept.editing.api_files.nim == nil then
          textadept.editing.api_files.nim = {}
        end
        local answer = nimsuggest.definition(buffer.current_pos)
        if #answer > 0 then
          buffer:call_tip_show(buffer.current_pos,
          answer[1].name.." - "..answer[1].type.."\n"..answer[1].comment)
        end
      end
    end,
    -- Goto definition on Ctrl-Shift-G
    [goto_definition_key] = function()
      gotoDeclaration(buffer.current_pos)
    end,
  }
  textadept.editing.autocompleters.nim = nim_complete
end
if check_executable(nim_compiler) then
  textadept.run.compile_commands.nim = function () return nim_compiler.." "..buffer.nim_backend.." %p" end
  textadept.run.run_commands.nim = function () return nim_compiler.." "..buffer.nim_backend.." --run %p" end
end
