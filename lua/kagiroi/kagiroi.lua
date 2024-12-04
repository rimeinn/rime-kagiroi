-- common dependency for kagiroi lua scripts

local utf8 = require("utf8")
local Module = {}
-- @param string utf8
-- @param i start_pos
-- @param j end_pos
function Module.utf8_sub(s, i, j)
    i = i or 1
    j = j or -1
    local n = utf8.len(s)
    if not n then
        return nil
    end
    if i > n or -j > n then
        return ""
    end
    if i < 1 or j < 1 then
        if i < 0 then
            i = n + 1 + i
        end
        if j < 0 then
            j = n + 1 + j
        end
        if i < 0 then
            i = 1
        elseif i > n then
            i = n
        end
        if j < 0 then
            j = 1
        elseif j > n then
            j = n
        end
    end
    if j < i then
        return ""
    end
    i = utf8.offset(s, i)
    j = utf8.offset(s, j + 1)
    if i and j then
        return s:sub(i, j - 1)
    elseif i then
        return s:sub(i)
    else
        return ""
    end
end

-- get the common prefix of two strings
-- @param s1 string
-- @param s2 string
-- @return string common prefix,string remaining s1,string remaining s2
function Module.utf8_common_prefix(s1, s2)
    local len = math.min(utf8.len(s1), utf8.len(s2))
    if len == 0 then
        return "", s1, s2
    end

    for i = 1, len do
        local c1 = Module.utf8_sub(s1, i, i)
        local c2 = Module.utf8_sub(s2, i, i)
        if c1 ~= c2 then
            return Module.utf8_sub(s1, 1, i - 1), Module.utf8_sub(s1, i), Module.utf8_sub(s2, i)
        end
    end
    return Module.utf8_sub(s1, 1, len), Module.utf8_sub(s1, len + 1), Module.utf8_sub(s2, len + 1)
end

function Module.utf8_char_iter(s)
    local i = 0
    local len = utf8.len(s)
    return function()
        i = i + 1
        if i <= len then
            return Module.utf8_sub(s, i, i)
        end
    end
end

function Module.append_trailing_space(str)
    return str:gsub("%s*$", " ")
end

function Module.trim_trailing_space(str)
    return str:gsub("%s+$", "")
end

function Module.insert_sorted(list, new_element, compare)
    if #list == 0 then
        table.insert(list, new_element)
        return
    end
    local low, high = 1, #list
    while low <= high do
        local mid = math.floor((low + high) / 2)
        if compare(new_element, list[mid]) then
            high = mid - 1
        else
            low = mid + 1
        end
    end
    table.insert(list, low, new_element)
end

return Module
