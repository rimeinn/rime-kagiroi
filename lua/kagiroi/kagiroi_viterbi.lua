-- kagiroi_viterbi.lua
-- maintain a lattice for viterbi algorithm
-- to offer contextual candidates.

-- license: GPLv3
-- version: 0.2.1
-- author: kuroame

local kagiroi = require("kagiroi/kagiroi")
local PriorityQueue =  require("kagiroi/priority_queue")
local Module = {
    kagiroi_dict = require("kagiroi/kagiroi_dict"),
    hira2kata_opencc = Opencc("kagiroi_h2k.json"),
    lattice = {}, -- lattice for viterbi algorithm
    max_word_length = 15,
    lookup_cache = {},
    surface = "",
}

local Node = {}

-- create a new node
-- @param left_id int
-- @param right_id int
-- @param cost float
-- @param surface string
function Node:new(left_id, right_id, cost, surface, candidate, type)
    local o = {}
    setmetatable(o, self)
    self.__index = self
    o.prev_index_col = 0 -- previous node column
    o.prev_index_row = 0 -- previous node row
    o.left_id = left_id -- left id of the node, from lex
    o.right_id = right_id -- right id of the node, from lex
    o.cost = cost -- cost of the node, should = prev.cost + matrix(prev.left_id, right_id) + wcost(from lex)
    o.surface = surface -- surface of the node, from lex
    o.candidate = candidate -- candidate of the node, from lex
    o.type = type -- type of the node: dummy, lex, bos(begin of sentence), eos(end of sentence)
    o.start = -1 -- start pos
    o._end = -1 -- end pos
    o.wcost = 0
    return o
end

-- create a new node from a lex entry
-- @param lex table
-- @return Node
function Node:new_from_lex(lex)
    return Node:new(lex.left_id, lex.right_id, lex.cost, lex.surface, lex.candidate, "lex")
end

-- ----------------------------
-- Private Functions of Module
-- ----------------------------

-- lookup the lexicon/user_dic entry for the surface
-- @param surface string
-- @return iterator of entries
function Module._lookup(surface)
    if Module.lookup_cache[surface] then
        local cached_results = Module.lookup_cache[surface]
        local index = 0
        return function()
            index = index + 1
            return cached_results[index]
        end
    end
    local lex_iter = Module.kagiroi_dict.query_lex(surface, false)
    local userdict_iter = Module.query_userdict(surface)
    local merged_iter = Module._merge_iter(lex_iter, userdict_iter)
    
    local results = {}
    for entry in merged_iter do
        table.insert(results, entry)
    end
    Module.lookup_cache[surface] = results
    local index = 0
    return function()
        index = index + 1
        return results[index]
    end
end


-- get the previous node of the node
-- @param node Node
-- @return Node
function Module._pre_node(node)
    return Module.lattice[node.prev_index_col][node.prev_index_row]
end

-- merge two iterators
-- @param iter1 iterator
-- @param iter2 iterator
-- @return iterator
function Module._merge_iter(iter1, iter2)
    local current_iter = iter1
    return function()
        while current_iter do
            local result = current_iter()
            if result then
                return result
            else
                if current_iter == iter1 then
                    current_iter = iter2
                else
                    current_iter = nil
                end
            end
        end
    end
end

-- ----------------------------
-- Public Functions of Module
-- ----------------------------

-- build the lattice for the input
-- column of lattice: start position of the surface
-- @param input string
function Module.analyze(input)
    Module.surface = input
    local input_len_utf8 = utf8.len(input)
    
    -- initialize lattice columns as empty tables
    for i = 1, input_len_utf8 + 1 do
        Module.lattice[i] = {}
    end
    -- set the eos node
    local eos = Node:new(0, 0, 0, "", "", "eos")
    Module.lattice[input_len_utf8 + 1][1] = eos
    -- i: start position of the surface
    -- j: end position of the surface
    for j = input_len_utf8, 1, -1 do
        -- search nodes that end at j

        -- check if there are any nodes that start at j + 1
        -- if not, nodes end at j cannot be connected to this lattice
        -- so we can skip this iteration
        if #Module.lattice[j + 1] == 0 then
            goto continue
        end
        local max_start = math.max(1, j - Module.max_word_length + 1)
        for i = max_start, j do
            local surface = kagiroi.utf8_sub(input, i, j)
            local iter = Module._lookup(surface)
            if iter then
                for lex in iter do
                    local node = Node:new_from_lex(lex)
                    -- try to connect to the best node that start at j + 1
                    node.prev_index_col = j + 1
                    local open_nodes = Module.lattice[node.prev_index_col]
                    -- evaluate open nodes
                    node.cost = math.huge
                    node.wcost = lex.cost
                    -- k: row index of the open node
                    for k, open_node in ipairs(open_nodes) do
                        local cost_without_matrix = open_node.cost + node.wcost
                        if cost_without_matrix > node.cost then
                            break
                        end
                        local cost_with_matrix = cost_without_matrix +
                            Module.kagiroi_dict.query_matrix(lex.right_id, open_node.left_id)
                        if cost_with_matrix < node.cost then
                            node.cost = cost_with_matrix
                            node.prev_index_row = k
                        end
                    end
                    node.start = i
                    node._end = j
                    kagiroi.insert_sorted(Module.lattice[i], node, function(a, b)
                        return a.cost < b.cost
                    end)
                end
            end
        end
        ::continue::
    end

    -- sort the nodes in lattice[1] by cost
    table.sort(Module.lattice[1], function(a, b)
        return a.cost + Module.kagiroi_dict.query_matrix(eos.right_id, a.left_id) <
            b.cost + Module.kagiroi_dict.query_matrix(eos.right_id, b.left_id)
    end)
end

-- generate the nbest list for the prefix
-- @return iterator of nbest prefixes
function Module.best_n_prefix()
    local current_index = 1
    local current_dummy_index = 1
    local high_quality_count = 7
    local high_quality_cost = 46040
    local surface = {}
    local max_dummy_surface_len = 4
    local next_node_cost = 0
    local dummy_node_iter = function()
        if current_dummy_index > #surface then
            return nil
        end
        local dummy_node = Node:new(0, 0, 46041, surface[current_dummy_index][1], surface[current_dummy_index][2], "dummy")
        current_dummy_index = current_dummy_index + 1
        return dummy_node
    end

    if #Module.lattice[1] == 0 then
        table.insert(surface, {Module.surface, Module.surface})
        table.insert(surface, {Module.surface, Module.hira2kata_opencc:convert(Module.surface)})
        return dummy_node_iter
    end

    local best_n_node_iter = function()
        if current_index > #Module.lattice[1] then
            return nil
        elseif current_index == #Module.lattice[1] then
            next_node_cost = math.huge
        else
            next_node_cost = Module.lattice[1][current_index + 1].cost
        end
        local best_n_node = Module.lattice[1][current_index]
        if (utf8.len(best_n_node.surface) < max_dummy_surface_len) then
            table.insert(surface, {best_n_node.surface, best_n_node.surface})
            table.insert(surface, {best_n_node.surface,Module.hira2kata_opencc:convert(best_n_node.surface)})
        end
        high_quality_count = high_quality_count - 1
        current_index = current_index + 1
        return best_n_node
    end
    return function()
        if next_node_cost >= high_quality_cost or high_quality_count <= 0 then
            return dummy_node_iter() or best_n_node_iter()
        end
        return best_n_node_iter()
    end
end

-- generate nbest candidate for the input
-- @return iterator of nbest sentences
function Module.best_n(n)
    n = (n and n > 0) and n or 10
    local first_nodes = Module.lattice[1]
    local pending_sentences = PriorityQueue()
    local result_sentences = {}
    local result_sen_cost_by_cand = {}
    local search_cost_threshold = math.huge
    local m = n
    for _, node in ipairs(first_nodes) do
        local initial = {
            g = node.wcost + Module.kagiroi_dict.query_matrix(0, node.left_id), -- history cost, 0 is bos.right_id
            h = node.cost - node.wcost, -- heuristic cost
            prefix = nil,
            last_node = node
        }
        pending_sentences:put(initial, initial.g + initial.h)
    end
    while true do
        local cur_sentence = pending_sentences:pop()
        if not cur_sentence 
            or (cur_sentence.g + cur_sentence.h) > search_cost_threshold then -- prune here since there are only sentences with larger cost left
            break
        end
        local last_node = cur_sentence.last_node
        local sentence_cost = cur_sentence.g + cur_sentence.h
        if last_node.type == "eos" then
            local candidate = ""
            local surface = ""
            local right_id = nil
            while cur_sentence and cur_sentence.prefix do
                local node = cur_sentence.last_node
                if right_id == nil and node.type ~= "eos" then
                    right_id = node.right_id
                end
                candidate = node.candidate .. candidate
                surface = node.surface .. surface
                cur_sentence = cur_sentence.prefix
            end
            local final_cand = cur_sentence.last_node.candidate .. candidate
            local existing_cand = result_sen_cost_by_cand[final_cand]
            if not existing_cand or existing_cand > sentence_cost then
                if existing_cand then
                    -- duplicated text, hence the need for one more cand
                    m = m + 1
                end
                kagiroi.insert_sorted(result_sentences, 
                    {
                        surface = cur_sentence.last_node.surface .. surface,
                        candidate = final_cand,
                        cost = sentence_cost,
                        left_id = cur_sentence.last_node.left_id,
                        right_id = right_id or cur_sentence.last_node.right_id,
                    },
                    function(a, b)
                        return a.cost < b.cost
                    end
                )
                result_sen_cost_by_cand[final_cand] = sentence_cost
                -- update cost threshold for pruning
                if #result_sentences >= m then
                    search_cost_threshold = result_sentences[m].cost
                end
            end
        else   
            local open_nodes = Module.lattice[last_node._end + 1]
            for _, open_node in ipairs(open_nodes) do
                local extended = {  
                    g = cur_sentence.g + open_node.wcost +
                    Module.kagiroi_dict.query_matrix(last_node.right_id, open_node.left_id), -- history cost
                    h = open_node.cost - open_node.wcost, -- heuristic cost
                    prefix = cur_sentence,
                    last_node = open_node
                }
                local ex_f = extended.g + extended.h
                if ex_f < search_cost_threshold then
                    pending_sentences:put(extended, ex_f)
                end
            end
        end
    end
    return result_sentences
end

function Module.clear()
    Module.lattice = {}
    Module.lookup_cache = {}
    Module.surface = ""
end

function Module.init(env)
    Module.kagiroi_dict.load()
    Module.clear()
    Module.query_userdict = function(surface)
        return nil
    end
end

function Module.fini()
    Module.clear()
    Module.kagiroi_dict.release()
end

return Module