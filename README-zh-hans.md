[日本語](README.md)
# 简介
基于Rime实现的罗马字日语输入方案

第一次部署时，会将词典和连接矩阵数据导入leveldb，耗费约1分钟

# 特点
- 使用[Project Mozc](https://github.com/google/mozc)的词典及连接矩阵数据
- 使用Viterbi算法对假名序列进行转换
- 使用Rime Algebra支持多种罗马字拼写

# 安装
℞ `pfeiwu/rime-kagiroi`

# 用例
![](misc/example.png)

<div style="padding: 10px; border: 1px solid #00f; background-color: #e7f3ff; color: #00529b; margin-bottom: 15px;">
  💡 <strong>提示:</strong> 得益于Rime强大的配置能力，你可以在其他方案中使用本方案作为辅助输出，这可以通过与affix_segmentor的配合实现，以下配置仅作为参考。
</div>


```yaml

  # 在xxx.custom.yaml中，xxx为你的主方案
  schema/dependencies/+:
    - kagiroi
    - kagiroi_kana
  engine/segmentors/@before 5: affix_segmentor@kagiroi # 关于顺序问题，可以参考https://github.com/rime/librime/pull/959
  engine/translators/+:
    - lua_translator@*kagiroi/kagiroi_translator
  kagiroi:
    prefix: ok # 引导前缀，可修改，如有修改，下面的pattern也需要同步改
    tips: 〔火光〕 # 提示符，可修改 （火光（カギロイ/Glimmer）来自Xenoblade3，レックス(Rex)和ホムラ(Pyra)女儿的名字(大概)）
    tag: kagiroi
  recognizer/patterns/kagiroi: '(^ok[a-z\-]*$)'

  # 在kagiroi方案中-和q都可以用来输入长音
  # 作为辅助方案时，使用-输出长音需要以下额外的步骤：
  # 1. 需要将-添加到alphabet中
  speller/alphabet: ...-; #在原来的基础上加-即可
  # 2. 需要修改-的翻页功能
  # 默认的key_bindings.yaml中，-被用作翻页键
  # 找到 - { when: has_menu, accept: minus, send: Page_Up } 将has_menu改为paging, 这样只有在进入paging状态后，-才会向前翻页
  # 也可以在key_bindings.custom.yaml通过patch方式修改（更好）

```

# 依赖
- librime >= 1.11.2
- librime-lua plugin

# 协议
本项目基于 GPLv3 开源

Mozc词典相关的开源协议参见
[这里](https://github.com/google/mozc/blob/006ed69bf545548a8a3596b13f58cb22cf3d8a2f/src/data/dictionary_oss/README.txt)

# 参考项目
- [Mozc: a Japanese Input Method Editor designed for multi-platform](https://github.com/google/mozc)
- [MeCab: Yet Another Part-of-Speech and Morphological Analyzer](https://taku910.github.io/mecab/)
- [Mozc for Python: Kana-Kanji converter](https://github.com/ikegami-yukino/mozcpy)
