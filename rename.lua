local nimsuggest = require("textadept-nim.nimsuggest")

local _M = {}

local function samefile(fname, sname)
  local fstat = lfs.attributes(fname)
  local sstat = lfs.attributes(sname)
  return fstat.size == sstat.size and
         fstat.change == sstat.change and
         fstat.access == fstat.access and
         fstat.permissions == fstat.permissions and
         fstat.modification == fstat.modification and
         fstat.dev == fstat.dev
end

_M.spawn_dialog = function()
  local position = buffer.current_pos
  
  local token_list = nimsuggest.def_and_use(position)
  local usages = ""
  for i, v in pairs(token_list) do
    if i > 5 then
      usages = usages.."And "..tostring(#token_list-i+1).." more...\n"
      break
    end
    usages = usages..v.file.."("..v.line..", "..v.column..")"..
      (v.request == "def" and " - Definition" or "").."\n"
  end
  if #token_list == 0
  then
    return
  end
  local current_word = token_list[1].name
  local options = {
    title = "Smart replace",
    informative_text = "Change name in text field and press OK to replace the name"..
      " in defenition and all usages of the object across the project.\n"..
      "Here is some usages:\n"..usages,
    text = current_word,
  }
  local code, result = ui.dialogs.standard_inputbox(options)
  if code == 1 and current_word ~= result then
    local external_files = {}
    for ii = 1, #token_list do
      local i = #token_list - ii + 1
      local v = token_list[i]
      if samefile(v.file, buffer.filename)
      then
        local pos = buffer:find_column(v.line - 1, v.column)
        local selword = buffer:text_range(pos, pos + #current_word)
        if selword:lower() == current_word:lower() and
          current_word:sub(1,1) == selword:sub(1,1) then
          buffer:delete_range(pos, #current_word)
          buffer:insert_text(pos, result)
        end
      else
        if external_files[v.file] == nil then
          external_files[v.file] = {}
        end
        if external_files[v.file][v.line] == nil then
          external_files[v.file][v.line] = {}
        end
        table.insert(external_files[v.file][v.line], v.column)
      end
    end
    for f, v in pairs(external_files)
    do
      local buffer = ""
      local lineno = 0
      for line in io.lines(f)
      do
        lineno = lineno + 1
        if v[lineno] ~= nil
        then
          for i, column in ipairs(v[lineno])
          do
            local selword = line:sub(column+1, column + #current_word)
            if selword == current_word then
              local head = line:sub(1, column)
              local tail = line:sub(column + #current_word+1)
              line = head..result..tail
            end
          end
        end
        buffer = buffer..line..(WIN32 and "\r" or "").."\n"
      end
      local file = io.open(f, "w")
      file.write(buffer)
      file.close()
    end
  end
end

return _M