-- kagiroi_kana_speller.lua
-- convert input to hiragana
-- license: GPLv3
-- version: 0.1.0
-- author: kuroame
local kAccepted = 1
local kNoop = 2
local XK_BackSpace = 0xff08
local Top = {}
local kagiroi = require("kagiroi/kagiroi")

local nfc_map = {
    ["か゛"] = "が",
    ["き゛"] = "ぎ",
    ["く゛"] = "ぐ",
    ["け゛"] = "げ",
    ["こ゛"] = "ご",
    ["さ゛"] = "ざ",
    ["し゛"] = "じ",
    ["す゛"] = "ず",
    ["せ゛"] = "ぜ",
    ["そ゛"] = "ぞ",
    ["た゛"] = "だ",
    ["ち゛"] = "ぢ",
    ["つ゛"] = "づ",
    ["て゛"] = "で",
    ["と゛"] = "ど",
    ["は゛"] = "ば",
    ["ひ゛"] = "び",
    ["ふ゛"] = "ぶ",
    ["へ゛"] = "べ",
    ["ほ゛"] = "ぼ",
    ["う゛"] = "ゔ",
    ["は゜"] = "ぱ",
    ["ひ゜"] = "ぴ",
    ["ふ゜"] = "ぷ",
    ["へ゜"] = "ぺ",
    ["ほ゜"] = "ぽ"
}

local function get_alphabet_suffix(text, alphabet)
    local suffix = ""
    for i = #text, 1, -1 do
        local ch = text:sub(i, i)
        if alphabet:find(ch, 1, true) then
            suffix = ch .. suffix
        else
            break
        end
    end
    return suffix
end

function Top.init(env)
    env.prefix = env.engine.schema.config:get_string("kagiroi/prefix") or ""
    env.layout = "kagiroi_" .. env.engine.schema.config:get_string("kagiroi/layout") or "romaji"
    env.alphabet = env.engine.schema.config:get_string("kagiroi/speller/alphabet") or "zyxwvutsrqponmlkjihgfedcba-;"
    env.gikun_delimiter = env.engine.schema.config:get_string("kagiroi/gikun/alphabet")
    env.roma2hira_xlator = Component.Translator(env.engine, Schema(env.layout), "translator", "script_translator")
    env.kana_speller_cache = {}

    -- clean broken bytes & justify caret position
    local last_caret_pos = 0
    env.update_notifier = env.engine.context.update_notifier:connect(function(ctx)
        local input = ctx.input
        local len, error_pos = utf8.len(input)
        local caret_pos = ctx.caret_pos
        if not len then
            if caret_pos >= error_pos then
                ctx:pop_input(1)
            else
                ctx:delete_input(1)
            end
        else
            local left_input = input:sub(1, caret_pos)
            local _, error_pos = utf8.len(left_input)
            if error_pos then
                -- moved left
                if last_caret_pos > caret_pos then
                    ctx.caret_pos = error_pos - 1
                else -- moved right
                    local next_bound = utf8.offset(input, 2, error_pos)
                    ctx.caret_pos = next_bound and next_bound - 1 or #input
                end
            else
                last_caret_pos = ctx.caret_pos
            end
        end
    end, 0)
    env.gikun_enable = env.engine.schema.config:get_bool("kagiroi/gikun/enable") or true
    env.gikun_delimiter = env.engine.schema.config:get_string("kagiroi/gikun/delimiter") or ";"
end

function Top.fini(env)
    env.roma2hira_xlator = nil
    env.update_notifier:disconnect()
    collectgarbage()
end

function Top.func(key_event, env)
    if key_event:release() or key_event:ctrl() or key_event:alt() or key_event:super() then
        return kNoop
    end
    local keycode = key_event.keycode
    if keycode < 0x20 or keycode > 0x7E then
        return kNoop
    end
    local ch = string.char(keycode)
    if not env.alphabet:find(ch, 1, true) then
        return kNoop
    end
    local context = env.engine.context
    local last_seg = context.composition:back()
    local input = context.input
    local remaining_alphabet = ""
    if last_seg then
        local seg_start = last_seg.start
        if last_seg:has_tag("kagiroi") then
            local seg_text = input:sub(seg_start + 1, last_seg._end)
            remaining_alphabet = get_alphabet_suffix(seg_text, env.alphabet)
            if env.gikun_enable and remaining_alphabet:sub(1, 1) == env.gikun_delimiter then
                remaining_alphabet = remaining_alphabet:sub(2, -1)
            end
        elseif seg_start ~= 0 or input ~= env.prefix then
            return kNoop
        end
    elseif env.prefix ~= "" then
        return kNoop
    end
    local alphabet_text = ch == " " and remaining_alphabet or remaining_alphabet .. ch
    local cand = Top.query_roma2hira_xlator(alphabet_text, env)
    if cand then
        local new_text = cand.text .. alphabet_text:sub(cand._end + 1)
        if #remaining_alphabet > 0 then
            context:pop_input(#remaining_alphabet)
        end
        if cand.text == "゛" or cand.text == "゜" then
            local last_utf8_char = kagiroi.utf8_sub(context.input, -1, -1)
            local nfc_string = nfc_map[last_utf8_char .. cand.text]
            if nfc_string then
                new_text = nfc_string
                context:pop_input(#last_utf8_char)
            end
        end
        context:push_input(new_text)
        return kAccepted
    end
    return kNoop
end

function Top.query_roma2hira_xlator(input, env)
    if env.kana_speller_cache[input] then
        return env.kana_speller_cache[input]
    end
    local pseudo_seg = Segment(0, #input)
    pseudo_seg.tags = Set {"kagiroi"}
    local xlation = env.roma2hira_xlator:query(input, pseudo_seg)
    if xlation then
        local nxt, thisobj = xlation:iter()
        local cand = nxt(thisobj)
        env.kana_speller_cache[input] = cand
        return cand
    end
    return nil
end

return Top
