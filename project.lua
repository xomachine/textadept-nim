local check_type = require("textadept-nim.utils").check_type
local _M = {}

local sep = WIN32 and "\\" or "/"

function _M.detect_project_root(filename)
  -- Trying to obtain project root file 
  -- If not succeed returns passed filename
  check_type("string", filename)
  
  local root_dir = io.get_project_root(buffer.filename) or
                   filename:match("^([%p%w]-)[^/\\]+$") or
                   "."
  
  local nimble_file = ""
  lfs.dir_foreach(root_dir, function(n)
        if n:match("%.nimble") or n:match("%.babel") then
          nimble_file = n
          return false
        end
      end,
    "!.*","", 0, false)
  
  if #nimble_file > 0
  then
    -- parse nimble file
    local srcdir = ""
    local bin = ""
    for line in io.lines(nimble_file)
    do
      local key, val = line:match("^%s*(%S+)%s*=%s*(%S+)")
      if key ~= nil and val ~= nil
      then
        if key == "bin"
        then
          bin = val
        elseif key == "srcDir"
        then
          srcdir = val
        end
      end
    end
    return root_dir..sep..srcdir..sep..bin..".nim"
  end
  return filename
end

return _M
