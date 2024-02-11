# MaPr v.0.5

(Ma)ke (Pr)oject - GCC/clang project building system. 

For simple and complex projects with subprojects in it. 

# Features
- Pass any commands to subprojects: `clean`, `all`... and to its subprojects and so on.
- Detects build type by name. (library, shared library, executable)
- Find sources recursive
- Add and exclude sertain sources

# Quick start
Create `src/main.c` and `Makefile` with this content and run `make`
```Makefile
OUT_FILE        = bin/bin-name

#-----------FOOTER-----------

COMMON_MK_PATH = $(CURDIR)/mapr/common.mk
ifeq ("$(wildcard $(COMMON_MK_PATH))","")
download:
	@git clone https://github.com/AIG-Livny/mapr.git
	$(MAKE)
endif

-include $(COMMON_MK_PATH) 
```

If `mapr` doesn't exist it will be downloaded. 
For subprojects need to create same makefile, but when make started from main directory, subprojects will not download mapr copy. All subprojects will use the main `mapr`. This scheme was made for building any subproject separately. Only when you `cd` into any subproject and run `make` will be downloaded new mapr copy. By return to main directory, the main `mapr` engages again.

# Usage
All configurations of project must be in Makefile, not in `mapr/common.mk`.

## Variables list
Almost all variables is optional, except `OUT_FILE`. In bracets default value if exists.

- `OUT_FILE` - name of out file. Name and extension defines type of file:
 	- executable: without extension or `.exe`
	- static library:	`lib%.a`
	- dynamic library:	`%.dll` or `%.so`

- `PKG_SEARCH` - libraries to search in `pkg-config` and add flags 

- `COMPILER` - (g++) - compiler binary

- `SUBPROJECTS` - list of directories where subprojects's `Makefile`'s contains. Example:
    ```
    SUBPROJECTS += lib/somesublib
    SUBPROJECTS += lib/anothersublib
    ```
    All subprojects recieves command via `subprojects.` prefix.
    ```
    make subproject.all
    make subproject.clean
    ```
    Will pass `all` and `clean` commands.

- `LIB_DIRS` - list directories where looking for libraries. Search is not recursive.

- `INC_DIRS` - (include) - list directories where looking for headers. Search is not recursive.

- `SRC_DIRS` - (src) - list directories where looking for sources. Search is recursive (`!`).

- `OBJ_PATH` - (obj) - where to store object files.

- `SRC_EXTS` - (*.cpp *.c) - source extensions

- `LINK_FLAGS` - link stage flags

- `CFLAGS` - (-O3) - compile stage flags

- `SOURCES` - list of source files. Can be used to specify files that can not be found by recursive search. In example: sertain source file from other project, without any excess sources.

- `LIBS` - list of libraries to link.

- `MODULES_DIRS` - list of clang modules directories

- `MODULES` - list of clang modules. Same as `SOURCES` variable

- `AR_FLAGS` - archivier flags

- `EXCLUDESRC` - list of sources exclusions

- `PRELINK` - command be executed before linking

- `POSTLINK` - command be executed after linking

- `RELEASE_COMMAND` - executed on `make release`

# Makefile example of project

```Makefile
OUT_FILE        = bin/myproject

COMPILER 		= clang++

CFLAGS			= -g -O0 -std=c++20 
CFLAGS			+= -DDEBUG
LINK_FLAGS 		= -stdlib=libstdc++

INCLUDE_DIRS    += include
INCLUDE_DIRS    += lib/imgui/include

LIB_DIRS        += /usr/lib/x86_64-linux-gnu
LIB_DIRS        += lib/imgui/bin

PKG_SEARCH      += glfw3
PKG_SEARCH      += glew

LIBS            += imgui

SUBPROJECTS		+= lib/imgui

# New size print
PRELINK		= mv $(OUT_FILE) $(OUT_FILE)_old 2> /dev/null ;
POSTLINK	= ./size.sh $(OUT_FILE) $(OUT_FILE)_old ; rm -f $(OUT_FILE)_old

#-----------FOOTER-----------

COMMON_MK_PATH = $(CURDIR)/mapr/common.mk
ifeq ("$(wildcard $(COMMON_MK_PATH))","")
download:
	@git clone https://github.com/AIG-Livny/mapr.git
	$(MAKE)
endif

-include $(COMMON_MK_PATH) 
```