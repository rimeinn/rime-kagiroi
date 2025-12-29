-- common dependency for kagiroi lua scripts

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
    return Module.utf8_sub(s1, 1, len)
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

function Module.find_nth_char(s, char, n)
    local position = 0
    for i = 1, n do
        position = string.find(s, char, position + 1, true)
        if not position then
            return nil
        end
    end
    return position
end

-- Function to check if a Unicode character is a Hiragana or Katakana
-- @param char_str string (single character UTF-8 string)
-- @return boolean true if it's a kana, false otherwise
function Module.is_kana(char_str)
    if not char_str or char_str == "" then
        return false
    end
    
    local codepoint = utf8.codepoint(char_str)
 
    -- Standard Hiragana and Katakana
    local is_standard_kana = (codepoint >= 0x3040 and codepoint <= 0x309F) or -- Hiragana
                             (codepoint >= 0x30A0 and codepoint <= 0x30FF)    -- Katakana
    
    -- Prolonged Sound Mark (Chōonpu, ー)
    local is_chouonpu = (codepoint == 0x30FC)
 
    -- Archaic/Variant Kana (Hentaigana and some variant Katakana)
    -- Hiragana Supplement (Hentaigana): U+1B000 – U+1B0FF
    -- Katakana Phonetic Extensions (mostly variant Katakana): U+1B100 – U+1B12F
    local is_archaic_kana = (codepoint >= 0x1B000 and codepoint <= 0x1B0FF) or -- Hiragana Supplement
                            (codepoint >= 0x1B100 and codepoint <= 0x1B12F)    -- Katakana Phonetic Extensions
 
    local is_kana_related_symbol = (codepoint == 0x3005) -- Iteration Mark (踊り字)
 
    return is_standard_kana or is_chouonpu or is_archaic_kana  or is_kana_related_symbol
end

-- @param s string (UTF-8 string)
-- @return string The string with non-kana characters trimmed from the end
function Module.trim_non_kana_trailing(s)
    if not s or s == "" then
        return ""
    end
 
    local len = utf8.len(s)
    if not len then -- Handle case where utf8.len returns nil (invalid UTF-8 sequence)
        return s -- Or return "" depending on desired error handling
    end
 
    local last_kana_idx = 0 -- Keep track of the index of the last kana character
    
    -- Iterate backward from the end of the string
    -- Note: Module.utf8_char_iter moves forward. We need a way to go backward.
    -- The most straightforward way is to calculate indices and use utf8_sub.
    for i = len, 1, -1 do
        local char = Module.utf8_sub(s, i, i)
        if Module.is_kana(char) then
            last_kana_idx = i
            break -- Found the last kana, so everything before this is kept
        end
    end
 
    if last_kana_idx == 0 then
        return "" -- No kana found in the string, return empty
    else
        -- Trim the string up to and including the last kana character
        return Module.utf8_sub(s, 1, last_kana_idx)
    end
end

function Module.Thunk(functor)
    local result = nil
    return function()
       if result == nil then
           result = functor()
       end
       return result
    end
end

return Module
