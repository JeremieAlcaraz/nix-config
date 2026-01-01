CC ?= /usr/bin/clang

bin/menus: menus.c | bin
	$(CC) -std=c99 -O3 -F/System/Library/PrivateFrameworks/ -framework Carbon -framework SkyLight $< -o $@

bin:
	mkdir bin
