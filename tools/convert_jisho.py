#!/usr/bin/env python3
# -*- coding: utf-8 -*-
import sys
import argparse
import re
from typing import Dict, List, Tuple, Optional

def load_id_def(id_def_path: str) -> Dict[str, int]:
    id_mapping = {}
    
    with open(id_def_path, 'r', encoding='utf-8') as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
                
            # 解析ID定义行
            parts = line.split(' ', 1)
            if len(parts) != 2:
                continue
                
            try:
                pos_id = int(parts[0])
                pos_info = parts[1]
            except ValueError:
                continue
            
            # 解析词性信息
            pos_parts = pos_info.split(',')
            if len(pos_parts) >= 2:
                # 获取主要词性和子类别
                main_pos = pos_parts[0].strip()  # 主要词性
                sub_pos = pos_parts[1].strip()   # 子类别
                
                # 创建键，优先创建更具体的键
                keys_to_add = []
                
                # 如果有子类别且不是*，优先创建完整的键
                if sub_pos != '*':
                    keys_to_add.append(f"{main_pos},{sub_pos}")
                
                # 然后创建主要词性键（但优先级较低）
                keys_to_add.append(main_pos)
                
                # 如果有第三列，也加上
                if len(pos_parts) >= 3:
                    third_pos = pos_parts[2].strip()
                    if third_pos != '*':
                        keys_to_add.insert(0, f"{main_pos},{sub_pos},{third_pos}")
                
                # 添加到映射中，但不覆盖已存在的更具体的匹配
                for key in keys_to_add:
                    if key not in id_mapping:
                        id_mapping[key] = pos_id
    
    return id_mapping

def find_pos_id(pos_type: str, id_mapping: Dict[str, int]) -> int:
    if pos_type in id_mapping:
        return id_mapping[pos_type]
    
    matching_keys = []
    for key in id_mapping.keys():
        if pos_type in key:
            matching_keys.append(key)
    
    if matching_keys:
        best_key = max(matching_keys, key=len)
        return id_mapping[best_key]

    for key in sorted(id_mapping.keys(), key=len, reverse=True):
        if key in pos_type:
            return id_mapping[key]
    return 1851

def convert_entry(entry: str, id_mapping: Dict[str, int], default_cost: int) -> str:
    parts = entry.strip().split('\t')
    if len(parts) < 3:
        return ""
    
    surface = parts[0].strip()   
    candidate = parts[1].strip() 
    pos_type = parts[2].strip()  
    
    pos_id = find_pos_id(pos_type, id_mapping)
    left_id = pos_id
    right_id = pos_id
    
    output_parts = [
        surface,
        str(left_id),
        str(right_id),
        str(default_cost),
        candidate
    ]
    
    return '\t'.join(output_parts)

def main():
    parser = argparse.ArgumentParser(description='convert the dict file format to lex.csv')
    parser.add_argument('id_def_path', help='id.def file path')
    parser.add_argument('default_cost', type=int, help='default cost')
    parser.add_argument('--input', '-i', help='input file')
    
    args = parser.parse_args()
    
    # 加载ID定义
    try:
        id_mapping = load_id_def(args.id_def_path)
    except FileNotFoundError:
        sys.exit(1)
    except Exception as e:
        sys.exit(1)
    
    input_stream = open(args.input, 'r', encoding='utf-8') if args.input else sys.stdin
    
    try:
        for line_num, line in enumerate(input_stream, 1):
            line = line.strip()
            if not line or line.startswith('#'):
                continue
            
            try:
                converted = convert_entry(line, id_mapping, args.default_cost)
                if converted:
                    print(converted)
            except Exception as e:
                continue
    finally:
        if args.input:
            input_stream.close()

if __name__ == '__main__':
    main() 