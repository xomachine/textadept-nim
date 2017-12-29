

local _M = 
{
  ["skUnknown"] =       _SCINTILLA.next_image_type(),
  ["skConditional"] =   _SCINTILLA.next_image_type(),
  ["skDynLib"] =        _SCINTILLA.next_image_type(),
  ["skParam"] =         _SCINTILLA.next_image_type(),
  ["skGenericParam"] =  _SCINTILLA.next_image_type(),
  ["skTemp"] =          _SCINTILLA.next_image_type(),
  ["skModule"] =        _SCINTILLA.next_image_type(),
  ["skType"] =          _SCINTILLA.next_image_type(),
  ["skVar"] =           _SCINTILLA.next_image_type(),
  ["skLet"] =           _SCINTILLA.next_image_type(),
  ["skConst"] =         _SCINTILLA.next_image_type(),
  ["skResult"] =        _SCINTILLA.next_image_type(),
  ["skProc"] =          _SCINTILLA.next_image_type(),
  ["skMethod"] =        _SCINTILLA.next_image_type(),
  ["skIterator"] =      _SCINTILLA.next_image_type(),
  ["skConverter"] =     _SCINTILLA.next_image_type(),
  ["skMacro"] =         _SCINTILLA.next_image_type(),
  ["skTemplate"] =      _SCINTILLA.next_image_type(),
  ["skField"] =         _SCINTILLA.next_image_type(),
  ["skEnumField"] =     _SCINTILLA.next_image_type(),
  ["skForVar"] =        _SCINTILLA.next_image_type(),
  ["skLabel"] =         _SCINTILLA.next_image_type(),
  ["skStub"] =          _SCINTILLA.next_image_type(),
  ["skPackage"] =       _SCINTILLA.next_image_type(),
  ["skAlias"] =         _SCINTILLA.next_image_type(),
}

_M.xpms = {}

local current_dir = debug.getinfo(1).short_src:match("(.*)icons.lua")


for xpm, t in pairs(_M)
do
  if type(t) == "number" then
    local fname = lfs.abspath(current_dir.."images/"..xpm..".xpm")
    local f = io.open(fname, "r")
    if f == nil then
      ui.print("PANIC! Can't open file "..tostring(fname))
    else
      _M.xpms[xpm] = f:read("*a")
      f:close()
    end
  end
end


function _M:register()
  for icon, t in pairs(_M)
  do
    if type(t) == "number" then
      buffer:register_image(t, _M.xpms[icon])
    end
  end
end
return _M
