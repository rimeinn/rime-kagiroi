[简体中文](README-zh-hans.md)

# 概要
Rime Input Method Engineで作ったローマ字日本語IME

Rimeについては

- [RIMEの公式HP(中国語)](https://rime.im/)
- [RIMEのGithub Organization](https://github.com/rime)

を参照してください

初回Deployは辞書と連接表をleveldbにロードするため、1分ほどの時間がかかります

# 特徴
- [Project Mozc](https://github.com/google/mozc)の辞書、及び連接表データを使用
- Viterbiアルゴリズムで最適変換を
- Rime Algebraでいろんなローマ字表記を支援

# 使用例
![](misc/example.png)

# 依存
- librime >= 1.11.2
- librime-lua plugin

# ライセンス
このプロジェクトは GPLv3 ライセンスの下で公開されています

Mozcの辞書データのライセンスについては
[こちら](https://github.com/google/mozc/blob/006ed69bf545548a8a3596b13f58cb22cf3d8a2f/src/data/dictionary_oss/README.txt)
で確認してください
# 参考したプロジェクト
- [Mozc: a Japanese Input Method Editor designed for multi-platform](https://github.com/google/mozc)
- [MeCab: Yet Another Part-of-Speech and Morphological Analyzer](https://taku910.github.io/mecab/)
- [Mozc for Python: Kana-Kanji converter](https://github.com/ikegami-yukino/mozcpy)