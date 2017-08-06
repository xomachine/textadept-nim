local thesamefile = require("textadept-nim.utils").thesamefile
local _M = {}
local message_styles = {
  ["Error"] = 15, -- ORANGE
  ["Hint"]  = 3, -- PALE GREEN
  ["Warning"] = 13 -- YELLOW,
}

function _M.parse_errors(answers)
  -- Parses output of nimsuggest containing an error
  -- and returns a table with error fields
  if type(answers) == "number" then return end
  if answers:match("^Error") then
    error_handler(answers)
    return nil
  end
  local suggestion_list = {}
  for answer in answers:gmatch("[^\n]+") do
    local message = {}
    message.type, message.comment = answer:match("(%u%l+):(.*)")
    message.file, message.line, message.column = answer:match(
    "^([^%(]+)%s*%(([0-9]+),%s*([0-9]+)%)")
    table.insert(suggestion_list, message)
  end
  _M.highlight_errors(suggestion_list)
 end

function _M.highlight_errors(suggestion_list)
  -- Sets the errors from list as annotations
  buffer:annotation_clear_all()
  local nested = nil
  local previous = nil
  for i, message in pairs(suggestion_list) do
    -- If message should be added to previous for 
    -- recognizing its type
    if nested ~= nil then
      message.file = nested.file
      message.line = nested.line
      -- If message still untyped - look for next one
      -- otherwise reset "nested" and proceed next message
      -- in normal way
      if message.type ~= nil then
        nested = nil
      else
        message.type = "Info"
      end
    end
    -- If unable to parse string after parsed message - append it to the last message
    if message.file ~= nil and thesamefile(buffer.filename, message.file) then 
      previous = message
      -- If message has no type but associated with file
      -- it must be generic/template issue and its type
      -- will be found in next messages
      -- nested - place where message should be added to
      if message.type == nil  then
        message.comment = answer:match("%)(.*)")
        nested = message
        message.type = "Info"
      end
      local line = tonumber(message.line) - 1
      local a = buffer.annotation_text[line]
      local comment = message.type..": " ..message.comment
      if a:len() > 0 then
        buffer.annotation_text[line] = a.."\n"..comment
      else
        buffer.annotation_text[line] = comment
      end
      local style = message_styles[message.type]
      if style ~= nil and buffer.annotation_style[line] < style then
        buffer.annotation_style[line] = style
      end
    end
  end
end

function _M.error_handler(session, err)
  -- Prints debug information when nimsuggest prints
  -- anything to stdout or stops with errorcode
  local handle = session.handle
  local filename = tostring(buffer.filename)
  if type(err) == "number" then
    if err == 0 then return end -- When exited normally
    err = "Nimsuggest crushed with error code: "..err
  end
  if err:match("^usage:.*")~=nil
  then
    return
  end
  ui.dialogs.textbox({
    title="Nimsuggest reported an error",
    informative_text="Nimsuggest reported an error!\n"..
    "Please attach this debug output to your bugreport.",
    text=err.."\nOpened file name: "..filename..
    "\nFilename passed to nimsuggest: "..(session.name or "N/A")..
    "\nWorking directory: "..tostring(filename:match("^([^/\\]+)/*\\*[^/\\]+$"))..
    "\nProject root: "..tostring(io.get_project_root(buffer.filename))..
    "\nHandler status: "..(handle ~= nil and handle:status() or "N/A")
    })
end

return _M