.PHONY: update_mozc build install clean

MATRIX_DEF = matrix.def
LEX_CSV = lex.csv

all: install

install: clean build

build: update_mozc nico $(MATRIX_DEF) $(LEX_CSV)

update_mozc:
	[ -d mozc ] && ( cd mozc ; git pull ) || git clone https://github.com/google/mozc/

clean:
	$(RM) lua/kagiroi/dic.userdb/*

$(MATRIX_DEF):
	./tools/generate_matrix_def.py
	./tools/prefix_suffix_penalty.py >> lua/kagiroi/dic/matrix.def
	cat lua/kagiroi/dic/matrix_custom.def >> lua/kagiroi/dic/matrix.def

$(LEX_CSV):
	cat mozc/src/data/dictionary_oss/dictionary*.txt | tr "\\t" "," | grep -v "^," > lua/kagiroi/dic/lex.csv
	cat lua/kagiroi/dic/dictionary*.txt | python3 tools/convert_jisho.py mozc/src/data/dictionary_oss/id.def 8000 | tr "\\t" "," | grep -v "^," >> lua/kagiroi/dic/lex.csv
	if [ -f lua/kagiroi/dic/lex_excluded.csv ]; then grep -v -x -f lua/kagiroi/dic/lex_excluded.csv lua/kagiroi/dic/lex.csv > lua/kagiroi/dic/lex.csv.tmp && mv lua/kagiroi/dic/lex.csv.tmp lua/kagiroi/dic/lex.csv; fi

nico:
	rm -r .temp
	mkdir -p .temp
	curl -L -o .temp/nicoime.zip http://tkido.com/nicoime/nicoime.zip
	cd .temp && unzip -o nicoime.zip
	iconv -f UTF-16LE -t UTF-8 .temp/nicoime_msime.txt > lua/kagiroi/dic/dictionary_nico.txt
	