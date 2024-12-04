[日本語](README.md)
# 简介
基于Rime实现的罗马字日语输入方案

第一次部署时，会将词典和连接矩阵数据导入leveldb，耗费约1分钟

# 特点
- 使用[Project Mozc](https://github.com/google/mozc)的词典及连接矩阵数据
- 使用Viterbi算法对假名序列进行转换
- 使用Rime Algebra支持多种罗马字拼写
  
# 用例
![](misc/example.png)

# 依赖
- librime >= 1.12.0
- librime-lua plugin

# 协议
本项目基于 GPLv3 开源

Mozc词典相关的开源协议参见
[这里](https://github.com/google/mozc/blob/006ed69bf545548a8a3596b13f58cb22cf3d8a2f/src/data/dictionary_oss/README.txt)

# 参考项目
- [Mozc: a Japanese Input Method Editor designed for multi-platform](https://github.com/google/mozc)
- [MeCab: Yet Another Part-of-Speech and Morphological Analyzer](https://taku910.github.io/mecab/)
- [Mozc for Python: Kana-Kanji converter](https://github.com/ikegami-yukino/mozcpy)