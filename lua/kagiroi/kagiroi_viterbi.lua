-- kagiroi_viterbi.lua
-- maintain a lattice for viterbi algorithm
-- to offer contextual candidates.
-- license: GPLv3
-- version: 0.2.1
-- author: kuroame
local kagiroi = require("kagiroi/kagiroi")
local segmentor = require("kagiroi/segmenter")
local PriorityQueue = require("kagiroi/priority_queue")
local Module = {
    kagiroi_dict = require("kagiroi/kagiroi_dict"),
    hira2kata_opencc = Opencc("kagiroi_h2k.json"),
    lattice = {}, -- lattice for viterbi algorithm
    max_word_length = 100,
    lookup_cache = {},
    bos = nil,
    surface = ""
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
    o.next_index_col = 0 -- next node column
    o.next_index_row = 0 -- next node row
    o.left_id = left_id -- left id of the node, from lex
    o.right_id = right_id -- right id of the node, from lex
    o.cost = cost -- cost of the node, should = prev.cost + matrix(prev.left_id, right_id) + wcost(from lex)
    o.surface = surface -- surface of the node, from lex
    o.candidate = candidate -- candidate of the node, from lex
    o.type = type -- type of the node: dummy, lex, bos(begin of sentence), eos(end of sentence)
    o.start = -1 -- start pos
    o._end = -1 -- end pos
    o.wcost = 0
    o.detour = {}
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
function Module._next_node(node)
    return Module.lattice[node.next_index_col][node.next_index_row]
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

function Module._build_lattice()
    local input = Module.surface
    local input_len_utf8 = utf8.len(input)
    -- initialize lattice columns as empty tables
    for i = 0, input_len_utf8 + 1 do
        Module.lattice[i] = {}
    end
    -- set the eos node
    local eos = Node:new(0, 0, 0, "", "", "eos")
    local bos = Node:new(0, 0, 0, "", "", "bos")
    bos._end = 0
    Module.lattice[input_len_utf8 + 1][1] = eos
    Module.lattice[0][1] = bos
    Module.bos = bos
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
                    node.next_index_col = j + 1
                    local open_nodes = Module.lattice[node.next_index_col]
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
                        if open_node.type == "eos" then
                            cost_with_matrix = cost_with_matrix + Module.kagiroi_dict.get_suffix_penalty(lex.right_id)
                        end
                        if cost_with_matrix < node.cost then
                            node.cost = cost_with_matrix
                            node.next_index_row = k
                        end
                    end
                    node.start = i
                    node._end = j
                    table.insert(Module.lattice[i], node)
                end
            end
            table.sort(Module.lattice[i], function(a, b)
                return a.cost < b.cost
            end)
        end
        ::continue::
    end
    local min_calculated_cost = math.huge
    local min_index_row = 1
    for i, node_a in ipairs(Module.lattice[1]) do
        local current_cost_a = node_a.cost + Module.kagiroi_dict.query_matrix(bos.right_id, node_a.left_id) +
                                   Module.kagiroi_dict.get_prefix_penalty(node_a.left_id)
        if current_cost_a < min_calculated_cost then
            min_calculated_cost = current_cost_a
            min_index_row = i
        end
    end
    bos.cost = min_calculated_cost
    bos.next_index_row = min_index_row
    bos.next_index_col = 1
end

-- build detour
function Module._build_detour()
    local input_len_utf8 = utf8.len(Module.surface)
    -- i: start position of the surface
    for i = 0, input_len_utf8 do
        for _, node in ipairs(Module.lattice[i]) do
            local successor_nodes = Module.lattice[node._end + 1]
            for row, snode in ipairs(successor_nodes) do
                local delta = snode.cost + node.wcost + Module.kagiroi_dict.query_matrix(node.right_id, snode.left_id) -
                                  node.cost
                if i == 0 then
                    delta = delta + Module.kagiroi_dict.get_prefix_penalty(snode.left_id)
                end
                table.insert(node.detour, {
                    delta = delta,
                    node = snode,
                    col = node._end + 1,
                    row = row
                })
            end
            table.sort(node.detour, function(a, b)
                return a.delta < b.delta
            end)
        end
    end
    local bosd = Module.bos.detour
end

-- materialize the deviation as table of lex and cost
function Module._materialize(deviation)
    if deviation._materialized then
        return deviation._materialized
    end
    local bos_node = Module.bos
    if deviation.is_root then
        local lex_table = {}
        local cur_node = bos_node
        while cur_node.type ~= "eos" do
            table.insert(lex_table, cur_node)
            cur_node = Module._next_node(cur_node)
        end
        deviation._materialized = {
            lex_table = lex_table,
            cost = bos_node.cost
        }
        return deviation._materialized
    end
    local parent_materialized = Module._materialize(deviation.parent)
    local lex_table = {}
    local cur_node = bos_node
    local index = 0
    local detoured = false
    while cur_node and cur_node.type ~= "eos" do
        table.insert(lex_table, cur_node)
        if detoured then
            cur_node = Module._next_node(cur_node)
        elseif deviation.detour_node_pre_index == index then
            cur_node = deviation.detour_node.node
            detoured = true
        else
            index = index + 1
            cur_node = parent_materialized.lex_table[index + 1]
        end
    end
    deviation._materialized = {
        lex_table = lex_table,
        cost = parent_materialized.cost + deviation.delta
    }
    return deviation._materialized
end

-- assemble the lex and cost
function Module._assemble(materialized)
    local lex_table = materialized.lex_table
    local candidate = ""
    local surface = ""
    for _, node in ipairs(lex_table) do
        candidate = candidate .. node.candidate
        surface = surface .. node.surface
    end

    local assem = {
        surface = surface,
        candidate = candidate,
        cost = materialized.cost,
        left_id = lex_table[2].left_id,
        right_id = lex_table[#lex_table].right_id
    }
    local debug_func = function()

        local path_str_parts = {}
        local total_cost_check = 0
        local total_cost = assem.cost

        if #lex_table > 1 then
            local bos_node = lex_table[1]
            local first_node = lex_table[2]

            local bos_conn_cost = Module.kagiroi_dict.query_matrix(bos_node.right_id, first_node.left_id)
            local prefix_penalty = Module.kagiroi_dict.get_prefix_penalty(first_node.left_id)

            table.insert(path_str_parts, "BOS")
            table.insert(path_str_parts, string.format("conn(%.0f)+pre(%.0f)", bos_conn_cost, prefix_penalty))
            table.insert(path_str_parts,
                string.format("%s[%s](l:%d,r:%d,w:%.0f)", first_node.candidate, first_node.surface, first_node.left_id,
                    first_node.right_id, first_node.wcost))

            total_cost_check = total_cost_check + bos_conn_cost + prefix_penalty + first_node.wcost

            for i = 3, #lex_table do
                local prev_node = lex_table[i - 1]
                local current_node = lex_table[i]
                local connection_cost = Module.kagiroi_dict.query_matrix(prev_node.right_id, current_node.left_id)
                total_cost_check = total_cost_check + connection_cost + current_node.wcost
                table.insert(path_str_parts, string.format("conn(%.0f)", connection_cost))
                table.insert(path_str_parts,
                    string.format("%s[%s](l:%d,r:%d,w:%.0f)", current_node.candidate, current_node.surface,
                        current_node.left_id, current_node.right_id, current_node.wcost))
            end

            local last_node = lex_table[#lex_table]
            local suffix_penalty = Module.kagiroi_dict.get_suffix_penalty(last_node.right_id)
            total_cost_check = total_cost_check + suffix_penalty
            table.insert(path_str_parts, string.format("suf(%.0f)", suffix_penalty))
        end

        log.info(string.format("total: %.0f (check: %.0f)\t| conv.: %s\t| path: %s", total_cost, total_cost_check,
            assem.candidate, table.concat(path_str_parts, " -> ")))
    end
    -- debug_func()
    return assem
end

function Module._weave_dummy_iter(smart_iter)
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
        local dummy_node = Node:new(0, 0, 46041, surface[current_dummy_index][1], surface[current_dummy_index][2],
            "dummy")
        current_dummy_index = current_dummy_index + 1
        return dummy_node
    end

    if #Module.lattice[1] == 0 then
        table.insert(surface, {Module.surface, Module.surface})
        table.insert(surface, {Module.surface, Module.hira2kata_opencc:convert(Module.surface)})
        return dummy_node_iter
    end

    local cur_smart_node = nil
    local next_node = nil
    local decorate = function()
        while true do
            cur_smart_node = next_node
            next_node = smart_iter()
            if next_node then
                next_node_cost = next_node.cost
            else
                if not cur_smart_node then
                    return nil
                end
                next_node_cost = math.huge
            end
            if cur_smart_node then
                high_quality_count = high_quality_count - 1
                if (utf8.len(cur_smart_node.surface) < max_dummy_surface_len) then
                    table.insert(surface, {cur_smart_node.surface, cur_smart_node.surface})
                    table.insert(surface,
                        {cur_smart_node.surface, Module.hira2kata_opencc:convert(cur_smart_node.surface)})
                end
                return cur_smart_node
            end
        end
    end

    return function()
        if next_node_cost >= high_quality_cost or high_quality_count <= 0 then
            return dummy_node_iter() or decorate()
        end
        return decorate()
    end
end

-- ----------------------------
-- Public Functions of Module
-- ----------------------------

-- build the lattice for the input
-- column of lattice: start position of the surface
-- @param input string
function Module.analyze(input)
    -- log.info("anl. " .. input)
    Module.surface = input
    Module._build_lattice()
end

-- generate the nbest list for the prefix
-- @return iterator of nbest prefixes
function Module.best_n_prefix()
    local bos = Module.bos
    local collector = PriorityQueue()
    for _, pdetour in ipairs(bos.detour) do
        local sect_node = pdetour.node
        local sect_delta = pdetour.delta
        local cur_node = sect_node
        local next_node = Module._next_node(cur_node)
        while next_node do
            if segmentor.is_boundary_internal(cur_node.right_id, next_node.left_id) then
                collector:put({
                    node = cur_node,
                    sect_node = sect_node,
                    delta = sect_delta
                }, sect_delta)
                break
            else
                local best_detour = cur_node.detour[2]
                if best_detour then
                    local delta = best_detour.delta + sect_delta
                    collector:put({
                        node = cur_node,
                        sect_node = sect_node, -- ancestor node in lattice[1]
                        delta = delta -- detour cost
                    }, delta)
                end
            end
            cur_node = next_node
            next_node = Module._next_node(cur_node)
        end
    end
    return Module._weave_dummy_iter(function()
        local deviation = collector:pop()
        local cur_node = deviation.sect_node
        local cost = Module.kagiroi_dict.query_matrix(0, cur_node.left_id) +
                         Module.kagiroi_dict.get_prefix_penalty(cur_node.left_id)
        local lex_table = {bos}
        while true do
            table.insert(lex_table, cur_node)
            cost = cost + cur_node.wcost
            if cur_node == deviation.node then
                break
            end
            local next_node = Module._next_node(cur_node)
            if next_node then
                cost = cost + Module.kagiroi_dict.query_matrix(cur_node.right_id, next_node.left_id)
                cur_node = next_node
            else
                break
            end
        end
        -- log.info("assem. prefix")
        return Module._assemble({
            lex_table = lex_table,
            cost = cost
        })
    end)
end

-- generate nbest candidate for the input
-- @return iterator of nbest sentences
function Module.best_n()
    if not Module._next_node(Module.bos) then
        return function()
            return nil
        end
    end
    local deviations_tree = PriorityQueue()
    local phase = 0
    local root = {
        is_root = true,
        bos = Module.bos,
        delta = 0
    }
    local seen_candidate = {}
    return function()
        while true do
            if phase == 0 then -- return the best sentence
                -- log.info("assem. best, sur. "..Module.surface)
                local assembled = Module._assemble(Module._materialize(root))
                seen_candidate[assembled.candidate] = 1
                phase = 1
                return assembled
            elseif phase == 1 then -- build detour info, and seeding
                Module._build_detour()
                -- seeding
                local cur_node = Module.bos
                local detour_node_pre_index = 0
                while cur_node.type ~= "eos" do
                    local detour_list = cur_node.detour
                    if #detour_list > 1 then
                        local best_detour = detour_list[2]
                        deviations_tree:put({
                            parent = root,
                            detour_node_pre = cur_node, -- pre node of detour node
                            detour_node_pre_index = detour_node_pre_index, -- index of pre node of detour node to find detour_node_pre in O(1)
                            detour_node = best_detour, -- detour node 
                            detour_index = 2, -- index of detour node to find detour node in O(1)
                            delta = best_detour.delta -- delta value of this detour
                        }, best_detour.delta)
                    end
                    detour_node_pre_index = detour_node_pre_index + 1
                    cur_node = Module._next_node(cur_node)
                end
                phase = 2
            elseif phase == 2 then -- peek deviations_tree and return it 
                local deviation = deviations_tree:peek()
                if not deviation then
                    return nil
                end
                phase = 3 -- jump to phase 3 to gather more
                -- log.info("assem. inferior")
                local assembled = Module._assemble(Module._materialize(deviation))
                if seen_candidate[assembled.candidate] == nil then
                    seen_candidate[assembled.candidate] = 1
                    return assembled
                end
                -- drop duplicated cand
            elseif phase == 3 then -- deviate from existing paths
                -- sibling deviation
                local deviation = deviations_tree:pop()
                local next_detour_index = deviation.detour_index + 1
                local detour_list = deviation.detour_node_pre.detour
                if next_detour_index <= #detour_list then -- if has next sibling
                    local next_detour_node = detour_list[next_detour_index]
                    local delta = next_detour_node.delta
                    local parent = deviation.parent
                    deviations_tree:put({
                        parent = parent,
                        detour_node_pre = deviation.detour_node_pre,
                        detour_node_pre_index = deviation.detour_node_pre_index,
                        detour_node = detour_list[next_detour_index],
                        detour_index = next_detour_index,
                        delta = delta
                    }, parent.delta + delta)
                end
                -- child deviation
                local cur_detour_pre = deviation.detour_node.node
                local detour_pre = cur_detour_pre
                local min_delta = math.huge
                local cur_detour_node_pre_index = deviation.detour_node_pre_index + 1
                local detour_node_pre_index = cur_detour_node_pre_index
                -- find next min delta
                while cur_detour_pre.type ~= "eos" do
                    local detour_list = cur_detour_pre.detour
                    if #detour_list > 1 then
                        if detour_list[2].delta < min_delta then
                            min_delta = detour_list[2].delta
                            detour_pre = cur_detour_pre
                            detour_node_pre_index = cur_detour_node_pre_index
                        end
                    end
                    cur_detour_pre = Module._next_node(cur_detour_pre)
                    cur_detour_node_pre_index = cur_detour_node_pre_index + 1
                end
                -- TODO: should traverse all children
                if min_delta < math.huge then
                    local detour_node = detour_pre.detour[2]
                    deviations_tree:put({
                        parent = deviation,
                        detour_node_pre = detour_pre,
                        detour_node_pre_index = detour_node_pre_index,
                        detour_node = detour_node,
                        detour_index = 2,
                        delta = min_delta
                    }, deviation.delta + min_delta)
                end
                phase = 2 -- back to phase 2 to return
            end
        end
    end
end

function Module.clear()
    Module.lattice = {}
    Module.lookup_cache = {}
    Module.surface = ""
end

function Module.init(env)
    Module.kagiroi_dict.load()
    if env.allow_table_word_in_sentence then
        Module.kagiroi_dict.set_table_word_cost(env.table_word_cost)
    end
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