.PHONY: update_mozc build install clean

MATRIX_DEF = matrix.def
LEX_CSV = lex.csv

all: install

install: clean build

build: update_mozc nico $(MATRIX_DEF) $(LEX_CSV)

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

nico:
	rm -r .temp
	mkdir -p .temp
	curl -L -o .temp/nicoime.zip http://tkido.com/nicoime/nicoime.zip
	cd .temp && unzip -o nicoime.zip
	iconv -f UTF-16LE -t UTF-8 .temp/nicoime_msime.txt > lua/kagiroi/dic/dictionary_nico.txt
	