-- kagiroi_translator.lua
-- main translator of kagiroi

-- license: GPLv3
-- version: 0.1.0
-- author: kuroame

local utf8 = require("utf8")
local kagiroi = require("kagiroi/kagiroi")

local hiragana_node = {
    entry = {},
    children = {}
}

function hiragana_node:new()
    local o = {
        entry = nil,
        children = {}
    }
    setmetatable(o, self)
    self.__index = self
    return o
end

local hiragana_trie = {
    root = hiragana_node:new(),
    syl_list = {}
}

function hiragana_trie:new()
    local o = {
        root = hiragana_node:new(),
        syl_list = {}
    }
    setmetatable(o, self)
    self.__index = self
    return o
end

-- insert a new node to the trie
function hiragana_trie:insert(ustr, entry)
    if self.syl_list[ustr] then
        return
    end
    self.syl_list[ustr] = entry
    local node = self.root
    for i = 1, utf8.len(ustr) do
        local u = kagiroi.utf8_sub(ustr, i, i)
        if not node.children[u] then
            node.children[u] = hiragana_node:new()
        end
        node = node.children[u]
    end
    node.entry = entry
end

function hiragana_trie:init(env)
    local mem = Memory(env.engine, Schema('kagiroi_kana'))
    mem:dict_lookup("", true, 1000)
    for entry in mem:iter_dict() do
        self:insert(entry.text, entry)
    end
end

-- collect the entries from the trie
-- @param text string
-- @return table list of entries
function hiragana_trie:collect(text)
    local result = {}
    local node = self.root
    local buffer = ""
    for i = 1, utf8.len(text) do
        local u = kagiroi.utf8_sub(text, i, i)
        -- check if there's more characters
        -- if exist, append to buffer, and move to next node
        if node.children[u] then
            buffer = buffer .. u
            node = node.children[u]
        else
            -- if not exist, save the current node
            if buffer ~= "" then
                if node.entry then
                    table.insert(result, node.entry)
                end
                -- reset for new search
                buffer = ""
                node = self.root

                if node.children[u] then
                    buffer = buffer .. u
                    node = node.children[u]
                end
            end
        end
    end
    -- save the last node
    if buffer ~= "" and node.entry then
        table.insert(result, node.entry)
    end
    return result
end

local Top = {}
local viterbi = require("kagiroi/kagiroi_viterbi")
local kHenkan = false
local kMuhenkan = true

function Top.init(env)
    viterbi.init()
    env.hiragana_trie = hiragana_trie:new()
    env.hiragana_trie:init(env)
    env.roma2hira_xlator = Component.Translator(env.engine, Schema('kagiroi_kana'), "translator", "script_translator")
    env.pseudo_xlator = Component.Translator(env.engine, Schema('kagiroi'), "translator", "script_translator")
    env.hira2kata_opencc = Opencc("kagiroi_h2k.json")
    env.hira2kata_halfwidth_opencc = Opencc("kagiroi_h2kh.json")
    env.mem = Memory(env.engine, Schema('kagiroi'))

    -- Update the user dict when our candidate is committed.
    env.mem:memorize(function(commit)
        local function save_phrase(dictentry)
            local text, left_id, right_id = string.match(dictentry.text, "(.+)|(%d+) (%d+)")
            if text and left_id and right_id then
                env.mem:update_userdict(dictentry, 1, "")
            end
            return text, left_id, right_id
        end
        
        -- If the commit contains multiple entries, we consider it as a sentence
        -- and its left id is the same as the first entry, right id is the same as the last entry.
        if #commit:get() > 1 then
            local stext = ""
            local scustom_code = ""
            local sleft_id = -1
            local sright_id = -1
            for i, dictentry in ipairs(commit:get()) do
                local text, left_id, right_id = save_phrase(dictentry)
                if sleft_id == -1 and left_id then
                    sleft_id = left_id
                end
                if right_id then
                    sright_id = right_id
                end
                stext = stext .. text
                scustom_code = scustom_code .. kagiroi.trim_trailing_space(dictentry.custom_code)
            end
            local sentry = DictEntry()
            sentry.text = stext .. "|" .. sleft_id .. " " .. sright_id
            sentry.custom_code = kagiroi.append_trailing_space(scustom_code)
            env.mem:update_userdict(sentry, 1, "")
        else
            local dictentry = commit:get()[1]
            if dictentry.text then
                save_phrase(dictentry)
            end
        end
    end)

    -- Register the user dict to the viterbi thingy.
    viterbi.register_userdict(function(input)
        env.mem:user_lookup(input .. " \t", true)
        local next_func, self = env.mem:iter_user()
        return function()
            local entry = next_func(self)
            if not entry then
                return nil
            end
            local candidate, left_id, right_id = string.match(entry.text, "(.+)|(%d+) (%d+)")
            if candidate and left_id and right_id then
                return {
                    surface = kagiroi.trim_trailing_space(entry.custom_code),
                    left_id = tonumber(left_id),
                    right_id = tonumber(right_id),
                    candidate = candidate,
                    cost = 1000 / (entry.commit_count + 1)
                }
            else
                return {
                    surface = kagiroi.trim_trailing_space(entry.custom_code),
                    left_id = -1,
                    right_id = -1,
                    candidate = entry.text,
                    cost = 50 / (entry.commit_count + 1)
                }
            end
        end
    end)

    env.delete_notifier = env.engine.context.delete_notifier:connect(function(ctx)
        viterbi.clear()
    end, 0)

    env.tag = env.engine.schema.config:get_string("kagiroi/tag") or ""

    env.preedit_view = env.engine.schema.config:get_string("kagiroi/preedit_view") or "hiragana"
end

function Top.fini(env)
    env.mem:disconnect()
    env.delete_notifier:disconnect()
    viterbi.fini()
    collectgarbage()
end

function Top.func(input, seg, env)
    if env.tag ~= "" and not seg:has_tag(env.tag) then
        return
    end
    -- query pseudo translator to commit pending transaction
    -- in the comming version of librime, we can use Memory:finish_session()
    -- we use this workaround since most frontends have not been updated yet
    env.pseudo_xlator:query(input, seg)
    local hiragana_cand = Top.query_roma2hira_xlator(input, seg, env)
    local composition_mode = env.engine.context:get_option("composition_mode") or kHenkan
    if hiragana_cand then
        if composition_mode == kHenkan then
            Top.henkan(hiragana_cand, env)
        elseif composition_mode == kMuhenkan then
            Top.muhenkan(hiragana_cand, env)
        end
    end
end

function Top.henkan(hiragana_cand, env)
    local a = env.hiragana_trie
    if not a then
        return
    end
    local hiragana_text = hiragana_cand.text
    viterbi.analyze(hiragana_text)
    -- firstly, find a best match for the whole input
    local best_sentence = viterbi.best()
    yield(Top.lex2cand(hiragana_cand, best_sentence, env, ""))
    -- secondly, send a "contextual" phrase candidate
    local prefix = best_sentence.prefix
    yield(Top.lex2cand(hiragana_cand, prefix, env, ""))
    -- finally, find the best n matches for the input prefix
    local best_n = viterbi.best_n_prefix(hiragana_text, -1)
    while true do
        local phrase = best_n()
        if phrase then
            yield(Top.lex2cand(hiragana_cand, phrase, env, ""))
        else
            break
        end
    end
end

function Top.muhenkan(hiragana_cand, env)
    local hiragana_str = hiragana_cand.text
    local hiragana_simp_cand = Candidate("kagiroi", hiragana_cand.start, hiragana_cand._end, hiragana_str, "")
    hiragana_simp_cand.preedit = hiragana_str
    yield(hiragana_simp_cand)
    local katakana_str = env.hira2kata_opencc:convert(hiragana_str)
    local katakana_cand = Candidate("kagiroi", hiragana_cand.start, hiragana_cand._end, katakana_str, "")
    katakana_cand.preedit = katakana_str
    yield(katakana_cand)
    local katakana_halfwidth_str = env.hira2kata_halfwidth_opencc:convert(hiragana_str)
    local katakana_halfwidth_cand = Candidate("kagiroi", hiragana_cand.start, hiragana_cand._end,
        katakana_halfwidth_str, "")
    katakana_halfwidth_cand.preedit = katakana_halfwidth_str
    yield(katakana_halfwidth_cand)
end

-- build rime candidates
function Top.lex2cand(hcand, lex, env, comment)
    local dest_hiragana_str = lex.surface
    local end_with_sokuon = kagiroi.utf8_sub(dest_hiragana_str, -1) == "っ"
    local end_with_single_n = kagiroi.utf8_sub(dest_hiragana_str, -1) == "ん" and
                                  (hcand.preedit:sub(-2) == " n" or hcand.preedit == "n")

    local preedit = ""
    local start = hcand.start
    local _end

    if hcand.text == dest_hiragana_str then
        _end = hcand._end
        if env.preedit_view == "romaji" then
            preedit = hcand.preedit
        end
    else
        local entry_list = env.hiragana_trie:collect(dest_hiragana_str)
        local syllable_num = #entry_list
        -- SPECIAL CASE: if the dest_hiragana_str end with っ, _end should be in the middle of sokuon
        -- eg. 「a tta」 , _end should be at the first t to separate the tta to t|ta
        if end_with_sokuon then
            _end = Top.find_end(hcand.preedit, hcand.start, hcand._end, syllable_num - 1) + 1
        else
            _end = Top.find_end(hcand.preedit, hcand.start, hcand._end, syllable_num)
        end
        if env.preedit_view == "romaji" then
            for word in string.gmatch(hcand.preedit, "%S+") do
                if preedit == "" then
                    preedit = word
                else
                    preedit = preedit .. " " .. word
                end
                syllable_num = syllable_num - 1
                if syllable_num == 0 then
                    break
                end
            end
        end
    end

    if env.preedit_view == "hiragana" then
        preedit = dest_hiragana_str
        if end_with_single_n and _end == hcand._end then
            preedit = preedit:gsub("ん$", "n")
        end
    elseif env.preedit_view == "katakana" then
        preedit = env.hira2kata_opencc:convert(dest_hiragana_str) or dest_hiragana_str
        if end_with_single_n and _end == hcand._end then
            preedit = preedit:gsub("ン$", "n")
        end
    elseif env.preedit_view == "inline" then
        preedit = lex.candidate
        if end_with_single_n then
            preedit = preedit:gsub("ん$", "n"):gsub("ン$", "n")
        end
    end

    local new_entry = DictEntry()
    new_entry.preedit = preedit
    -- save the lex data in entry text
    new_entry.text = lex.candidate .. "|" .. lex.left_id .. " " .. lex.right_id
    -- just use hiragana str as custom code
    new_entry.custom_code = kagiroi.append_trailing_space(dest_hiragana_str)
    local new_cand = Phrase(env.mem, "kagiroi_lex", start, _end, new_entry):toCandidate()
    return ShadowCandidate(new_cand, "kagiroi", lex.candidate, comment)
end

-- find the end position for the candidate
function Top.find_end(h_preedit, h_start, h_end, syllable_num)
    if syllable_num <= 0 then
        return h_start
    end
    local n = kagiroi.find_nth_char(h_preedit, " ", syllable_num)
    if n then
        return n - syllable_num + h_start
    else
        return h_end
    end
end

-- translate romaji to hiragana
function Top.query_roma2hira_xlator(input, seg, env)
    local xlation = env.roma2hira_xlator:query(input, seg)
    if xlation then
        local nxt, thisobj = xlation:iter()
        local cand = nxt(thisobj)
        return cand
    end
    return nil
end

return Top
