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
}
local youon = {"ぁ", "ぃ", "ぅ", "ぇ", "ぉ", "ゃ", "ゅ", "ょ"}

local function start_with_youon(str)
    local initial = kagiroi.utf8_sub(str, 1, 1)
    for _, char in ipairs(youon) do
        if initial == char then
            return true
        end
    end
    return false
end

local function calculate_userdict_cost(surface, commit_count)
    local base_cost = 5000
    local length_penalty = math.max(1, 2.0 - utf8.len(surface) * 0.3)
    local frequency_bonus = math.log(commit_count + 2) / math.log(2)

    local cost = math.max(500, base_cost * length_penalty / frequency_bonus)
    return math.floor(cost)
end

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
    o.rcost = math.huge
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
function Module:_lookup(surface)
    local cache = self.lookup_cache
    local cached_results = cache:get(surface)
    if cached_results then
        local index = 0
        return function()
            index = index + 1
            return cached_results[index]
        end
    end
    local lex_iter = self.query_dict(surface)
    local userdict_iter = self.query_userdict(surface)
    local merged_iter = self:_merge_iter(lex_iter, userdict_iter)

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
function Module:_get_matrix_cost(right_id, left_id)
    local cache = self.matrix_cache
    local cache_set = cache:get(right_id)
    if cache_set then
        local cached_cost = cache_set[left_id]
        if cached_cost then
            return cached_cost
        end
    else
        cache_set = {}
    end
    local cost = self.query_matrix(right_id, left_id)
    cache_set[left_id] = cost
    cache:set(right_id, cache_set)
    return cost
end

function Module:_get_prefix_penalty(next_id)
    return self:_get_matrix_cost(-10, next_id)
end

function Module:_get_suffix_penalty(prev_id)
    return self:_get_matrix_cost(prev_id, -20)
end

-- get the previous node of the node
-- @param node Node
-- @return Node
function Module:_pre_node(node)
    return self.lattice[node.pre_index_col][node.pre_index_row]
end

function Module:_find_nodes_starting_at(i)
    local result = {}
    for j = i, self.surface_len do
        if not self.start_index_by_col[j] then
            goto continue
        end
        local nodes_at_ij = self.start_index_by_col[j][i]
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
function Module:_merge_iter(iter1, iter2)
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

function Module:_init_lattice()
    -- set the bos/eos node
    local eos = Node:new(0, 0, 0, "", "", "eos")
    local bos = Node:new(0, 0, 0, "", "", "bos")
    bos.start = 0
    bos._end = 0
    eos.start = self.surface_len + 1
    eos._end = self.surface_len + 1
    self.lattice[0] = {}
    self.lattice[eos._end] = {}
    self.lattice[0][1] = bos
    self.lattice[eos._end][1] = eos
    self.bos = bos
    self.eos = eos
end

function Module:_build_detour(node)
    node.detour = {}
    local pre_nodes = self.lattice[node.start - 1]
    for row, pnode in ipairs(pre_nodes) do
        local conn_cost = self:_get_matrix_cost(pnode.right_id, node.left_id)
        local delta = pnode.cost + conn_cost -- current path cost
        - (node.cost - node.wcost) -- best path cost
        if node.type == "eos" then
            delta = delta + self:_get_suffix_penalty(pnode.right_id)
        end
        -- log.info(" added detour for " .. node.type .." ("..node.candidate.."): ".. pnode.candidate)
        table.insert(node.detour, {
            delta = delta,
            node = pnode
        })
    end
    table.sort(node.detour, function(a, b)
        return a.delta < b.delta
    end)
end

function Module:_build_reverse_detour()
    self.eos.rcost = 0
    local max_width = math.min(20, self.surface_len)
    for j = max_width, 0, -1 do
        for _, node in ipairs(self.lattice[j] or {}) do
            local successors = {}
            if j == max_width then
                table.insert(successors, self.eos)
            else
                successors = self:_find_nodes_starting_at(node._end + 1)
            end
            local best_successor = nil
            node.rcost = math.huge
            local second_best_cost = node.rcost
            for _, succ_node in ipairs(successors) do
                local new_rcost = node.wcost + self:_get_matrix_cost(node.right_id, succ_node.left_id) +
                                      succ_node.rcost
                if succ_node.type == "eos" then
                    new_rcost = new_rcost + self:_get_suffix_penalty(node.right_id)
                end
                if new_rcost < node.rcost then
                    second_best_cost = node.rcost
                    node.rcost = new_rcost
                    best_successor = succ_node
                elseif new_rcost < second_best_cost then
                    second_best_cost = new_rcost
                end
            end
            node.rdelta = second_best_cost - node.rcost
            node.rsucc = best_successor
        end
    end
end

function Module:_conn_eos()
    local eos = self.eos
    eos.start = self.surface_len + 1
    eos._end = self.surface_len + 1
    local min_calculated_cost = math.huge
    local min_index_row = 1
    for i, node_a in ipairs(self.lattice[self.surface_len]) do
        local current_cost_a = node_a.cost + self:_get_matrix_cost(node_a.right_id, eos.left_id) +
                                   self:_get_suffix_penalty(node_a.right_id)
        if current_cost_a < min_calculated_cost then
            min_calculated_cost = current_cost_a
            min_index_row = i
        end
    end
    eos.cost = min_calculated_cost
    eos.pre_index_row = min_index_row
    eos.pre_index_col = self.surface_len
    self:_build_detour(eos)
end

function Module:_extend_to(j)
    self.lattice[j] = {}
    self.start_index_by_col[j] = {}
    local input = self.surface
    for i = 1, j do
        local pre_index_col = i - 1
        local open_nodes = self.lattice[pre_index_col]
        if #open_nodes == 0 then
            goto continue
        end
        local surface = kagiroi.utf8_sub(input, i, j)
        local iter = self:_lookup(surface)
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
                                                 self:_get_matrix_cost(open_node.right_id, node.left_id)
                    if open_node.type == "bos" then
                        cost_with_matrix = cost_with_matrix + self:_get_prefix_penalty(node.left_id)
                    end
                    if cost_with_matrix < node.cost then
                        node.cost = cost_with_matrix
                        node.pre_index_row = k
                    end
                end
                node.start = i
                node._end = j
                kagiroi.insert_sorted(self.lattice[j], node, function(a, b)
                    return a.cost < b.cost
                end)
                if #self.lattice[j] > self.search_beam_width then
                    table.remove(self.lattice[j])
                end
            end
        end
        ::continue::
    end
    for _, node in ipairs(self.lattice[j]) do
        local i = node.start
        if not self.start_index_by_col[j] then
            self.start_index_by_col[j] = {}
        end
        if not self.start_index_by_col[j][i] then
            self.start_index_by_col[j][i] = {}
        end
        table.insert(self.start_index_by_col[j][i], node)
        self:_build_detour(node)
    end
end

function Module:_build_lattice()
    self:_init_lattice()
    for j = 1, self.surface_len do
        self:_extend_to(j)
    end
end

-- materialize the deviation as table of lex and cost
function Module:_materialize(deviation)
    if deviation._materialized then
        return deviation._materialized
    end
    local eos_node = self.eos
    if deviation.is_root then
        local lex_table = {}
        local cur_node = eos_node
        while cur_node.type ~= "bos" do
            table.insert(lex_table, cur_node)
            cur_node = self:_pre_node(cur_node)
        end
        deviation._materialized = {
            lex_table = lex_table,
            cost = eos_node.cost
        }
        return deviation._materialized
    end
    local parent_materialized = self:_materialize(deviation.parent)
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
        cur_node = self:_pre_node(cur_node)
    end
    deviation._materialized = {
        lex_table = lex_table,
        cost = parent_materialized.cost + deviation.delta
    }
    return deviation._materialized
end

-- assemble the lex and cost
function Module:_assemble(materialized)
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
        right_id = lex_table[2].right_id -- eos is at 1
    }
    local debug_func = function()
        local path_str_parts = {}
        local total_cost_check = 0
        local total_cost = assem.cost

        if #lex_table > 1 then
            local eos_node = self.eos
            local bos_node = self.bos
            local first_node = lex_table[#lex_table]
            local last_node = lex_table[2]

            local eos_conn_cost = self:_get_matrix_cost(last_node.right_id, eos_node.left_id)
            local bos_conn_cost = self:_get_matrix_cost(bos_node.right_id, first_node.left_id)
            local suffix_penalty = self:_get_suffix_penalty(last_node.right_id)
            local prefix_penalty = self:_get_prefix_penalty(first_node.left_id)

            table.insert(path_str_parts, "BOS")
            table.insert(path_str_parts, string.format("conn(%.0f)+pre(%.0f)", bos_conn_cost, prefix_penalty))
            table.insert(path_str_parts,
                string.format("%s[%s](l:%d,r:%d,w:%.0f)", first_node.candidate, first_node.surface, first_node.left_id,
                    first_node.right_id, first_node.wcost))

            total_cost_check = total_cost_check + bos_conn_cost + prefix_penalty + suffix_penalty + first_node.wcost

            for i = #lex_table - 1, 2, -1 do
                local current_node = lex_table[i]
                local prev_node = lex_table[i + 1]
                local connection_cost = self:_get_matrix_cost(prev_node.right_id, current_node.left_id)
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
    -- debug_func()
    return assem
end

function Module:_weave_dummy_iter(smart_iter)
    local current_dummy_index = 1
    local high_quality_count = 7
    local high_quality_cost = 46040
    local dummy_cost = high_quality_cost + 1
    local surface = {}
    local max_dummy_surface_len = 4
    local next_node_cost = 0
    local dummy_node_iter = function()
        if current_dummy_index > #surface then
            return nil
        end
        local dummy_node = Node:new(1920, 1920, dummy_cost, surface[current_dummy_index][1], surface[current_dummy_index][2],
            "dummy")
        current_dummy_index = current_dummy_index + 1
        return dummy_node
    end

    if #self.lattice[1] == 0 then
        table.insert(surface, {self.surface, self.surface})
        table.insert(surface, {self.surface, self.hira2kata_opencc():convert(self.surface)})
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
                        {cur_smart_node.surface, self.hira2kata_opencc():convert(cur_smart_node.surface)})
                end
                dummy_cost = cur_smart_node.cost + 1
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
function Module:analyze(input)
    if input == self.surface then
        self.need_update = false
        return
    end
    self.need_update = true
    -- log.info("anl. " .. input)
    local prefix = kagiroi.utf8_common_prefix(input, self.surface)
    -- log.info("pref." .. prefix)
    local prefix_len = utf8.len(prefix)
    local old_len = self.surface_len
    self.surface = input
    self.surface_len = utf8.len(input)

    if prefix_len == 0 then
        self:_build_lattice()
    else
        -- truncate
        if prefix_len < old_len then
            for j = prefix_len + 1, old_len do
                self.lattice[j] = nil
                self.start_index_by_col[j] = nil
            end
        end
        -- extend
        for j = prefix_len + 1, self.surface_len do
            self:_extend_to(j)
        end
    end
    self:_conn_eos()
end

-- generate the nbest list for the prefix
-- @return iterator of nbest prefixes
function Module:best_n_prefix()
    self:_build_reverse_detour()
    local sect_nodes = self:_find_nodes_starting_at(1)
    local collector = PriorityQueue()
    -- find min rcost + pref + conn
    local min_cost = math.huge
    for _, sect_node in ipairs(sect_nodes) do
        local new_cost = sect_node.rcost + self:_get_prefix_penalty(sect_node.left_id) +
                             self:_get_matrix_cost(self.bos.right_id, sect_node.left_id)
        if new_cost < min_cost then
            min_cost = new_cost
        end
    end

    for _, sect_node in ipairs(sect_nodes) do
        local sect_delta = sect_node.rcost + self:_get_prefix_penalty(sect_node.left_id) +
                               self:_get_matrix_cost(self.bos.right_id, sect_node.left_id) - min_cost
        local cur_node = sect_node
        local next_node = sect_node.rsucc
        while next_node do
            if segmentor.is_boundary_internal(cur_node.right_id, next_node.left_id) then
                collector:put({
                    node = cur_node,
                    sect_node = sect_node,
                    delta = sect_delta
                }, sect_delta)
                break
            else
                if cur_node.rdelta < math.huge then
                    local delta = cur_node.rdelta + sect_delta
                    collector:put({
                        node = cur_node,
                        sect_node = sect_node,
                        delta = delta -- detour cost
                    }, delta)
                end
            end
            cur_node = next_node
            next_node = cur_node.rsucc
        end
    end
    return self:_weave_dummy_iter(function()
        local deviation = collector:pop()
        if not deviation then
            return nil
        end
        local cur_node = deviation.sect_node
        local cost = deviation.delta + min_cost
        local lex_table = {}
        while true do
            -- keep it reverse to compatible with _assemble
            table.insert(lex_table, 1, cur_node)
            if cur_node == deviation.node then
                break
            end
            local next_node = cur_node.rsucc
            if next_node then
                cur_node = next_node
            else
                break
            end
        end
        table.insert(lex_table, 1, self.eos)
        -- log.info("assem. prefix")
        return self:_assemble({
            lex_table = lex_table,
            cost = cost
        })
    end)
end

-- generate nbest candidate for the input
-- @return iterator of nbest sentences
function Module:best_n()
    if not self:_pre_node(self.eos) then
        return function()
            return nil
        end
    end
    local deviations_tree = PriorityQueue()
    local root = {
        is_root = true,
        eos = self.eos,
        detour_node = {
            node = self.eos
        },
        delta = 0
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
            cur_node = self:_pre_node(cur_node)
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
                local assembled = self:_assemble(self:_materialize(node_to_return))
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

function Module:clear()
    self.lattice = {}
    self.surface = ""
    self.bos = nil
    if self.lookup_cache_size > 0 then
        self.lookup_cache = lru.new(self.lookup_cache_size)
    end
    if self.matrix_cache_size > 0 then
        self.matrix_cache = lru.new(self.matrix_cache_size)
    end
end

function Module.new(env)
    local o = {
        hira2kata_opencc = kagiroi.Thunk(function()
            return Opencc("kagiroi_h2k.json")
        end),
        lattice = {}, -- lattice for viterbi algorithm
        start_index_by_col = {},
        search_beam_width = 50,
        lookup_cache = nil,
        lookup_cache_size = 50000,
        bos = nil,
        eos = nil,
        matrix_cache = nil,
        matrix_cache_size = 1000,
        surface = "",
        surface_len = 0,
        query_userdict = function(input)
            if not input or input == "" or start_with_youon(input) then
                return function()
                    return nil
                end
            end
            env.mem:user_lookup(input .. " \t", true)
            local next_func, self = env.mem:iter_user()
            return function()
                local entry = next_func(self)
                if not entry then
                    return nil
                end
                local candidate, left_id, right_id = string.match(entry.text, "(.+)|(-?%d+) (-?%d+)")
                local surface = kagiroi.trim_trailing_space(entry.custom_code)
                if candidate and left_id and right_id then
                    return {
                        surface = surface,
                        left_id = tonumber(left_id),
                        right_id = tonumber(right_id),
                        candidate = candidate,
                        cost = calculate_userdict_cost(surface, entry.commit_count)
                    }
                else
                    return {
                        surface = surface,
                        left_id = -1,
                        right_id = -1,
                        candidate = entry.text,
                        cost = 50 / (entry.commit_count + 1)
                    }
                end
            end
        end,
        query_dict = function(input)
            if not input or input == "" or start_with_youon(input) then
                return function()
                    return nil
                end
            end
            env.mem:dict_lookup(input, false, 999999)
            local next_func, self = env.mem:iter_dict()
            return function()
                while true do
                    local entry = next_func(self)
                    if not entry then
                        return nil
                    end
                    local candidate, left_id, right_id = string.match(entry.text, "(.+)|(-?%d+) (-?%d+)")
                    if candidate and left_id and right_id then
                        return {
                            surface = input,
                            left_id = tonumber(left_id),
                            right_id = tonumber(right_id),
                            candidate = candidate,
                            cost = math.floor(100000000 * math.exp(entry.weight) + 0.5)
                        }
                    end
                end
    
            end
        end,
        query_matrix = function(prev_id, next_id)
            local res = env.matrix_lookup():lookup(prev_id .. " " .. next_id)
            if not res or res == "" then
                return math.huge
            end
            local last_part = string.match(res, "%S+$")
            return tonumber(last_part) or math.huge
        end
    }
    setmetatable(o, {__index = Module})
    o:clear()
    return o
end

return Module
