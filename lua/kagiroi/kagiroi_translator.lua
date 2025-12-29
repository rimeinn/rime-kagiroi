-- kagiroi_translator.lua
-- main translator of kagiroi
-- license: GPLv3
-- version: 0.2.1
-- author: kuroame
local kagiroi = require("kagiroi/kagiroi")

local Top = {}
local viterbi = require("kagiroi/kagiroi_viterbi")

-- build rime candidates
local function lex2cand(seg, lex, env, comment)
    local dest_hiragana_str = lex.surface
    local preedit = ""
    local start = seg.start
    local _end = seg.start + #dest_hiragana_str
    local new_entry = DictEntry()
    new_entry.preedit = preedit
    -- save the lex data in entry text
    new_entry.text = lex.candidate .. "|" .. lex.left_id .. " " .. lex.right_id
    -- just use hiragana str as custom code
    new_entry.custom_code = kagiroi.append_trailing_space(dest_hiragana_str)
    local new_cand = Phrase(env.mem, "kagiroi_lex", start, _end, new_entry):toCandidate()
    return ShadowCandidate(new_cand, "kagiroi", lex.candidate, comment or "")
end

function Top.init(env)
    env.kanji_xlator = kagiroi.Thunk(function()
            return Component.Translator(env.engine, Schema('kagiroi_kanji'), "translator", "script_translator")
    end)
    env.matrix_lookup = kagiroi.Thunk(function()
            return ReverseLookup("kagiroi_matrix")
    end)
    env.disable_user_dict_for_patterns = env.engine.schema.config:get_list(
        "kagiroi/translator/disable_user_dict_for_patterns")
    env.hira2kata_halfwidth_opencc = kagiroi.Thunk(function()
            return Opencc("kagiroi_h2kh.json")
    end)
    env.hira2kata_opencc = kagiroi.Thunk(function()
            return Opencc("kagiroi_h2k.json")
    end)
    env.mem = Memory(env.engine, Schema('kagiroi'))
    env.viterbi = viterbi.new(env)
    -- Update the user dict when our candidate is committed.
    env.mem:memorize(function(commit)
        local function save_phrase(dictentry)
            local text, left_id, right_id = string.match(dictentry.text, "(.+)|(-?%d+) (-?%d+)")
            if text and left_id and right_id then
                env.mem:update_userdict(dictentry, 1, "")
            end
            return text, left_id, right_id
        end
        local function is_gikun_delimiter(dictentry)
            if env.gikun_enable and dictentry.custom_code == env.gikun_delimiter then
                return true
            end
            return false
        end
        local gikun_yomikata = nil
        -- If the commit contains multiple entries, we consider it as a sentence
        -- and its left id is the same as the first entry, right id is the same as the last entry.
        if #commit:get() > 1 then
            local stext = ""
            local scustom_code = ""
            local sleft_id = -1
            local sright_id = -1
            for i, dictentry in ipairs(commit:get()) do
                if is_gikun_delimiter(dictentry) then
                    gikun_yomikata = kagiroi.append_trailing_space(scustom_code)
                    stext = ""
                else
                    local text, left_id, right_id = save_phrase(dictentry)
                    if not gikun_yomikata then
                        scustom_code = scustom_code .. kagiroi.trim_trailing_space(dictentry.custom_code)
                        if sleft_id == -1 and left_id then
                            sleft_id = left_id
                        end
                        if right_id then
                            sright_id = right_id
                        end
                    end
                    stext = stext .. text
                end
            end
            local sentry = DictEntry()
            sentry.text = stext .. "|" .. sleft_id .. " " .. sright_id
            sentry.custom_code = gikun_yomikata or kagiroi.append_trailing_space(scustom_code)
            env.mem:update_userdict(sentry, 1, "")
        else
            local dictentry = commit:get()[1]
            if dictentry.text then
                save_phrase(dictentry)
            end
        end
        env.viterbi:clear()
    end)
    env.delete_notifier = env.engine.context.delete_notifier:connect(function(ctx)
        env.viterbi:clear()
    end, 0)

    env.tag = env.engine.schema.config:get_string("kagiroi/tag") or ""
    env.mapping_projection = Projection(env.engine.schema.config:get_list('kagiroi/translator/input_mapping'))
    env.sentence_size = env.engine.schema.config:get_int("kagiroi/translator/sentence/size") or 2

    -- gikun support
    env.gikun_enable = env.engine.schema.config:get_bool("kagiroi/gikun/enable") or true
    env.gikun_delimiter = env.engine.schema.config:get_string("kagiroi/gikun/delimiter") or ";"
end

function Top.fini(env)
    env.mem:disconnect()
    env.pseudo_xlator = nil
    env.delete_notifier:disconnect()
    env.viterbi = nil
    collectgarbage()
end

function Top.func(input, seg, env)
    if env.tag ~= "" and not seg:has_tag(env.tag) then
        return
    end
    env.mem:finish_session()
    if env.gikun_enable then
        Top.gikun(input, seg, env)
    end
    local projected = env.mapping_projection:apply(input, true)
    Top.henkan(input, projected, seg, env)
end

function Top.henkan(input, projected, seg, env)
    local trimmed = kagiroi.trim_non_kana_trailing(projected)
    if env.gikun_enable then
        trimmed = string.gsub(trimmed, env.gikun_delimiter .. ".*$", "")
    end
    if trimmed == "" then
        return
    end
    local katakana = env.engine.context:get_option("katakana")
    local hw_katakana = env.engine.context:get_option("hw_katakana")
    if katakana or hw_katakana then
        yield(Top.katakana(input, trimmed, seg, hw_katakana, env))
    end
    -- find the best n sentences matching the complete input

    env.viterbi:analyze(trimmed)
    local iter = env.viterbi:best_n()
    local sentence_size = env.sentence_size
    local sentence = iter()
    while sentence ~= nil and sentence_size > 0 do
        yield(lex2cand(seg, sentence, env))
        sentence = iter()
        sentence_size = sentence_size - 1
    end

    -- find the best n prefixes for partial selecting,
    --    insert some kanji candidates after high-quality candidates
    local prefix_iter = env.viterbi:best_n_prefix()
    local kanji_iter = Top.kanji(trimmed, seg, env)
    local KANJI_CANDIDATE_COST_THRESHOLD_0 = 10000
    local KANJI_CANDIDATE_COST_THRESHOLD_1 = 245546
    local kanji = kanji_iter()
    for phrase in prefix_iter do
        while kanji do
            if phrase.cost > KANJI_CANDIDATE_COST_THRESHOLD_1 then
                yield(lex2cand(seg, kanji, env))
                kanji = kanji_iter()
            elseif phrase.cost > KANJI_CANDIDATE_COST_THRESHOLD_0 then
                if kanji.surface == trimmed and phrase.surface ~= trimmed then
                    yield(lex2cand(seg, kanji, env))
                    kanji = kanji_iter()
                else
                    break
                end
            else
                break
            end
        end
        yield(lex2cand(seg, phrase, env))
    end
    while kanji do
        yield(lex2cand(seg, kanji, env))
        kanji = kanji_iter()
    end
end

function Top.gikun(input, seg, env)
    if env.engine.context.composition:toSegmentation():get_confirmed_position() == 0 then
        return
    end
    local delimiter_len = string.len(env.gikun_delimiter)
    if string.sub(input, 1, delimiter_len) == env.gikun_delimiter then
        local delimiter_entry = DictEntry()
        delimiter_entry.text = ""
        delimiter_entry.custom_code = env.gikun_delimiter
        local delimiter_cand =
            Phrase(env.mem, "kigun_delimiter", seg.start, seg.start + delimiter_len, delimiter_entry):toCandidate()
        delimiter_cand.quality = math.huge
        yield(ShadowCandidate(delimiter_cand, "kigun_delimiter_shadowed", "", "義訓"))
    end
end

function Top.katakana(input, trimmed, seg, is_half_width, env)
    if is_half_width then
        local katakana_halfwidth_str_trimmed = env.hira2kata_halfwidth_opencc():convert(trimmed)
        local katakana_halfwidth_str = env.hira2kata_halfwidth_opencc():convert(input)
        local katakana_halfwidth_cand = Candidate("kagiroi", seg.start, seg._end, katakana_halfwidth_str_trimmed, "")
        katakana_halfwidth_cand.preedit = katakana_halfwidth_str
        return katakana_halfwidth_cand
    else
        local katakana_str_trimmed = env.hira2kata_opencc():convert(trimmed)
        local katakana_str = env.hira2kata_opencc():convert(input)
        local katakana_cand = Candidate("kagiroi", seg.start, seg._end, katakana_str_trimmed, "")
        katakana_cand.preedit = katakana_str
        return katakana_cand
    end
end

function Top.kanji(input, seg, env)
    local xlation = env.kanji_xlator():query(input, seg)
    if not xlation then
        return function() return nil end
    end
    local next, iter = xlation:iter()
    return function()
        while true do
            local cand = next(iter)
            if not cand then
                return nil
            end
            if cand.type ~= "sentence" then
                local lex = {
                    candidate = cand.text,
                    left_id = 1920,
                    right_id = 1920,
                    surface = cand.preedit
                }
                return lex
            end
        end
    end
end

return Top
