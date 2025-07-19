.PHONY: update_mozc build install clean

MATRIX_DEF = matrix.def
LEX_CSV = lex.csv

all: install

install: clean build

build: update_mozc nico_pixiv $(MATRIX_DEF) $(LEX_CSV) nico_pixiv

update_mozc:
	[ -d mozc ] && ( cd mozc ; git pull ) || git clone https://github.com/google/mozc/

clean:
	$(RM) lua/kagiroi/dic/*
	$(RM) lua/kagiroi/dic.userdb/*

$(MATRIX_DEF):
	./tools/generate_matrix_def.py

$(LEX_CSV):
	cat mozc/src/data/dictionary_oss/dictionary*.txt | tr "\\t" "," | grep -v "^," > lua/kagiroi/dic/lex.csv
	cat lua/kagiroi/dic/dictionary*.txt | python3 tools/convert_jisho.py mozc/src/data/dictionary_oss/id.def 8000 | tr "\\t" "," | grep -v "^," >> lua/kagiroi/dic/lex.csv

nico_pixiv:
	curl -o lua/kagiroi/dic/dictionary-nico-intersection-pixiv-google.txt https://raw.githubusercontent.com/ncaq/dic-nico-intersection-pixiv/master/public/dic-nico-intersection-pixiv-google.txt