-- kagiroi_viterbi.lua
-- maintain a lattice for viterbi algorithm
-- to offer contextual candidates.

-- license: GPLv3
-- version: 0.1.0
-- author: kuroame

local utf8 = require("utf8")
local kagiroi = require("kagiroi/kagiroi")
local Module = {
    kagiroi_dict = require("kagiroi/kagiroi_dict"),
    lattice = nil
}

local Node = {
    prev = nil, -- previous node
    left_id, -- left id of the node, from lex
    right_id, -- right id of the node, from lex
    cost, -- cost of the node, should = prev.cost + matrix(prev.right_id, left_id) + wcost(from lex)
    surface, -- surface of the node, from lex
    candidate, -- candidate of the node, from lex
    bnext_iter, -- iterator of the next node with the same begin position
    -- _bnext, -- cached next node with the same begin position
    enext_iter -- iterator of the next node with the same end position
}

function Node:new(left_id, right_id, cost, surface, candidate, type)
    local o = {}
    setmetatable(o, self)
    self.__index = self
    o.left_id = left_id
    o.right_id = right_id
    o.cost = cost
    o.surface = surface
    o.candidate = candidate
    o.type = type
    o.bnext_iter = function()
        return nil
    end
    o.enext_iter = function()
        return nil
    end
    return o
end

function Node:set_lazy_bnext(next_generator)
    self.bnext_iter = function()
        if not self._bnext then
            self._bnext = next_generator()
        end
        return self._bnext
    end
    return self
end

function Node:new_from_lex(lex)
    return Node:new(lex.left_id, lex.right_id, lex.cost, lex.surface, lex.candidate, "lex")
end

function Node:to_string()
    return string.format("Node{surface='%s', candidate='%s', cost=%d, left_id=%d, right_id=%d, type='%s'}",
        self.surface, self.candidate, self.cost, self.left_id, self.right_id, self.type)
end

local Lattice = {
    bos_node, -- begin of sentence node
    eos_node, -- end of sentence node
    begin_nodes = {}, -- nodes that begin at i
    begin_nodes_rear = {}, -- the rear node of begin_nodes
    -- the rear node of begin_nodes section,
    -- section means a group of nodes of same surface_len
    -- format: begin_nodes_section_rear[pos][end_pos]
    begin_nodes_section_rear = {},
    -- nodes that start at 1
    -- format:prefix_nodes[surface_len]
    prefix_nodes = {},
    end_nodes = {}, -- nodes that end at i
    -- best previous node and cost(ends at i) 
    -- for nodes that begin at i with left_id j
    -- format: best_prev_node_cost[i][j]
    best_prev_node_cost = {},
    input = "", -- input string
    input_len_in_utf8 = 0
}

function Lattice:new()
    local o = {}
    setmetatable(o, self)
    self.__index = self
    o.bos_node = Node:new(0, 0, 0, "", "", "bos")
    o.eos_node = Node:new(0, 0, 0, "", "", "eos")
    o.end_nodes[1] = o.bos_node
    return o
end

-- push a utf8 char into the lattice
function Lattice:push(uchar)
    self.input = self.input .. uchar
    self.input_len_in_utf8 = self.input_len_in_utf8 + 1
    for i = 1, self.input_len_in_utf8 do
        -- lookup the lexicon for possible nodes that begin at i, and update the begin_nodes
        self:lookup(i)
        -- connect the nodes
        self:connect(i)
    end
end

-- pop the last utf8 char from the lattice
function Lattice:pop()
    -- first, discard the nodes that end at self.input_len_in_utf8 + 1
    self.end_nodes[self.input_len_in_utf8 + 1] = nil
    -- then, iterate all begin nodes, and discard nodes that end at self.input_len_in_utf8 + 1
    for i = 1, self.input_len_in_utf8 do
        local section_rear = self.begin_nodes_section_rear[i][self.input_len_in_utf8]
        if section_rear then
            section_rear.bnext_iter = nil
            self.begin_nodes_rear[i] = section_rear
        end
    end
    self.input = kagiroi.utf8_sub(self.input, 1, -2)
    self.best_prev_node_cost[self.input_len_in_utf8 + 1] = nil
    self.begin_nodes_rear[self.input_len_in_utf8] = nil
    self.begin_nodes[self.input_len_in_utf8] = nil
    self.prefix_nodes[self.input_len_in_utf8] = nil
    self.input_len_in_utf8 = self.input_len_in_utf8 - 1
end

function Lattice:rebuild(input)
    self:clear()
    if input then
        self:analyze(input)
    end
end

function Lattice:clear()
    self.begin_nodes = {}
    self.begin_nodes_rear = {}
    self.begin_nodes_section_rear = {}
    self.prefix_nodes = {}
    self.end_nodes = {}
    self.best_prev_node_cost = {}
    self.input = ""
    self.input_len_in_utf8 = 0
    self.bos_node = Node:new(0, 0, 0, "", "", "bos")
    self.eos_node = Node:new(0, 0, 0, "", "", "eos")
    self.end_nodes[1] = self.bos_node
end

function Lattice:analyze(input)
    -- clear the lattice if it is a new input
    if utf8.len(input) == 1 then
        self:clear()
    end
    -- first we need to figure out the common prefix of input and self.input
    -- len of remaining part of the self.input should be the times we need to pop
    -- then we push every utf8 char into our Lattice

    -- strategy: when the common prefix is less than the half of the #input, consider rebuilding the lattice TODO

    -- log.info("input: " .. input .. " self.input: " .. self.input)
    local common_prefix, new_input_remaining, old_input_remaining = kagiroi.utf8_common_prefix(input, self.input)
    -- log.info("common_prefix: " .. common_prefix.." \tnew_input_remaining: " .. new_input_remaining..
    --     "\told_input_remaining: " .. old_input_remaining)
    local old_input_remaining_len = utf8.len(old_input_remaining)

    -- reset the eos
    self.begin_nodes[self.input_len_in_utf8 + 1] = nil
    -- self.eos_node.prev = nil
    while old_input_remaining_len > 0 do
        -- log.info("------------------------------------------------------------")
        -- log.info("poping ".. self.input_len_in_utf8)
        self:pop()
        old_input_remaining_len = old_input_remaining_len - 1
    end

    for uchar in kagiroi.utf8_char_iter(new_input_remaining) do
        -- log.info("------------------------------------------------------------")
        -- log.info("pushing: " .. uchar)
        self:push(uchar)
    end

    -- connect eos node to our lattice
    self.begin_nodes[self.input_len_in_utf8 + 1] = self.eos_node
    self:connect(self.input_len_in_utf8 + 1)
end

-- lookup the lexicon/user_dic for possible nodes that begin at pos, end at len(self.input)
-- then update the self.begin_nodes[pos]
function Lattice:lookup(pos)
    local surface = kagiroi.utf8_sub(self.input, pos)
    local surface_len = utf8.len(surface)
    -- log.info("querying surface: " .. surface)
    local lex_iter = Module.kagiroi_dict.query_lex(surface, false)
    local userdict_iter = Module.query_userdict(surface)
    local word_iter = Module._merge_iter(lex_iter, userdict_iter)
    -- SPECIAL CASE: if surface_len = 1, echo this surface to avoid empty lattice
    if surface_len == 1 then
        local emitted = false
        word_iter = Module._merge_iter(word_iter, function()
            if not emitted then
                emitted = true
                return {
                    candidate = surface,
                    surface = surface,
                    cost = math.huge,
                    left_id = -2,
                    right_id = -2
                }
            end
        end)
    end
    local function bnext_iter()
        local lex = word_iter()
        if lex then
            -- log.info("found lex: " .. lex.candidate .. " for surface: " .. lex.surface)
            return Node:new_from_lex(lex):set_lazy_bnext(bnext_iter)
        else
            return nil
        end
    end
    -- if there are already begin nodes at pos, append the new nodes to the end
    if self.begin_nodes[pos] then
        -- notice that begin_nodes_rear is maintained in connect function
        local rear_node = self.begin_nodes_rear[pos]
        -- log.info("appending new nodes to the rear node: " .. rear_node.candidate .. "|" .. rear_node.type.. " at pos: " .. pos)
        rear_node.bnext_iter = bnext_iter
    else
        local node = bnext_iter()
        -- log.info("first begin node at pos: " .. pos .. " is " .. node.candidate .. "|" .. node.type)
        self.begin_nodes[pos] = node
    end
end

-- connect the nodes that begin at pos, updating cost, prev, and end_nodes
function Lattice:connect(pos)
    -- log.info("connecting pos: " .. pos)
    -- iterate from the rear node of begin_nodes
    local rear_node = self.begin_nodes_rear[pos]
    local cur_node = nil
    -- if not rear node recorded, which means it is a new linkedlist
    -- we need to iterate from the beginning
    if not rear_node then
        cur_node = self.begin_nodes[pos]
    else
        -- log.info("rear node found at pos: " .. pos .. " is " .. rear_node.candidate .. "|" .. rear_node.type)
        cur_node = rear_node.bnext_iter()
    end

    while cur_node do
        -- log.info("connecting cur_node: " .. cur_node.candidate .. "|" .. cur_node.type)
        -- find a best previous node for current node
        local best_prev_node = nil
        local best_cost = math.huge

        -- check if there's already a best previous node recorded
        if self.best_prev_node_cost[pos] and self.best_prev_node_cost[pos][cur_node.left_id] then
            -- log.info("cached best_prev_node_cost found at pos: " .. pos .. " for left_id: " .. cur_node.left_id.. " is " .. self.best_prev_node_cost[pos][cur_node.left_id].node.candidate .. "|" .. self.best_prev_node_cost[pos][cur_node.left_id].node.type)
            local best_node_cost = self.best_prev_node_cost[pos][cur_node.left_id]
            best_prev_node = best_node_cost.node
            -- best_node_cost.cost = best_prev_node.cost + trans_cost
            -- recorded to save an extra matrix query
            best_cost = best_node_cost.cost + cur_node.cost
        end

        -- if not, we need to find the best previous node from the end_nodes at pos
        if not best_prev_node then
            -- iterate the possible prev node(nodes that end at pos) from the beginning of the linkedlist
            local prev_node = self.end_nodes[pos]
            if not prev_node then
                -- log.info("no previous node found at pos: " .. pos)
                -- if no previous node found, then this cur_node is unlinkable
                -- we need to move to the next node
                goto continue
            end
            best_prev_node = prev_node
            while prev_node do
                -- log.info("iterating prev_node: " .. prev_node.candidate .. "|" .. prev_node.type)
                -- just for debugging, this should not happen
                if prev_node.type == "eos" then
                    log.error("eos node found in the middle of the lattice")
                end
                -- query the transition cost
                local trans_cost = Module.kagiroi_dict.query_matrix(prev_node.right_id, cur_node.left_id)
                -- calculate the accumulated cost
                local acost = prev_node.cost + trans_cost + cur_node.cost
                -- update best cost and best prev node if needed
                if acost < best_cost then
                    best_cost = acost
                    best_prev_node = prev_node
                end
                -- move to the next prev node
                prev_node = prev_node.enext_iter()
            end
        end

        -- update the best_prev_node_cost
        if not self.best_prev_node_cost[pos] then
            self.best_prev_node_cost[pos] = {}
        end
        self.best_prev_node_cost[pos][cur_node.left_id] = {
            node = best_prev_node,
            cost = best_cost - cur_node.cost
        }

        -- update the node
        cur_node.prev = best_prev_node
        cur_node.cost = best_cost

        -- SPECIAL CASE: if best_prev_node is bos Node
        -- need to maintain a list for best_n_phrase to iterate
        if best_prev_node.type == "bos" then
            local surface_len = utf8.len(cur_node.surface)
            if not self.prefix_nodes[surface_len] then
                self.prefix_nodes[surface_len] = {}
            end
            kagiroi.insert_sorted(self.prefix_nodes[surface_len], cur_node, function(a, b)
                return a.cost < b.cost
            end)
        end

        -- log.info("connect prev node to cur_node: " .. best_prev_node.candidate .. "|" .. best_prev_node.type .. " -> " ..
        --           cur_node.candidate .. "|" .. cur_node.type)

        -- update end_nodes, best_prev_node_cost,
        -- this lex type check is to ensure the eos node won't be considered as end node,
        -- since no need to append any node to the eos node
        if cur_node.type == "lex" then
            -- update the end_nodes
            local current_end = self.end_nodes[self.input_len_in_utf8 + 1]
            cur_node.enext_iter = function()
                return current_end
            end
            self.end_nodes[self.input_len_in_utf8 + 1] = cur_node
            -- log.info("update end_nodes at pos: " .. self.input_len_in_utf8 + 1 .. " with node: " .. cur_node.candidate.. "|" .. cur_node.type)
        end

        ::continue::
        local next_node = cur_node.bnext_iter()
        if not next_node then
            -- if no next node found, then this cur_node is the rear node
            -- we need to record it
            if cur_node.type == "lex" then
                self.begin_nodes_rear[pos] = cur_node
                if not self.begin_nodes_section_rear[pos] then
                    self.begin_nodes_section_rear[pos] = {}
                end
                self.begin_nodes_section_rear[pos][self.input_len_in_utf8 + 1] = cur_node
                -- log.info("recorded rear node at pos: " .. pos .. " is " .. cur_node.candidate .. "|" .. cur_node.type)
            end
            -- log.info("no next node found, break, cur_node: " .. cur_node.candidate .. "|" .. cur_node.type)
            break
        end
        -- move to the next node
        cur_node = next_node
    end
end

-- get the best sentence
function Lattice:best_sentence()
    local prev = self.eos_node.prev
    if not prev then
        self:clear()
        error("eos node not connected!")
    end
    local candidate = ""
    local surface = ""
    local prefix = nil
    local left_id = prev.left_id
    local right_id = prev.right_id
    while prev do
        candidate = prev.candidate .. candidate
        surface = prev.surface .. surface
        if prev.prev and prev.prev.type == "bos" then
            prefix = prev
            break
        end
        prev = prev.prev
        left_id = prev.left_id
    end
    return {
        surface = surface,
        candidate = candidate,
        cost = self.eos_node.cost,
        prefix = prev,
        left_id = left_id,
        right_id = right_id
    }
end

-- get the best n phrases starting from the beginning of input
-- returns an iterator that yields nodes in the ascending order of lengh of the surface, then cost
function Lattice:best_n_phrase(n)
    local cur_len = self.input_len_in_utf8
    local current_index = 1
    return function()
        while cur_len > 0 do
            local cur_nodes = self.prefix_nodes[cur_len]
            if cur_nodes and #cur_nodes > 0 then
                if current_index <= #cur_nodes then
                    local node = cur_nodes[current_index]
                    current_index = current_index + 1
                    return node
                else
                    cur_len = cur_len - 1
                    current_index = 1
                end
            else
                cur_len = cur_len - 1
                current_index = 1
            end
        end
        return nil
    end
end

function Module.init()
    Module.kagiroi_dict.load()
    Module.lattice = Lattice:new()
    Module.query_userdict = function(i)
        return function()
            return nil
        end
    end
end

function Module.fini()
    Module.kagiroi_dict.release()
end

function Module.analyze(input)
    Module.lattice:analyze(input)
end

function Module.clear()
    Module.lattice:clear()
end

function Module.best()
    return Module.lattice:best_sentence()
end

function Module.best_n_prefix(n)
    return Module.lattice:best_n_phrase(n)
end

function Module.register_userdict(userdict)
    Module.query_userdict = userdict
end

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

return Module
