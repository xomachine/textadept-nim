local utils = require("textadept-nim.utils")
local check_type =  utils.check_type
local file_exists = utils.file_exists
local _M = {}

local sep = WIN32 and "\\" or "/"

local function parse_nimble(filename)
  check_type("string", filename)
  local project = {}
  project.backend = "c" -- nimble builds project in C by default
-- parse nimble file
  for line in io.lines(filename)
  do
    local key, val = line:match("^%s*(%S+)%s*=%s*(%S+)")
    if key == "bin"
    then
      project.bin = val
    elseif key == "srcDir"
    then
      project.srcdir = val
    elseif key == "backend"
    then
      project.backend = val
    elseif line:match("setCommand") ~= nil
    then
      project.backend = line:match("setCommand%s+\"(%a+)\"")
    end
  end
  return project
end


function _M.detect_project(filename)
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
    local project = parse_nimble(nimble_file)
    if project.bin ~= nil
    then -- root file is a file that transforms to a binary
      project.root = root_dir..sep..(project.srcdir or "")..
        sep..project.bin..".nim"
      if file_exists(project.root)
      then
        return project
      end
    end
    -- if project builds no binaries
    -- trying to consider as root a file with name similar to nimble file
    project.root = tostring(nimble_file:match("(.*%.)[^/\\]+")).."nim"
    if not file_exists(project.root)
    then
      -- if it does not exists checking it in srcdir(if exists)
      project.root = root_dir..sep..(project.srcdir or "")..
        project.root:match(".*([/\\][^/\\]+)$")
      if not file_exists(project.root)
      then -- finally give up, project root will be a given file
        project.root = filename
      end
    end
    return project
  end
  local dummy_project = 
  {
    backend = "c",
    srcdir = root_dir,
    root = filename
  } -- When no nimble file detected - just return dummy project for one file
  return dummy_project
end

return _M
