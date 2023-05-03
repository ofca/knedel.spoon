require('hs.spoons')
-- Custom loader for Knedel files.
table.insert(package.loaders or package.searchers, 2, function(moduleName)
    local path = hs.spoons.scriptPath()
    local prefix = "knedel/"
    local prefixLength = string.len(prefix)
    -- Replace dots to slashes.
    moduleName = moduleName:gsub("%.", "/")
    if moduleName:sub(1, prefixLength) == prefix then
        local filePath = path..moduleName:sub(prefixLength+1)..".lua"
        local file = io.open(filePath, "rb")
        if file then
            return assert(load(assert(file:read("*a")), filePath))
        end
    end
    return "no file "..path..moduleName:sub(prefixLength+1).."lua (custom loaded)"
end)
require('hs.hotkey')
local chooser = require('knedel.chooser')

-- Uncomment when debugging.
hs.logger.setGlobalLogLevel(5);

local obj={}
obj.__index = obj

-- Metadata
obj.name = "Knedel"
obj.version = "0.1"
obj.author = "ofca"
obj.homepage = ""
obj.license = "MIT - https://opensource.org/licenses/MIT"

hs.hotkey.bind({"alt"}, "tab", function() chooser:show() end)

return obj