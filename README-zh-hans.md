[日本語](README.md)
# 简介
基于Rime实现的日语输入方案

# 特点
- 使用[Project Mozc](https://github.com/google/mozc)的词典及连接矩阵数据
- 使用Viterbi算法对假名序列进行转换
- 內置罗马字、假名布局，也可以自行依据这些配置轻松地加入其他布局
- 支持实时或者在kagiroi.dict.yaml里添加自定义词汇

# 安装
℞ `rimeinn/rime-kagiroi`

# 用例
![](misc/example.png)


> 💡 **提示**
> 
> 得益于Rime强大的配置能力，你可以在其他方案中使用本方案作为辅助输出，这可以通过与affix_segmentor的配合实现，以下配置仅作为参考。




```yaml

  # 在xxx.custom.yaml中，xxx为你的主方案
  schema/dependencies/+:
    - kagiroi
  engine/segmentors/@before 5: affix_segmentor@kagiroi # 关于顺序问题，可以参考https://github.com/rime/librime/pull/959
  engine/processors/@before 5: lua_processor@*kagiroi/kagiroi_kana_speller # kagiroi使用到的自定义speller，至少要放到rime自带speller的前面，如果打字发现编辑区仍然没有出现平假名，有可能是受到上游的processor的影响，可以试着把这个speller的顺序往前调整

  engine/translators/+:
    - lua_translator@*kagiroi/kagiroi_translator #kagiroi的主要translator，负责把平假名转换成候选
  kagiroi:
    prefix: ok # 引导前缀，可修改，如有修改，下面的pattern也需要同步改
    tips: 〔火光〕 # 提示符，可修改
    tag: kagiroi
    layout: romaji # 布局，可选 romaji/kana 或者自定义一个布局
    speller:
      __include: kagiroi:/alphabet/3_dan # 罗马字布局需要用到3段式键盘，如果是kana布局，需要使用4段式 kagiroi:/alphabet/4_dan

  # 标记kagiroi段落的正则表达式
  recognizer/patterns/kagiroi: '(^ok[ょあいうえおかきくけこがぎぐげごさしすせそざじずぜぞたちつてとだぢづでどなにぬねのはひふへほばびぶべぼぱぴぷぺぽまみむめもやゆよらりるれろわゐ𛄟ゑをんゃっゕゖーゅabcdefghijklmnopqrstuvwxyz\-;]*$)'
  # 由于kagiroi在speller里将用户输入的字母转换成了平假名，所以这里需要将平假名放到alphabet里面，否则kagiroi将无法正常工作
  speller/alphabet: ょあいうえおかきくけこがぎぐげごさしすせそざじずぜぞたちつてとだぢづでどなにぬねのはひふへほばびぶべぼぱぴぷぺぽまみむめもやゆよらりるれろわゐ𛄟ゑをんゃっゕゖーゅabcdefghijklmnopqrstuvwxyz-ABCDEFGHIJKLMNOPQRSTUVWXYZ/;
  # 长音的输入
  # 可以使用 `q` 或者 `-` 输入长音，使用 `-` 时需要修改 `-` 的翻页功能
  # 在 `key_bindings.yaml` 里找到 `- { when: has_menu, accept: minus, send: Page_Up }` 将 `has_menu` 改为 `paging`
  # 或在 `key_bindings.custom.yaml` 通过 patch 方式修改（推荐）

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
