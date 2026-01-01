CC ?= /usr/bin/clang

bin/cpu_load: cpu_load.c cpu.h ../sketchybar.h | bin
	$(CC) -std=c99 -O3 $< -o $@

bin:
	mkdir bin
