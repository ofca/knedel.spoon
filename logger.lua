require('hs.logger')
require('hs.spoons')

local Logger = {}
Logger.__index = Logger

-- Logger:new()
-- Method
-- Logger constructor
function Logger:new()
    local o = {}
    setmetatable(o, Logger)
    o.logger = hs.logger.new("Knedel")
    return o
end

-- Logger:debug(...)
-- Method
-- Log debug message.
function Logger:debug(...)
    local args = ""
    local params = {...}
    local first = true
    for i = 1, select("#", ...) do
        args = args..(first and "" or "  |  ")..Logger.dump(params[i])
        first = false
    end

    if self.logger.level == 5 then
        local deb = debug.getinfo(2)
        local len = string.len(hs.spoons.scriptPath())
        local file = deb.source:sub(len+2, string.len(deb.source))
        print("Knedel["..file..":"..deb.currentline.."]  "..args)
    end
end

-- Dump
function Logger.dump(value)
    local t = type(value)
    if t == 'table' then
        local s = '{ '
        for k,v in pairs(value) do
            if type(k) ~= 'number' then k = '"'..k..'"' end
            s = s .. '['..k..'] = ' .. Logger.dump(v) .. ','
        end
        return s .. '} '
    elseif value == nil then
        return "nil"
    elseif t == "number" then
        return value
    elseif t == "string" then
        return "\""..value.."\""
    else
        return tostring(value)
    end
end

return Logger:new()

