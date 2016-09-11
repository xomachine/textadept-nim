local textadept = require("textadept")
local events = require("events")
local constants = require("textadept-nim.constants")
local icons = require("textadept-nim.icons")
local nimsuggest = require("textadept-nim.nimsuggest")
local check_executable = require("textadept-nim.utils").check_executable
local sessions = require("textadept-nim.sessions")
local nim_shutdown_all_sessions = function() sessions:stop_all() end
local renamer = require("textadept-nim.rename")

-- Keybinds:
-- API Helper key
local api_helper_key = "ch"
-- GoTo Definition key
local goto_definition_key = "cG"
-- Smart replacer key
local smart_replace_key = "cg"

local on_buffer_delete = function()
  -- Checks if any nimsuggest session left without
  -- binding to buffer.
  -- All unbound sessions will be closed
  local to_remove = {}
  for k, v in pairs(sessions.session_of) do
    local keep = false
    for i, b in ipairs(_BUFFERS) do
      if b.filename ~= nil then
        if b.filename == k then keep = true end
      end
    end
    if not keep then table.insert(to_remove, k) end
  end
  for i, v in pairs(to_remove) do
    sessions:detach(v)
  end
end

local on_file_load = function()
  -- Called when editor loads file.
  -- Trying to get information about project and starts nimsuggest
  if buffer ~= nil and buffer:get_lexer(true) == "nim" then
    buffer.use_tabs = false
    buffer.tab_width = 2
    nimsuggest.check()
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


local function remove_type_info(text, position)
  if buffer == nil or buffer:get_lexer(true) ~= "nim" then
    return
  end
  local name = text:match("^([^:]+):.*")
  if name ~= nil
  then
    local pos = buffer.current_pos
    local to_paste = name:sub(pos-position+1)
    buffer:insert_text(pos, to_paste)
    buffer:word_right_end()
    buffer:auto_c_cancel()
  end
end

local function nim_complete(name)
  -- Returns a list of suggestions for autocompletion
  buffer.auto_c_separator = 35
  icons:register()
  local shift = 0
  local curline = buffer:get_cur_line()
  local cur_col = buffer.column[buffer.current_pos] + 1
  for i = 1, cur_col do
    local shifted_col = cur_col - i
    local c = curline:sub(shifted_col, shifted_col)
    if c == c:match("([^%w_-])")
    then
      shift = i - 1
      break
    end
  end
  local suggestions = {}
  local token_list = nimsuggest.suggest(buffer.current_pos-shift)
  for i, v in pairs(token_list) do
    table.insert(suggestions, v.name..": "..v.type.."?"..icons[v.skind])
  end
  if #suggestions == 0 then
    return textadept.editing.autocompleters.word(name)
  end
  if #suggestions == 1 then
    remove_type_info(suggestions[1], buffer.current_pos - shift)
    return
  end
  return shift, suggestions
end

if check_executable(constants.nimsuggest_exe) then
  events.connect(events.FILE_AFTER_SAVE, on_file_load)
  events.connect(events.QUIT, nim_shutdown_all_sessions)
  events.connect(events.RESET_BEFORE, nim_shutdown_all_sessions)
  events.connect(events.FILE_OPENED, on_file_load)
  events.connect(events.BUFFER_DELETED, on_buffer_delete)
  events.connect(events.AUTO_C_SELECTION, remove_type_info)
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
          answer[1].skind:match("sk(.*)").." "..answer[1].name..": "..
          answer[1].type.."\n"..answer[1].comment)
        end
      end
    end,
    -- Goto definition on Ctrl-Shift-G
    [goto_definition_key] = function()
      gotoDeclaration(buffer.current_pos)
    end,
    -- Smart replace
    [smart_replace_key] = renamer.spawn_dialog,
  }
  textadept.editing.autocompleters.nim = nim_complete
end
if check_executable(constants.nim_compiler_exe) then
  textadept.run.compile_commands.nim = function ()
    return constants.nim_compiler_exe.." "..
      sessions.active[sessions.session_of[buffer.filename]].project.backend..
      " %p"
  end
  textadept.run.run_commands.nim = function ()
    return constants.nim_compiler_exe.." "..
      sessions.active[sessions.session_of[buffer.filename]].project.backend..
      " --run %p"
  end
end
