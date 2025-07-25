#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Script to filter dictionary_nico.txt by removing entries found on the specified webpage.
"""

import re
import requests
import sys
import os
from typing import Set, Tuple

def katakana_to_hiragana(text):
    """Convert katakana to hiragana"""
    result = ""
    for char in text:
        # Convert katakana to hiragana
        if 'ァ' <= char <= 'ヴ':
            result += chr(ord(char) - ord('ァ') + ord('ぁ'))
        else:
            result += char
    return result

def fetch_webpage_entries(url: str) -> Set[Tuple[str, str]]:
    """
    Fetch the webpage and extract word-reading pairs from li elements.
    Returns a set of tuples (hiragana_reading, word).
    """
    print(f"Fetching webpage: {url}")
    try:
        response = requests.get(url, timeout=30)
        response.raise_for_status()
        response.encoding = 'utf-8'
        content = response.text
    except requests.RequestException as e:
        print(f"Error fetching webpage: {e}")
        return set()
    
    # Regular expression to match the li elements  
    # <li><a class="auto" href="xxx">(.+)</a>（(.+）</li>
    pattern = r'<li><a class="auto" href="[^"]*">([^<]+)</a>（([^）]+)）</li>'
    matches = re.findall(pattern, content)
    
    entries = set()
    for word, reading_content in matches:
        # Extract pure text from reading content (remove HTML tags)
        # The reading content might contain HTML tags like <a>text</a>
        clean_reading = re.sub(r'<[^>]+>', '', reading_content)
        # Convert katakana reading to hiragana
        hiragana_reading = katakana_to_hiragana(clean_reading)
        entries.add((hiragana_reading, word))
    
    print(f"Total entries found: {len(entries)}")
    return entries

def filter_dictionary(dictionary_path: str, entries_to_remove: Set[Tuple[str, str]]):
    """
    Read dictionary_nico.txt, remove entries that match the webpage entries,
    and write the filtered content back to the file.
    """
    if not os.path.exists(dictionary_path):
        print(f"Dictionary file not found: {dictionary_path}")
        return
    
    print(f"Reading dictionary: {dictionary_path}")
    
    filtered_lines = []
    removed_count = 0
    total_count = 0
    
    with open(dictionary_path, 'r', encoding='utf-8-sig') as f:
        for line_num, line in enumerate(f, 1):
            line = line.strip()
            total_count += 1
            
            # Skip header lines and empty lines
            if line.startswith('!') or not line:
                filtered_lines.append(line)
                continue
            
            # Split by tab
            parts = line.split('\t')
            if len(parts) < 2:
                filtered_lines.append(line)
                continue
            
            hiragana_reading = parts[0]
            word = parts[1]
            
            # Check if this entry should be removed
            if (hiragana_reading, word) in entries_to_remove:
                print(f"Removing: {hiragana_reading} -> {word}")
                removed_count += 1
            else:
                filtered_lines.append(line)
    
    print(f"Total lines processed: {total_count}")
    print(f"Lines removed: {removed_count}")
    print(f"Lines remaining: {len(filtered_lines)}")
    
    # Write filtered content back to file
    print(f"Writing filtered dictionary back to: {dictionary_path}")
    with open(dictionary_path, 'w', encoding='utf-8-sig') as f:
        for line in filtered_lines:
            f.write(line + '\n')
    
    print("Dictionary filtering completed!")

def main():
    # URL to fetch
    url = "https://dic.nicovideo.jp/a/%E8%AA%AD%E3%81%BF%E3%81%8C%E9%80%9A%E5%B8%B8%E3%81%AE%E8%AA%AD%E3%81%BF%E6%96%B9%E3%81%A8%E3%81%AF%E7%95%B0%E3%81%AA%E3%82%8B%E8%A8%98%E4%BA%8B%E3%81%AE%E4%B8%80%E8%A6%A7"
    
    # Path to dictionary file (relative to script location)
    script_dir = os.path.dirname(os.path.abspath(__file__))
    dictionary_path = os.path.join(script_dir, '..', 'lua', 'kagiroi', 'dic', 'dictionary_nico.txt')
    dictionary_path = os.path.normpath(dictionary_path)
    
    # Fetch entries from webpage
    entries_to_remove = fetch_webpage_entries(url)
    
    if not entries_to_remove:
        print("No entries found on webpage, exiting...")
        return
    
    # Filter dictionary
    filter_dictionary(dictionary_path, entries_to_remove)

if __name__ == "__main__":
    main() 