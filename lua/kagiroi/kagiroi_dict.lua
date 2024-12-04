-- kagiroi_dic.lua
-- load lex.csv and matrix.def data to LevelDB
-- expose functions to query data

-- License: GPLv3
-- version: 0.1.0
-- author: kuroame

local Module = {
    dic_db = nil
}
local ref_count = 0
local pathsep = (package.config or '/'):sub(1, 1)
-- open dict, if dict is empty, load from resources
function Module.load()
    if ref_count > 0 then
        ref_count = ref_count + 1
        return
    end
    Module._open_dic()
    local lex_count = Module._get_lex_count()
    if lex_count <= 0 then
        log.info("Loading lex.csv...")
        Module._load_lex_file(rime_api.get_user_data_dir() .. pathsep .. "lua" .. pathsep .. "kagiroi" .. pathsep ..
                                  "dic" .. pathsep .. "lex.csv")
        log.info("Loading matrix.def...")
        Module._load_matrix_file(rime_api.get_user_data_dir() .. pathsep .. "lua" .. pathsep .. "kagiroi" .. pathsep ..
                                     "dic" .. pathsep .. "matrix.def")
        log.info("Data loaded.")
    end
    log.info("kagiroi lex count: " .. Module._get_lex_count())
    log.info("kagiroi matrix count: " .. Module._get_matrix_count())
    ref_count = 1
end

-- release dict, closing the underlying LevelDB
function Module.release()
    ref_count = ref_count - 1
    if ref_count > 0 then
        return
    end
    if Module.dic_db and Module.dic_db:loaded() then
        Module.dic_db:close()
    end
end

-- query lex
-- @param surface string
-- @param is_prefix boolean
-- @return function iterator
function Module.query_lex(surface, is_prefix)
    local lex_key_prefix = "LEX:" .. surface
    if not is_prefix then
        lex_key_prefix = lex_key_prefix .. ":"
    end
    local res = Module.dic_db:query(lex_key_prefix)
    local function iter()
        if not res then
            return nil
        end
        local next_func, self = res:iter()
        return function()
            while true do
                local key, value = next_func(self)
                if key == nil then
                    return nil
                end
                local entry = Module._unpack_lex(key, value)
                if entry ~= nil then
                    return entry
                end
            end
        end
    end
    return iter()
end

-- predefined matrix cost
local PREDEFINED = {}
PREDEFINED["MATRIX:-1:-1"] = 1
PREDEFINED["MATRIX:0:-1"] = 1
PREDEFINED["MATRIX:-1:0"] = 1

-- query matrix to get cost
-- @param prev_id number
-- @param next_id number
function Module.query_matrix(prev_id, next_id)
    local key = "MATRIX:" .. prev_id .. ":" .. next_id
    local predefined = PREDEFINED[key]
    if predefined then
        return predefined
    end
    local value = Module.dic_db:fetch(key)
    if value then
        return tonumber(value)
    else
        return math.huge
    end
end

------------------------------------------------------------
-- private functions
------------------------------------------------------------

-- open LevelDB
function Module._open_dic()
    Module.dic_db = LevelDb("lua/kagiroi/dic")
    if not Module.dic_db:open() then
        error("Failed to open LevelDB database.")
    end
end

-- unpack lex data
-- @param key string LEX 
-- @param value string LEX 
-- @return table, fields:
--   - surface (string)
--   - left_id (number)
--   - right_id (number)
--   - candidate (string)
--   - cost (number)
function Module._unpack_lex(key, value)
    local parts = {}

    -- key: LEX:{surface}:{left_id}:{right_id}:{candidate} eg. LEX:いい:2426:2426:良い
    local surface, left_id, right_id, candidate = key:match("LEX:([^:]+):(%d+):(%d+):([^:]+)")

    -- value: cost eg. 100
    local cost = value

    parts.surface = surface
    parts.left_id = tonumber(left_id)
    parts.right_id = tonumber(right_id)
    parts.candidate = candidate
    parts.cost = tonumber(cost)
    return parts
end

-- load lex.csv data to LevelDB
-- @param filePath string lex.csv file path
function Module._load_lex_file(filePath)
    local file = io.open(filePath, "r")
    if not file then
        error("Failed to open lex file: " .. filePath)
    end

    local lexCount = 0

    for line in file:lines() do
        local fields = {}
        for field in string.gmatch(line, "([^,]+)") do
            table.insert(fields, field)
        end

        if #fields >= 5 then
            -- surface form
            local surface = fields[1]
            -- left_id、right_id
            local left_id = fields[2]
            local right_id = fields[3]
            -- cost
            local cost = fields[4]
            -- candidate
            local candidate = fields[5]

            -- build key
            local key = "LEX:" .. surface .. ":" .. left_id .. ":" .. right_id .. ":" .. candidate
            -- build value
            local value = cost
            -- update LevelDB
            if not Module.dic_db:update(key, value) then
                error("Failed to update key: " .. key)
            end

            lexCount = lexCount + 1
        end
    end

    if not Module.dic_db:update("META:LEXCOUNT", tostring(lexCount)) then
        error("Failed to update meta key: Meta:LEXCOUNT")
    end

    file:close()
end

-- load matrix.def data to LevelDB
-- @param filePath string matrix.def file path
function Module._load_matrix_file(filePath)
    local file = io.open(filePath, "r")
    if not file then
        error("Failed to open matrix file: " .. filePath)
    end

    -- we don't need the first line for now
    local firstLine = file:read("*line")

    local matrixCount = 0

    for line in file:lines() do
        local fields = {}
        for field in string.gmatch(line, "([^%s]+)") do
            table.insert(fields, field)
        end

        if #fields == 3 then
            -- left id, right id, cost
            local left_id = fields[1]
            local right_id = fields[2]
            local cost = fields[3]

            -- build key,value
            local key = "MATRIX:" .. left_id .. ":" .. right_id
            local value = cost

            -- update LevelDB
            if not Module.dic_db:update(key, value) then
                error("Failed to update key: " .. key)
            end

            matrixCount = matrixCount + 1
        end
    end

    if not Module.dic_db:update("META:MATRIXCOUNT", tostring(matrixCount)) then
        error("Failed to update meta key: Meta:MATRIXCOUNT")
    end
    file:close()
end

-- get lex count
-- @return number 
function Module._get_lex_count()
    local value = Module.dic_db:fetch("META:LEXCOUNT")

    if value then
        return tonumber(value)
    else
        return 0
    end
end

-- get matrix count
-- @return number
function Module._get_matrix_count()
    local value = Module.dic_db:fetch("META:MATRIXCOUNT")

    if value then
        return tonumber(value)
    else
        return 0
    end
end

return Module

