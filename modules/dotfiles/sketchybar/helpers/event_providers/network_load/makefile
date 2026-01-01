CC ?= /usr/bin/clang

bin/network_load: network_load.c network.h ../sketchybar.h | bin
	$(CC) -std=c99 -O3 $< -o $@

bin:
	mkdir bin
