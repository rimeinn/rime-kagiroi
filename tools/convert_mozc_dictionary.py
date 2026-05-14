#!/usr/bin/env python3
# -*- coding: utf-8 -*-
import argparse
import sys
from pathlib import Path


def load_id_def(path):
    id_to_pos = {}
    pos_to_id = {}
    with open(path, "r", encoding="utf-8") as f:
        for line in f:
            line = line.rstrip("\n")
            if not line:
                continue
            parts = line.split(" ", 1)
            if len(parts) != 2:
                continue
            pos_id = int(parts[0])
            pos = parts[1]
            id_to_pos[pos_id] = pos
            pos_to_id[pos] = pos_id
    return id_to_pos, pos_to_id


def append_missing_pos(kagiroi_id_path, mozc_id_to_pos, kagiroi_pos_to_id):
    next_id = max(kagiroi_pos_to_id.values(), default=-1) + 1
    missing = []
    for pos in mozc_id_to_pos.values():
        if pos not in kagiroi_pos_to_id:
            missing.append((next_id, pos))
            kagiroi_pos_to_id[pos] = next_id
            next_id += 1

    if not missing:
        return

    with open(kagiroi_id_path, "a", encoding="utf-8") as f:
        for pos_id, pos in missing:
            f.write(f"{pos_id} {pos}\n")

    print(f"Appended {len(missing)} new POS IDs to {kagiroi_id_path}", file=sys.stderr)


def build_id_map(mozc_id_to_pos, kagiroi_pos_to_id):
    mozc_to_kagiroi = {}
    for mozc_id, pos in mozc_id_to_pos.items():
        try:
            mozc_to_kagiroi[mozc_id] = kagiroi_pos_to_id[pos]
        except KeyError:
            raise RuntimeError(f"POS not found in kagiroi id def: {pos}") from None
    return mozc_to_kagiroi


def load_excluded(path):
    if not path:
        return set()
    excluded_path = Path(path)
    if not excluded_path.exists():
        return set()
    excluded = set()
    with open(excluded_path, "r", encoding="utf-8") as f:
        for line in f:
            line = line.rstrip("\n")
            if line:
                excluded.add(line)
    return excluded


def convert_dictionary(stdin, stdout, mozc_to_kagiroi, excluded):
    for line in stdin:
        line = line.rstrip("\n")
        if not line:
            continue
        parts = line.split("\t")
        if len(parts) < 5 or not parts[0]:
            continue
        reading, left_id, right_id, cost, candidate = parts[:5]
        if ",".join([reading, left_id, right_id, cost, candidate]) in excluded:
            continue
        try:
            kagiroi_left_id = mozc_to_kagiroi[int(left_id)]
            kagiroi_right_id = mozc_to_kagiroi[int(right_id)]
        except (KeyError, ValueError) as e:
            raise RuntimeError(f"Failed to map POS IDs in line: {line}") from e
        if ",".join(
            [reading, str(kagiroi_left_id), str(kagiroi_right_id), cost, candidate]
        ) in excluded:
            continue
        print(f"{candidate}|{kagiroi_left_id} {kagiroi_right_id}\t{reading}\t{cost}", file=stdout)


def main():
    parser = argparse.ArgumentParser(
        description="Convert mozc dictionary entries to kagiroi stable POS IDs."
    )
    parser.add_argument("--mozc-id-def", required=True)
    parser.add_argument("--kagiroi-id-def", required=True)
    parser.add_argument("--exclude")
    args = parser.parse_args()

    mozc_id_to_pos, _ = load_id_def(args.mozc_id_def)
    _, kagiroi_pos_to_id = load_id_def(args.kagiroi_id_def)
    append_missing_pos(Path(args.kagiroi_id_def), mozc_id_to_pos, kagiroi_pos_to_id)
    mozc_to_kagiroi = build_id_map(mozc_id_to_pos, kagiroi_pos_to_id)
    excluded = load_excluded(args.exclude)
    convert_dictionary(sys.stdin, sys.stdout, mozc_to_kagiroi, excluded)


if __name__ == "__main__":
    main()
