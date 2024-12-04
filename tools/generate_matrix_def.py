#!/usr/bin/env python3
import os

ROOT_DIR = os.path.join(os.path.dirname(__file__), '../')
CONNECTION_DEFLATE_PATH = os.path.join(
    ROOT_DIR, 'mozc/src/data/dictionary_oss/'
    'connection_single_column.txt')
MATRIX_DEF_PATH = os.path.join(ROOT_DIR, 'lua/kagiroi/dic/matrix.def')


def decompress_deflate(path):
    with open(CONNECTION_DEFLATE_PATH, 'r') as f:
        return f.read()


def to_matrix(connections):
    num_classes = int(connections[0])
    connection_matrix = ['%s %s' % (num_classes, num_classes)]
    for lid in range(num_classes):
        for rid in range(num_classes):
            line = '%s %s %s' % (lid, rid,
                                 connections[lid * num_classes + rid + 1])
            connection_matrix.append(line)
    return '\n'.join(connection_matrix)


def main():
    connections = decompress_deflate(CONNECTION_DEFLATE_PATH)
    connections = connections.splitlines()
    connection_matrix = to_matrix(connections)
    os.makedirs(os.path.dirname(MATRIX_DEF_PATH), exist_ok=True)
    with open(MATRIX_DEF_PATH, 'w') as f:
        f.write(connection_matrix)


if __name__ == '__main__':
    main()
