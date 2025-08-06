#
# Dictionary Kagiroi Makefile
#

.PHONY: all build clean install update_mozc

# ==============================================================================
# Variables
# ==============================================================================

SHELL := /bin/bash
RM := rm -f

# Output Dictionaries
MOZC_DICT := kagiroi.mozc.dict.yaml
NICO_DICT := kagiroi.nico.dict.yaml
MATRIX_DICT := kagiroi_matrix.dict.yaml
EMOJI_DICT := opencc/kagiroi_emoji.txt

# Versioning
CURRENT_DATE := $(shell date +%Y%m%d)

# ==============================================================================
# Dictionary Headers
# ==============================================================================

# Generic header template for dictionaries
define GENERIC_DICT_HEADER
# Rime dictionary
# encoding: utf-8
# $(3)
# $(1)
---
name: $(2)
version: $(CURRENT_DATE)
sort: by_weight
use_preset_vocabulary: false
...

#nocomment
endef

# Specific headers for each dictionary
MOZC_DICT_HEADER := $(call GENERIC_DICT_HEADER,Dictionary mozc,kagiroi.mozc,license: see LICENSE)
NICO_DICT_HEADER := $(call GENERIC_DICT_HEADER,Dictionary ニコニコ大百科,kagiroi.nico,source: https://tkido.com/blog/1019.html)
MATRIX_DICT_HEADER := $(call GENERIC_DICT_HEADER,Connection data from mozc,kagiroi_matrix,license: see LICENSE)

# Export headers to be available in subshells
export MOZC_DICT_HEADER NICO_DICT_HEADER MATRIX_DICT_HEADER

# ==============================================================================
# Main Targets
# ==============================================================================

all: install

install: build
	@echo "Done."

build: $(MOZC_DICT) $(NICO_DICT) $(MATRIX_DICT) $(EMOJI_DICT)
	@echo "All dictionaries have been built."

clean:
	@echo "Cleaning up generated files..."
	$(RM) -f $(MOZC_DICT) $(NICO_DICT) $(MATRIX_DICT) $(EMOJI_DICT)
	$(RM) -rf .temp
	@if [ -d lua/kagiroi/dic.userdb ]; then $(RM) -r lua/kagiroi/dic.userdb; fi

# ==============================================================================
# File Generation Rules
# ==============================================================================

# Clones or updates the mozc repository
update_mozc:
	@if [ -d mozc ]; then \
		echo "Updating mozc repository..."; \
		(cd mozc ; git pull --quiet); \
	else \
		echo "Cloning mozc repository..."; \
		git clone --depth 1 --quiet https://github.com/google/mozc/; \
	fi

# Generates the main dictionary from mozc data
$(MOZC_DICT): update_mozc
	@printf '%s\n' "$$MOZC_DICT_HEADER" > $@
	@( \
		cat mozc/src/data/dictionary_oss/dictionary*.txt | tr '\t' ',' | grep -v '^,'; \
	) | \
	if [ -f lua/kagiroi/dic/lex_excluded.csv ]; then \
		grep -v -x -f lua/kagiroi/dic/lex_excluded.csv; \
	else \
		cat; \
	fi | \
	awk -F',' 'NF>=5 {print $$5"|"$$2" "$$3"\t"$$1"\t"$$4}' >> $@

# Generates the Nico Nico dictionary
$(NICO_DICT): update_mozc
	@printf '%s\n' "$$NICO_DICT_HEADER" > $@
	@mkdir -p .temp
	@echo "Downloading and processing ニコニコ大百科..."
	@curl -L -s -o .temp/nicoime.zip http://tkido.com/nicoime/nicoime.zip
	@( \
		cd .temp && \
		unzip -o -q nicoime.zip && \
		iconv -f UTF-16LE -t UTF-8 nicoime_msime.txt \
	) | \
		awk -F'\t' 'BEGIN{OFS="\t"} {gsub("ヴ", "ゔ", $$1); print}' | \
		poetry run tools/filter_nico_dictionary.py | \
		poetry run tools/convert_jisho.py mozc/src/data/dictionary_oss/id.def 8000 | \
		tr '\t' ',' | \
		grep -v '^,' | \
	if [ -f lua/kagiroi/dic/lex_excluded.csv ]; then \
		grep -v -x -f lua/kagiroi/dic/lex_excluded.csv; \
	else \
		cat; \
	fi | \
		awk -F',' 'NF>=5 {print $$5"|"$$2" "$$3"\t"$$1"\t"$$4}' >> $@
	@$(RM) -r .temp

# Generates the matrix dictionary
$(MATRIX_DICT):
	@printf '%s\n' "$$MATRIX_DICT_HEADER" > $@
	@( \
		poetry run ./tools/generate_matrix_def.py; \
		poetry run ./tools/prefix_suffix_penalty.py; \
		cat lua/kagiroi/dic/matrix_custom.def \
	) | awk '{print $$1" "$$2"\t"$$3}' >> $@

# Generates the emoji dictionary
$(EMOJI_DICT): update_mozc
	@echo "Generating emoji dictionary..."
	@mkdir -p opencc
	@awk -F'\t' 'BEGIN{OFS="\t"} NF>=3 && $$2!="" { \
		if ($$3 != "") { \
			split($$3, readings, " "); \
			for (i in readings) { \
				if (readings[i] != "") { \
					if (dict[readings[i]]) { \
						dict[readings[i]] = dict[readings[i]] " " $$2; \
					} else { \
						dict[readings[i]] = $$2; \
					} \
				} \
			} \
		} \
		if (NF>=6 && $$6 != "") { \
			split($$6, descriptions, " "); \
			for (i in descriptions) { \
				if (descriptions[i] != "") { \
					if (dict[descriptions[i]]) { \
						dict[descriptions[i]] = dict[descriptions[i]] " " $$2; \
					} else { \
						dict[descriptions[i]] = $$2; \
					} \
				} \
			} \
		} \
	} END { \
		for (name in dict) { \
			print name "\t" name " " dict[name]; \
		} \
	}' mozc/src/data/emoji/emoji_data.tsv > $@
.DEFAULT_GOAL := all
