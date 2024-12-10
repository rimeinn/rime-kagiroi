.PHONY: update_mozc build install clean

MATRIX_DEF = matrix.def
LEX_CSV = lex.csv

all: install

install: clean build

build: update_mozc $(MATRIX_DEF) $(LEX_CSV)

update_mozc:
	[ -d mozc ] && ( cd mozc ; git pull ) || git clone https://github.com/google/mozc/

clean:
	$(RM) lua/kagiroi/dic/*
	$(RM) lua/kagiroi/dic.userdb/*

$(MATRIX_DEF):
	./tools/generate_matrix_def.py

$(LEX_CSV):
	cat mozc/src/data/dictionary_oss/dictionary*.txt | tr "\\t" "," | grep -v "^," > lua/kagiroi/dic/lex.csv
