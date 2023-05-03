local module = {
    startsWith = function (str, prefix)
        return str:sub(1, string.len(prefix)) == prefix
    end,
    split = function (str, sep)
        local parts = {}
        for part in string.gmatch(str or "", "[^%"..sep.."]+") do
            parts[#parts+1] = part
        end
        return parts
    end,
    ternary = function(condition, t, f)
        if condition then
            return t
        else
            return f
        end
    end
}

return module