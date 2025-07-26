#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""A tool to generate segmenter Lua code from human-readable rule file."""

import codecs
import re
import sys


HEADER = """-- Auto-generated segmenter code
-- Generated from: %s
local segmenter = {}

-- Constants
segmenter.L_SIZE = %d
segmenter.R_SIZE = %d

-- Boundary checking function
-- @param rid: Right node POS ID (uint16_t)
-- @param lid: Left node POS ID (uint16_t)  
-- @return: boolean - true if boundary exists, false otherwise
function segmenter.is_boundary_internal(rid, lid)
  -- BOS * or * EOS always has boundary
  if rid == 0 or lid == 0 then
    return true
  end
"""

FOOTER = """
  -- Default rule: boundary exists for unmatched cases
  return true
end

-- Export the segmenter module
return segmenter
"""


def ReadPOSID(id_file, special_pos_file):
    """Read POS ID mappings from files."""
    pos = {}
    max_id = 0

    for line in codecs.open(id_file, "r", encoding="utf8"):
        fields = line.split()
        pos[fields[1]] = fields[0]
        max_id = max(int(fields[0]), max_id)

    max_id = max_id + 1
    for line in codecs.open(special_pos_file, "r", encoding="utf8"):
        if len(line) <= 1 or line[0] == "#":
            continue
        fields = line.split()
        pos[fields[0]] = ("%d" % max_id)
        max_id = max_id + 1

    return pos


def PatternToRegexp(pattern):
    """Convert pattern to regexp, handling special characters."""
    return pattern.replace("*", "[^,]+")


def GetLuaCondition(pos, pattern, name):
    """Generate Lua condition for pattern matching."""
    if pattern == "*":
        return "true"

    pat = re.compile(PatternToRegexp(pattern))
    min_id = -1
    max_id = -1
    keys = list(pos.keys())
    keys.sort()

    id_range = []

    for p in keys:
        id_val = pos[p]
        if pat.match(p):
            if min_id == -1:
                min_id = id_val
                max_id = id_val
            else:
                max_id = id_val
        else:
            if min_id != -1:
                id_range.append([min_id, max_id])
                min_id = -1
    if min_id != -1:
        id_range.append([min_id, max_id])

    conditions = []
    for r in id_range:
        if r[0] == r[1]:
            conditions.append(f"({name} == {r[0]})")
        else:
            conditions.append(f"({name} >= {r[0]} and {name} <= {r[1]})")

    if not conditions:
        print(f"FATAL: No rule found {pattern}")
        sys.exit(-1)

    return " or ".join(conditions)





def main():
    pos = ReadPOSID(sys.argv[1], sys.argv[2])

    print(HEADER % (sys.argv[3], len(list(pos.keys())), len(list(pos.keys()))))

    for line in codecs.open(sys.argv[3], "r", encoding="utf8"):
        if len(line) <= 1 or line[0] == "#":
            continue
        (l, r, result) = line.split()
        result = result.lower()
        lcond = GetLuaCondition(pos, l, "rid") or "true"
        rcond = GetLuaCondition(pos, r, "lid") or "true"
        print("  -- %s %s %s" % (l, r, result))
        print("  if (%s) and (%s) then return %s end" % (lcond, rcond, result))

    print(FOOTER)


if __name__ == "__main__":
    main() 