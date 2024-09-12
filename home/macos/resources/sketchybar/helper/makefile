whoami := $(shell whoami)

helper: helper.c cpu.h sketchybar.h
	clang -std=c99 -O3 helper.c -o /tmp/.$(whoami)_sketchybar_helper
