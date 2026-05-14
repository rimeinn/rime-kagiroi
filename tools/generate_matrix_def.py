#!/usr/bin/env python3
import argparse
import os

ROOT_DIR = os.path.join(os.path.dirname(__file__), '../')
CONNECTION_DEFLATE_PATH = os.path.join(
    ROOT_DIR, 'mozc/src/data/dictionary_oss/'
    'connection_single_column.txt')
MOZC_ID_DEF_PATH = os.path.join(
    ROOT_DIR, 'mozc/src/data/dictionary_oss/id.def')
KAGIROI_ID_DEF_PATH = os.path.join(
    ROOT_DIR, 'lua/kagiroi/dic/kagiroi_id.def')


def decompress_deflate(path):
    with open(path, 'r') as f:
        return f.read()


def load_id_def(path):
    id_to_pos = {}
    pos_to_id = {}
    with open(path, 'r', encoding='utf-8') as f:
        for line in f:
            line = line.rstrip('\n')
            if not line:
                continue
            parts = line.split(' ', 1)
            if len(parts) != 2:
                continue
            pos_id = int(parts[0])
            pos = parts[1]
            id_to_pos[pos_id] = pos
            pos_to_id[pos] = pos_id
    return id_to_pos, pos_to_id


def build_id_map(mozc_id_def_path, kagiroi_id_def_path):
    mozc_id_to_pos, _ = load_id_def(mozc_id_def_path)
    _, kagiroi_pos_to_id = load_id_def(kagiroi_id_def_path)
    mozc_to_kagiroi = {}
    for mozc_id, pos in mozc_id_to_pos.items():
        if pos not in kagiroi_pos_to_id:
            raise RuntimeError(f'POS not found in kagiroi id def: {pos}')
        mozc_to_kagiroi[mozc_id] = kagiroi_pos_to_id[pos]
    return mozc_to_kagiroi


def to_matrix(connections, mozc_to_kagiroi):
    num_classes = int(connections[0])
    connection_matrix = []
    for lid in range(num_classes):
        if lid not in mozc_to_kagiroi:
            raise RuntimeError(f'Mozc left id is not defined in id.def: {lid}')
        for rid in range(num_classes):
            if rid not in mozc_to_kagiroi:
                raise RuntimeError(f'Mozc right id is not defined in id.def: {rid}')
            line = '%s %s %s' % (mozc_to_kagiroi[lid], mozc_to_kagiroi[rid],
                                 connections[lid * num_classes + rid + 1])
            connection_matrix.append(line)
    return '\n'.join(connection_matrix)


def main():
    parser = argparse.ArgumentParser(
        description='Generate kagiroi stable-ID matrix from mozc connection data.')
    parser.add_argument('--connection-file', default=CONNECTION_DEFLATE_PATH)
    parser.add_argument('--mozc-id-def', default=MOZC_ID_DEF_PATH)
    parser.add_argument('--kagiroi-id-def', default=KAGIROI_ID_DEF_PATH)
    args = parser.parse_args()

    mozc_to_kagiroi = build_id_map(args.mozc_id_def, args.kagiroi_id_def)
    connections = decompress_deflate(args.connection_file)
    connections = connections.splitlines()
    connection_matrix = to_matrix(connections, mozc_to_kagiroi)
    print(connection_matrix)


if __name__ == '__main__':
    main()
