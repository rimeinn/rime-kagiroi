#!/usr/bin/env python3
# -*- coding: utf-8 -*-
import sys
import re
from pathlib import Path
from typing import Dict, List, Tuple, Set


def load_id_def(file_path: str) -> Dict[str, str]:
    id_dict = {}
    with open(file_path, 'r', encoding='utf-8') as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            
            parts = line.split(' ', 1)
            if len(parts) != 2:
                continue
                
            id_num = parts[0]
            pos_info = parts[1]
            id_dict[id_num] = pos_info
    
    return id_dict


def load_boundary_def(file_path: str) -> List[Tuple[str, str, str]]:
    boundary_list = []
    with open(file_path, 'r', encoding='utf-8') as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith('#'):
                continue
            
            parts = re.split(r'\s+', line)
            if len(parts) < 3:
                continue
            
            prefix_suffix = parts[0]
            if prefix_suffix not in ['PREFIX', 'SUFFIX']:
                continue
            
            cost = parts[-1]
            pos_info = ' '.join(parts[1:-1])
            
            boundary_list.append((prefix_suffix, pos_info, cost))
    
    return boundary_list


def match_pos_pattern(id_pos: str, boundary_pos: str) -> bool:
    if '(' in boundary_pos and '|' in boundary_pos:
        try:
            boundary_pattern = boundary_pos.replace('*', '[^,]*')
            return re.search(boundary_pattern, id_pos) is not None
        except re.error:
            pass
    
    id_parts = id_pos.split(',')
    boundary_parts = boundary_pos.split(',')
    
    if len(id_parts) != 7 or len(boundary_parts) != 7:
        min_len = min(len(id_parts), len(boundary_parts))
        for i in range(min_len):
            boundary_part = boundary_parts[i].strip()
            id_part = id_parts[i].strip()
            
            if boundary_part == '*':
                continue
            
            if boundary_part != id_part:
                return False
        return True
    
    for i in range(7):
        boundary_part = boundary_parts[i].strip()
        id_part = id_parts[i].strip()
        
        if boundary_part == '*':
            continue
        
        if boundary_part != id_part:
            return False
    
    return True


def join_files(id_file: str, boundary_file: str) -> None:
    id_dict = load_id_def(id_file)
    boundary_list = load_boundary_def(boundary_file)
    
    prefix_costs: Dict[str, str] = {}
    suffix_costs: Dict[str, str] = {}
    
    for boundary_type, boundary_pos, cost in boundary_list:
        for id_num, id_pos in id_dict.items():
            if match_pos_pattern(id_pos, boundary_pos):
                if boundary_type == 'PREFIX':
                    prefix_costs[id_num] = cost
                elif boundary_type == 'SUFFIX':
                    suffix_costs[id_num] = cost
    
    for id_num in id_dict.keys():
        if id_num in prefix_costs:
            print(f"-10 {id_num} {prefix_costs[id_num]}")
        else:
            print(f"-10 {id_num} 0")
    
    for id_num in id_dict.keys():
        if id_num in suffix_costs:
            print(f"{id_num} -20 {suffix_costs[id_num]}")
        else:
            print(f"{id_num} -20 0")


def main():
    script_dir = Path(__file__).parent
    project_root = script_dir.parent
    
    id_file = project_root / "mozc" / "src" / "data" / "dictionary_oss" / "id.def"
    boundary_file = project_root / "mozc" / "src" / "data" / "rules" / "boundary.def"
    
    if not id_file.exists():
        print(f"Error: {id_file} not found", file=sys.stderr)
        sys.exit(1)
    
    if not boundary_file.exists():
        print(f"Error: {boundary_file} not found", file=sys.stderr)
        sys.exit(1)
    
    join_files(str(id_file), str(boundary_file))


if __name__ == "__main__":
    main()