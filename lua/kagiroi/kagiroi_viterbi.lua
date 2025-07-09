-- kagiroi_viterbi.lua
-- maintain a lattice for viterbi algorithm
-- to offer contextual candidates.

-- license: GPLv3
-- version: 0.2.0
-- author: kuroame

local kagiroi = require("kagiroi/kagiroi")
local Module = {
    kagiroi_dict = require("kagiroi/kagiroi_dict"),
    lattice = {}, -- lattice for viterbi algorithm
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
    local lex_iter = Module.kagiroi_dict.query_lex(surface, false)
    local userdict_iter = Module.query_userdict(surface)
    return Module._merge_iter(lex_iter, userdict_iter)
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
    local input_len_utf8 = utf8.len(input)
    
    -- initialize lattice columns as empty tables
    for i = 1, input_len_utf8 + 1 do
        Module.lattice[i] = {}
    end
    
    -- set the eos nodes
    local eos = Node:new(0, 0, 0, "", "", "eos")
    Module.lattice[input_len_utf8 + 1][1] = eos
    -- mark if the column has any nodes
    local valid_col = 1 << input_len_utf8
    -- i: start position of the surface
    -- j: end position of the surface
    for j = input_len_utf8, 1, -1 do
        -- search nodes that end at j

        -- check if there are any nodes that start at j + 1
        -- if not, nodes end at j cannot be connected to this lattice
        -- so we can skip this iteration
        if valid_col & (1 << j) == 0 then
            goto continue
        end
        for i = 1, j do
            local surface = kagiroi.utf8_sub(input, i, j)
            local iter = Module._lookup(surface)
            if iter then
                for lex in iter do
                    -- mark this column as valid, so that we can search nodes that end at i-1 in the next iteration
                    valid_col = valid_col | (1 << i - 1)
                    local node = Node:new_from_lex(lex)
                    table.insert(Module.lattice[i], node)
                    -- try to connect to the best node that start at j + 1
                    node.prev_index_col = j + 1
                    local open_nodes = Module.lattice[node.prev_index_col]
                    -- evaluate open nodes
                    node.cost = math.huge
                    -- k: row index of the open node
                    for k, open_node in ipairs(open_nodes) do
                        local cost = open_node.cost +
                            Module.kagiroi_dict.query_matrix(lex.right_id, open_node.left_id) +
                            lex.cost
                        if cost < node.cost then
                            node.cost = cost
                            node.prev_index_row = k
                        end
                    end
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

-- generate best candidate for the input
-- @return iterator of nbest list
function Module.best()
    local best_node = Module.lattice[1][1]
    if not best_node then
        return {
            surface = "",
            candidate = "",
            cost = math.huge,
            left_id = 0,
            right_id = 0
        }
    end
    local candidate = ""
    local surface = ""
    local left_id = best_node.left_id
    local right_id = best_node.right_id
    local cur_node = best_node
    while cur_node and cur_node.type ~= "eos" do
        candidate = candidate .. cur_node.candidate
        surface = surface .. cur_node.surface
        left_id = cur_node.left_id
        cur_node = Module._pre_node(cur_node)
        right_id = cur_node.right_id
    end
    return {
        surface = surface,
        candidate = candidate,
        cost = best_node.cost,
        left_id = left_id,
        right_id = right_id
    }
end

-- generate the nbest list for the prefix
-- @return iterator of nbest list
function Module.best_n_prefix()
    local current_index = 1
    local current_dummy_index = 1
    local high_quality_count = 7
    local high_quality_cost = 46040
    local is_dummy_node_emitted = false
    local surface = {}
    local max_dummy_surface_len = 4
    return function()
        while current_index <= #Module.lattice[1] do
            local best_n_node = Module.lattice[1][current_index]
            if (utf8.len(best_n_node.surface) < max_dummy_surface_len) then
                table.insert(surface, best_n_node.surface)
                table.insert(surface, Module.hira2kata_opencc:convert(best_n_node.surface))
            end
            if not is_dummy_node_emitted and ((best_n_node.cost >= high_quality_cost or high_quality_count <= 0) or current_index >= #Module.lattice[1]) then
                is_dummy_node_emitted = true
                while current_dummy_index <= #surface do
                    current_dummy_index = current_dummy_index + 1
                    return Node:new(0, 0, 46041, surface[current_dummy_index], surface[current_dummy_index], "dummy")
                end
            end
            current_index = current_index + 1
            high_quality_count = high_quality_count - 1
            return best_n_node
        end
    end
end

function Module.register_userdict(userdict)
    Module.query_userdict = userdict
end

function Module.set_hira2kata_opencc(hira2kata_opencc)
    Module.hira2kata_opencc = hira2kata_opencc
end

function Module.clear()
    Module.lattice = {}
end

function Module.init()
    Module.kagiroi_dict.load()
    Module.lattice = {}
    Module.query_userdict = function(i)
        return function()
            return nil
        end
    end
end

function Module.fini()
    Module.lattice = {}
    Module.kagiroi_dict.release()
    Module.hira2kata_opencc = nil
end

return Module