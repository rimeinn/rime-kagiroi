-- kagiroi_viterbi.lua
-- maintain a lattice for viterbi algorithm
-- to offer contextual candidates.
-- license: GPLv3
-- version: 0.2.1
-- author: kuroame
local kagiroi = require("kagiroi/kagiroi")
local segmentor = require("kagiroi/segmenter")
local PriorityQueue = require("kagiroi/priority_queue")
local lru = require("kagiroi/lru")
local Module = {
    kagiroi_dict = require("kagiroi/kagiroi_dict"),
    hira2kata_opencc = Opencc("kagiroi_h2k.json"),
    lattice = {}, -- lattice for viterbi algorithm
    max_word_length = 100,
    start_index_by_col = {},
    detour_by_end_pos = {},
    search_beam_width = 50,
    lookup_cache = nil,
    lookup_cache_size = 50000,
    bos = nil,
    eos = nil,
    matrix_cache = nil,
    matrix_cache_size = 1000,
    surface = "",
    surface_len = 0
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
    o.pre_index_col = 0 -- next node column
    o.pre_index_row = 0 -- next node row
    o.left_id = left_id -- left id of the node, from lex
    o.right_id = right_id -- right id of the node, from lex
    o.cost = cost -- cost of the node, should = prev.cost + matrix(prev.left_id, right_id) + wcost(from lex)
    o.surface = surface -- surface of the node, from lex
    o.candidate = candidate -- candidate of the node, from lex
    o.type = type -- type of the node: dummy, lex, bos(begin of sentence), eos(end of sentence)
    o.start = -1 -- start pos
    o._end = -1 -- end pos
    o.wcost = 0 -- word cost
    o.detour = {}
    o.r_detour = {}
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
    local cache = Module.lookup_cache
    local cached_results = cache:get(surface)
    if cached_results then
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
    cache:set(surface, results)
    local index = 0
    return function()
        index = index + 1
        return results[index]
    end
end

-- get the connection cost between two nodes
-- @param right_id int
-- @param left_id int
-- @return float
function Module._get_matrix_cost(right_id, left_id)
    local key = right_id .. ":" .. left_id
    local cache = Module.matrix_cache

    local cache_set = cache:get(right_id)
    if cache_set then
        local cached_cost = cache_set[left_id]
        if cached_cost then
            return cached_cost
        end
    else
        cache_set = {}
    end
    local cost = Module.kagiroi_dict.query_matrix(right_id, left_id)
    cache_set[left_id] = cost
    cache:set(right_id, cache_set)
    return cost
end

function Module._get_prefix_penalty(next_id)
    return Module._get_matrix_cost(-10, next_id)
end

function Module._get_suffix_penalty(prev_id)
    return Module._get_matrix_cost(prev_id, -20)
end

-- get the previous node of the node
-- @param node Node
-- @return Node
function Module._pre_node(node)
    return Module.lattice[node.pre_index_col][node.pre_index_row]
end

function Module._find_nodes_starting_at(i)
    local result = {}
    for j = i, Module.surface_len do
        if not Module.start_index_by_col[j] then
            goto continue
        end
        local nodes_at_ij = Module.start_index_by_col[j][i]
        if not nodes_at_ij then
            goto continue
        end
        for _, node in ipairs(nodes_at_ij) do
            table.insert(result, node)
        end
        ::continue::
    end
    return result
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

function Module._init_lattice()
    Module.lattice[0] = {}
    -- set the bos/eos node
    local eos = Node:new(0, 0, 0, "", "", "eos")
    local bos = Node:new(0, 0, 0, "", "", "bos")
    bos.start = 0
    bos._end = 0
    eos.start = Module.surface_len + 1
    eos._end = Module.surface_len + 1
    Module.lattice[0][1] = bos
    Module.bos = bos
    Module.eos = eos
end

function Module._build_detour(node)
    node.detour = {}
    local pre_nodes = Module.lattice[node.start - 1]
    for row, pnode in ipairs(pre_nodes) do
        local conn_cost = Module._get_matrix_cost(pnode.right_id, node.left_id)
        local delta = pnode.cost + conn_cost -- current path cost
        - (node.cost - node.wcost) -- best path cost
        if node.type == "eos" then
            delta = delta + Module._get_suffix_penalty(pnode.right_id)
        end
        -- log.info(" added detour for " .. node.type .." ("..node.candidate.."): ".. pnode.candidate)
        table.insert(node.detour, {
            delta = delta,
            node = pnode
        })
        table.insert(Module.detour_by_end_pos[node._end], {
            from = pnode,
            to = node,
            conn_cost = conn_cost
        })
    end
    table.sort(node.detour, function(a, b)
        return a.delta < b.delta
    end)
end

function Module._conn_eos()
    local eos = Module.eos
    eos.start = Module.surface_len + 1
    eos._end = Module.surface_len + 1
    local min_calculated_cost = math.huge
    local min_index_row = 1
    for i, node_a in ipairs(Module.lattice[Module.surface_len]) do
        local current_cost_a = node_a.cost + Module._get_matrix_cost(node_a.right_id, eos.left_id) +
                                   Module._get_suffix_penalty(node_a.right_id)
        if current_cost_a < min_calculated_cost then
            min_calculated_cost = current_cost_a
            min_index_row = i
        end
    end
    eos.cost = min_calculated_cost
    eos.pre_index_row = min_index_row
    eos.pre_index_col = Module.surface_len
    Module.detour_by_end_pos[eos._end] = {}
    Module._build_detour(eos)
end

function Module._extend_to(j)
    Module.lattice[j] = {}
    Module.start_index_by_col[j] = {}
    local input = Module.surface
    for i = 1, j do
        local pre_index_col = i - 1
        local open_nodes = Module.lattice[pre_index_col]
        if #open_nodes == 0 then
            goto continue
        end
        local surface = kagiroi.utf8_sub(input, i, j)
        local iter = Module._lookup(surface)
        if iter then
            for lex in iter do
                local node = Node:new_from_lex(lex)
                node.pre_index_col = pre_index_col
                node.cost = math.huge
                node.wcost = lex.cost
                -- evaluate open nodes
                -- k: row index of the open node
                for k, open_node in ipairs(open_nodes) do
                    local cost_without_matrix = open_node.cost + node.wcost
                    if cost_without_matrix > node.cost then
                        break
                    end
                    local cost_with_matrix = cost_without_matrix +
                                                 Module._get_matrix_cost(open_node.right_id, node.left_id)
                    if open_node.type == "bos" then
                        cost_with_matrix = cost_with_matrix + Module._get_prefix_penalty(node.left_id)
                    end
                    if cost_with_matrix < node.cost then
                        node.cost = cost_with_matrix
                        node.pre_index_row = k
                    end
                end
                node.start = i
                node._end = j
                kagiroi.insert_sorted(Module.lattice[j], node, function(a, b)
                    return a.cost < b.cost
                end)
                if #Module.lattice[j] > Module.search_beam_width then
                    table.remove(Module.lattice[j])
                end
            end
        end
        ::continue::
    end
    Module.detour_by_end_pos[j] = {}
    for _, node in ipairs(Module.lattice[j]) do
        local i = node.start
        if not Module.start_index_by_col[j] then
            Module.start_index_by_col[j] = {}
        end
        if not Module.start_index_by_col[j][i] then
            Module.start_index_by_col[j][i] = {}
        end
        table.insert(Module.start_index_by_col[j][i], node)
        Module._build_detour(node)
    end
end

function Module._build_lattice()
    Module._init_lattice()
    for j = 1, Module.surface_len do
        Module._extend_to(j)
    end
end

-- materialize the deviation as table of lex and cost
function Module._materialize(deviation)
    if deviation._materialized then
        return deviation._materialized
    end
    local eos_node = Module.eos
    if deviation.is_root then
        local lex_table = {}
        local cur_node = eos_node
        while cur_node.type ~= "bos" do
            table.insert(lex_table, cur_node)
            cur_node = Module._pre_node(cur_node)
        end
        deviation._materialized = {
            lex_table = lex_table,
            cost = eos_node.cost,
        }
        return deviation._materialized
    end
    local parent_materialized = Module._materialize(deviation.parent)
    local parent_lex_table = parent_materialized.lex_table
    local lex_table = {}
    local found_detour_point = false
    for _, node_from_parent in ipairs(parent_lex_table) do
        if node_from_parent == deviation.detour_node_next then
            found_detour_point = true
            -- log.info("detour from "..deviation.detour_node_next.type .. " " .. deviation.detour_node_next.candidate)
            table.insert(lex_table, node_from_parent)
            break
        end
        table.insert(lex_table, node_from_parent)
    end
    local cur_node = deviation.detour_node.node
    -- log.info("to " .. cur_node.candidate)
    while cur_node and cur_node.type ~= "bos" do
        table.insert(lex_table, cur_node)
        cur_node = Module._pre_node(cur_node)
    end
    deviation._materialized = {
        lex_table = lex_table,
        cost = parent_materialized.cost + deviation.delta,
    }
    return deviation._materialized
end

function Module._materialize_state(result_state)
    local lex_table = {Module.eos} -- compatible with _assemble, which assumes eos is at 1
    local surface_list = {}
    local current_state = result_state
    
    -- Backtrack from the final state to BOS
    while current_state and current_state.node and current_state.node.type ~= "bos" do
        table.insert(lex_table,  current_state.node)
        current_state = current_state.parent_state
    end
    
    return {
        lex_table = lex_table,
        cost = result_state.cost
    }
end

-- assemble the lex and cost
function Module._assemble(materialized)
    local lex_table = materialized.lex_table
    local candidate = ""
    local surface = ""
    for _, node in ipairs(lex_table) do
        candidate = node.candidate .. candidate
        surface = node.surface .. surface
    end
    
    local assem = {
        surface = surface,
        candidate = candidate,
        cost = materialized.cost,
        left_id = lex_table[#lex_table].left_id,
        right_id = lex_table[2].right_id,-- eos is at 1
    }
    local debug_func = function()
        local path_str_parts = {}
        local total_cost_check = 0
        local total_cost = assem.cost

        if #lex_table > 1 then
            local eos_node = Module.eos
            local bos_node = Module.bos
            local first_node = lex_table[#lex_table]
            local last_node = lex_table[2]

            local eos_conn_cost = Module._get_matrix_cost(last_node.right_id, eos_node.left_id)
            local bos_conn_cost = Module._get_matrix_cost(bos_node.right_id, first_node.left_id)
            local suffix_penalty = Module._get_suffix_penalty(last_node.right_id)
            local prefix_penalty = Module._get_prefix_penalty(first_node.left_id)

            table.insert(path_str_parts, "BOS")
            table.insert(path_str_parts, string.format("conn(%.0f)+pre(%.0f)", bos_conn_cost, prefix_penalty))
            table.insert(path_str_parts,
                string.format("%s[%s](l:%d,r:%d,w:%.0f)", first_node.candidate, first_node.surface, first_node.left_id,
                    first_node.right_id, first_node.wcost))

            total_cost_check = total_cost_check + bos_conn_cost + prefix_penalty + suffix_penalty + first_node.wcost

            for i = #lex_table - 1, 2, -1 do
                local current_node = lex_table[i]
                local prev_node = lex_table[i + 1]
                local connection_cost = Module._get_matrix_cost(prev_node.right_id, current_node.left_id)
                total_cost_check = total_cost_check + connection_cost + current_node.wcost
                table.insert(path_str_parts, string.format("conn(%.0f)", connection_cost))
                table.insert(path_str_parts,
                    string.format("%s[%s](l:%d,r:%d,w:%.0f)", current_node.candidate, current_node.surface,
                        current_node.left_id, current_node.right_id, current_node.wcost))
            end
            table.insert(path_str_parts, string.format("suf(%.0f)", suffix_penalty))
        end

        log.info(string.format("total: %.0f (check: %.0f)\t| conv.: %s\t| path: %s", total_cost, total_cost_check,
            assem.candidate, table.concat(path_str_parts, " -> ")))
    end
    debug_func()
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
    if input == Module.surface then
        Module.need_update = false
        return
    end
    Module.need_update = true
    -- log.info("anl. " .. input)
    local prefix = kagiroi.utf8_common_prefix(input, Module.surface)
    -- log.info("pref." .. prefix)
    local prefix_len = utf8.len(prefix)
    local old_len = Module.surface_len
    Module.surface = input
    Module.surface_len = utf8.len(input)

    if prefix_len == 0 then
        Module._build_lattice()
    else
        -- truncate
        if prefix_len < old_len then
            for j = prefix_len + 1, old_len do
                Module.lattice[j] = nil
                Module.start_index_by_col[j] = nil
                Module.detour_by_end_pos[j] = nil
            end
        end
        -- extend
        for j = prefix_len + 1, Module.surface_len do
            Module._extend_to(j)
        end
    end
    Module._conn_eos()
end

-- generate the nbest list for the prefix
-- @return iterator of nbest prefixes
function Module.best_n_prefix()
    local pq = PriorityQueue()
    local initial_path_state = {
        type = "PATH",
        node = Module.bos,
        parent_state = nil,
        g_cost = 0,
        segment = 0
    }
    pq:put(initial_path_state, 0)
    return Module._weave_dummy_iter(function()
        while true do
            local state = pq:pop()
            if state == nil then
                return nil
            end
            if state.type == "RESULT" then
                return Module._assemble(Module._materialize_state(state))
            end
            local current_path_state = state
            local node = state.node
            local next_pos = node._end + 1
            local successor_nodes = Module._find_nodes_starting_at(next_pos)
            for _, successor_node in ipairs(successor_nodes) do
                local g_cost_to_next = current_path_state.g_cost +
                                           Module._get_matrix_cost(node.right_id, successor_node.left_id) +
                                           successor_node.wcost
                if node.type == "bos" then
                    g_cost_to_next = g_cost_to_next + Module._get_prefix_penalty(successor_node.left_id)
                end
                local extended_path = {
                    type = "PATH",
                    node = successor_node,
                    parent_state = current_path_state,
                    cost = current_path_state.g_cost, -- cost of path
                    segment = current_path_state.segment + 1
                }
                if segmentor.is_boundary_internal(node.right_id, successor_node.left_id) and node.type ~= "bos" then
                    extended_path.segment = current_path_state.segment + 1
                    pq:put({
                        type = "RESULT",
                        node = node,
                        parent_state = current_path_state.parent_state,
                        cost = g_cost_to_next,
                        segment = current_path_state.segment + 1
                    }, g_cost_to_next)
                end
                pq:put({
                    type = "PATH",
                    node = successor_node,
                    parent_state = current_path_state,
                    g_cost = g_cost_to_next,
                    segment = current_path_state.segment
                }, g_cost_to_next)
            end
        end
    end)
end

-- generate nbest candidate for the input
-- @return iterator of nbest sentences
function Module.best_n()
    if not Module._pre_node(Module.eos) then
        return function()
            return nil
        end
    end
    local deviations_tree = PriorityQueue()
    local phase = 0
    local root = {
        is_root = true,
        eos = Module.eos,
        detour_node = {
            node = Module.eos
        },
        delta = 0,
    }
    local seen_candidate = {}
    local children_deviate = function(parent)
        local cur_node = parent.detour_node.node
        while cur_node.type ~= "bos" do
            local detour_list = cur_node.detour
            if #detour_list > 1 then
                local best_detour = detour_list[2] -- 1 is the best path
                local delta = best_detour.delta
                deviations_tree:put({
                    parent = parent,
                    detour_node_next = cur_node, -- next node of detour node
                    detour_node = best_detour, -- detour node 
                    detour_index = 2, -- index of detour node to find detour node in O(1)
                    delta = delta -- delta value of this detour
                }, parent.delta + delta)
            end
            cur_node = Module._pre_node(cur_node)
        end
    end
    local sibling_deviate = function(brother)
        local next_detour_index = brother.detour_index + 1
        local detour_list = brother.detour_node_next.detour
        if next_detour_index <= #detour_list then -- if has next sibling
            local next_detour_node = detour_list[next_detour_index]
            local delta = next_detour_node.delta
            local parent = brother.parent
            deviations_tree:put({
                parent = parent,
                detour_node_next = brother.detour_node_next,
                detour_node = next_detour_node,
                detour_index = next_detour_index,
                delta = delta
            }, parent.delta + delta)
        end
    end
    local node_to_return = root
    local next_node = nil
    children_deviate(root)
    return function()
        while true do
            if next_node then
                sibling_deviate(next_node)
                children_deviate(next_node)
                node_to_return = next_node
                next_node = nil
            elseif node_to_return then
                local assembled = Module._assemble(Module._materialize(node_to_return))
                next_node = deviations_tree:pop()
                if not next_node then
                    node_to_return = nil
                end
                if seen_candidate[assembled.candidate] == nil then
                    seen_candidate[assembled.candidate] = 1
                    return assembled
                end
            else
                return nil
            end
        end
    end
end

function Module.clear()
    Module.lattice = {}
    Module.surface = ""
    Module.bos = nil
    if Module.lookup_cache_size > 0 then
        Module.lookup_cache = lru.new(Module.lookup_cache_size)
    end
    if Module.matrix_cache_size > 0 then
        Module.matrix_cache = lru.new(Module.matrix_cache_size)
    end
end

function Module.init(env)
    Module.kagiroi_dict.load()
    if env.allow_table_word_in_sentence then
        Module.kagiroi_dict.set_table_word_cost(env.table_word_cost)
    end

    Module.query_userdict = function(surface)
        return nil
    end
    Module.clear()
end

function Module.fini()
    Module.clear()
    Module.kagiroi_dict.release()
end

return Module