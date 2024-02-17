# MaPr v.0.8

(Ma)ke (Pr)oject - GCC/clang project building system. 

For simple and complex projects with subprojects in it. 

# Quick start
Create `src/main.c` and `Makefile` with this content and run `make`
```Makefile
OUT_FILE        = bin-name

#-----------FOOTER-----------

COMMON_MK_PATH = $(CURDIR)/mapr/common.mk
ifeq ("$(wildcard $(COMMON_MK_PATH))","")
%:
	@git clone https://github.com/AIG-Livny/mapr.git
	$(MAKE) $(MAKECMDGOALS)
endif

-include $(COMMON_MK_PATH) 
```

# Features
- Pass any commands to subprojects: `clean`, `all`... and to its subprojects and so on.
- Detects build type by name. (library, shared library, executable)
- Find sources recursive
- Add and exclude sertain sources
- Store object files in one directory and support "../" - paths. Resolves "../mydir" as "obj/mydir"
- Find and automatically use libraries with `pkg-config`

If `mapr` doesn't exist it will be downloaded. 
For subprojects need to create same makefile, but when make started from main directory, subprojects will not download mapr copy. All subprojects will use the main `mapr`. This scheme was made for building any subproject separately. Only when you `cd` into any subproject and run `make` will be downloaded new mapr copy. By returning to main directory, the main `mapr` engages again.

# Usage
All configurations of project must be in Makefile, not in `mapr/common.mk`.

There is debug feature to print messages to log `mapr/debug.log`. Add `DEBUG = 1` into Makefile to enable debug mode.

`mapr` directory is recomended to place in `.gitignore` 

## Variables list
Almost all variables is optional, except `OUT_FILE`. In bracets default value if exists.

- `OUT_FILE` - name of out file. Name and extension defines type of file:
 	- executable: without extension or `.exe`
	- static library:	`lib%.a`
	- dynamic library:	`%.dll` or `%.so`

- `PKG_SEARCH` - libraries to search in `pkg-config` and add flags 

- `COMPILER` - (g++) - compiler, global variable, come from main project

- `LOCAL_COMPILER` - (COMPILER) - be used if present ignoring COMPILER var. 

- `SUBPROJECTS` - list of directories where subprojects's `Makefile`'s contains. Example:
    ```
    SUBPROJECTS += lib/somesublib
    SUBPROJECTS += lib/anothersublib
    ```
    All subprojects recieves command via `subprojects.` prefix.
    ```
    make subprojects.all
    make subprojects.clean
    ```
    Will pass `all` and `clean` commands.

- `SUBPROJECT_LIBS` - list of subproject libs directories. This is subset of SUBPROJECTS, but it made for static libs. MaPr will automaticaly obtain '-I', '-L', '-l' options from each project.
    
    This line:
    ```
    SUBPROJECT_LIBS	+= lib/mathc
    ```
    is equivalent of this:
    ```
    SUBPROJECTS 	+= lib/mathc
    INCLUDE_DIRS 	+= lib/mathc/mathc
    LIB_DIRS 		+= lib/mathc/bin
    LIBS 	 		+= mathc
    ```

- `SRC_DIRS` - (src) - list directories where looking for sources 

- `SRC_RECURSIVE_DIRS` - list directories where starts recursive search of sources

- `SRC_EXTS` - (*.cpp *.c) - source extensions

- `INCLUDE_DIRS` - (SRC_DIRS) - list directories where looking for headers

- `EXPORT_INCLUDE_DIRS` - (INCLUDE_DIRS) - if specified upper project will get only these directories automatically. This variable is for dividing private and public includes.

- `EXPORT_DEFINITIONS` - list of definitions that will be sended to upper project. In example: you have library with `#ifdef` statements, you configure and build library as independent project. When upper project will include `.h`, he will not to know about any definitions that was used during building library, so `EXPORT_DEFINITIONS` can pass them up. These definitions also used in building project itself.

- `LIB_DIRS` - list directories where looking for libraries

- `OBJ_PATH` - (obj) - where to store object files.

- `LINK_FLAGS` - link stage flags

- `CFLAGS` - (-O3) - compile stage flags. It is global variable that be passed to subprojects and rewrite local `CFLAGS` variable. To use private flags see `LOCAL_CFLAGS`

- `LOCAL_CFLAGS` - compile stage flags. These flags affects on only local project and not will passed into subprojects.

- `SOURCES` - list of source files. Can be used to specify files that can not be found by recursive search. In example: sertain source file from other project, without any excess sources.

- `LIBS` - list of libraries to link.

- `MODULES_DIRS` - list of clang modules directories

- `MODULES` - list of clang modules. Same as `SOURCES` variable

- `AR` - archiver

- `AR_FLAGS` - archivier flags

- `EXCLUDESRC` - list of sources exclusions

- `PRELINK` - command be executed before linking

- `PRECOMPILE` - command be executed before compile

- `POSTLINK` - command be executed after linking. Must start with ";" or "&&" because it be appended to command line

- `POSTCOMPILE` - command be executed after compile. Requirement same as previous 

- `RELEASE_COMMAND` - executed on `make release`

# Third-party libraries
Any third-party library can be placed into subdirectory, it doesn't change original files and thus replaces its build system.
```
___mapr
___lib
   |___somelib
       |___somelib  (original lib folder)
       |
       |___bin
       |   |___binary of lib, builded by mapr
       |
       |___Makefile
``` 
or even:
```
___mapr
___lib
   |___third-party
   |   |___somelib  (original lib folder)
   |
   |___somelib 
       |___bin
       |   |___binary of lib, builded by mapr
       |
       |___Makefile
```

# Makefile example

```Makefile
OUT_FILE        = bin/myproject

COMPILER 		= clang++

CFLAGS			= -g -O0 -std=c++20 
CFLAGS			+= -DDEBUG
LINK_FLAGS 		= -stdlib=libstdc++

SUBPROJECT_LIBS += lib/imgui

PKG_SEARCH      += glfw3
PKG_SEARCH      += glew

# New size print
PRELINK		= mv $(OUT_FILE) $(OUT_FILE)_old 2> /dev/null ;
POSTLINK	= ; ./size.sh $(OUT_FILE) $(OUT_FILE)_old ; rm -f $(OUT_FILE)_old

#-----------FOOTER-----------

COMMON_MK_PATH = $(CURDIR)/mapr/common.mk
ifeq ("$(wildcard $(COMMON_MK_PATH))","")
%:
	@git clone https://github.com/AIG-Livny/mapr.git
	$(MAKE) $(MAKECMDGOALS)
endif

-include $(COMMON_MK_PATH) 
```