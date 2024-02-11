# Assert variable / set default value if not set
check_variable = $(if $(value $(1)),, $(error $(1) not defined))
default_variable = $(if $(value $(1)),, $(eval $(1) = $(2)))

# Recursive search
rwildcard=$(foreach d,$(wildcard $(1:=/*)),$(call rwildcard,$d,$2) $(filter $(subst *,%,$2),$d))

# Colorful text Win/Lin
color_text = $(if $(filter Windows_NT, $(OS)),"[$(1)m$(2)[0m","\\033[$(1)m$(2)\\033[0m")

# Variables checking, setting defaults
$(call check_variable ,OUT_FILE)
$(call default_variable ,SRC_DIRS,src)
$(call default_variable ,MODULES_DIRS,modules)
$(call default_variable ,INCLUDE_DIRS,. include)
$(call default_variable ,OBJ_PATH,obj)
$(call default_variable ,SRC_EXTS,*.cpp *.c)
$(call default_variable ,COMPILER,g++)
$(call default_variable ,AR,ar)
$(call default_variable ,CFLAGS,-O3)
$(call default_variable ,AR_FLAGS,rcs)

LIB_DIRS 		:= $(addprefix -L, $(LIB_DIRS))
INCLUDE_DIRS 	:= $(addprefix -I, $(INCLUDE_DIRS))
LIBS 			:= $(addprefix -l, $(LIBS))

ifneq (, $(shell which pkg-config))
INCLUDE_DIRS    += $(shell pkg-config --cflags $(PKG_SEARCH))
LIBS 			+= $(shell pkg-config --libs-only-l $(PKG_SEARCH))
LIB_DIRS 		+= $(shell pkg-config --libs-only-L $(PKG_SEARCH))
else
ifneq ("$(PKG_SEARCH)","")
$(error PKG_SEARCH present, but pkg-config not found!)
endif
endif

# Project files
SOURCES += $(foreach dr, $(SRC_DIRS), $(foreach ext, $(SRC_EXTS),  $(call rwildcard,$(dr),$(ext))))
SOURCES := $(filter-out $(EXCLUDESRC),$(SOURCES))
OBJECTS = $(foreach src, $(SOURCES),$(OBJ_PATH)/$(basename $(src)).o)
DEPS    = $(OBJECTS:%.o=%.d)

# Modules
MODULES += $(foreach dr, $(MODULES_DIRS), $(call rwildcard,$(dr),*.ccm))
PRECOMPILED_MODULES = $(foreach mod, $(MODULES), $(OBJ_PATH)/$(basename $(mod)).pcm)

# Making directories
$(shell mkdir -p $(dir $(OUT_FILE)) 2> /dev/null)
$(shell mkdir -p $(dir $(OBJECTS)) 2> /dev/null)
$(shell mkdir -p $(dir $(DEPS)) 2> /dev/null)
$(shell mkdir -p $(dir $(PRECOMPILED_MODULES)) 2> /dev/null)

DEPFLAGS 	= -MT $@ -MD -MP -MF $(OBJ_PATH)/$*.Td
POSTCOMPILE += mv -f $(OBJ_PATH)/$*.Td $(OBJ_PATH)/$*.d 2>/dev/null

CMD.COMPILE_C   	= $(COMPILER) $(DEPFLAGS) $(CFLAGS) $(INCLUDE_DIRS) -c -o $@ $< 
CMD.COMPILE_CCM   	= $(COMPILER) --precompile $(DEPFLAGS) $(CFLAGS) $(INCLUDE_DIRS) -c -o $@ $< 
CMD.LINK_SHARED		= $(COMPILER) -shared $(LIB_DIRS) $(LINK_FLAGS) $(PRECOMPILED_MODULES) $(OBJECTS) -o $@ $(LIBS)
CMD.LINK_STATIC		= $(AR) $(AR_FLAGS) $(LIB_DIRS) $@ $(PRECOMPILED_MODULES) $(OBJECTS) $(LIBS)
CMD.LINK_EXEC		= $(COMPILER) $(LINK_FLAGS) $(LIB_DIRS) $(PRECOMPILED_MODULES) $(OBJECTS) -o $@ $(LIBS)

COMPILE.c 		= @echo $(call color_text,94,Building): $@ ; $(PRECOMPILE) $(CMD.COMPILE_C) ; $(POSTCOMPILE)
COMPILE.cc 		= $(COMPILE.c)
COMPILE.ccm 	= @echo $(call color_text,95,Module): $@ ; $(PRECOMPILE) $(CMD.COMPILE_CCM) ; $(POSTCOMPILE)
LINK.shared 	= @echo $(call color_text,33,Linking shared): $@ ; $(PRELINK) $(CMD.LINK_SHARED) ; $(POSTLINK)
LINK.static 	= @echo $(call color_text,33,Linking static): $@ ; $(PRELINK) $(CMD.LINK_STATIC) ; $(POSTLINK)
LINK.executable = @echo $(call color_text,32,Linking executable): $@ ; $(PRELINK) $(CMD.LINK_EXEC) ; $(POSTLINK)

# always run multithread
MAKEFLAGS += -j

# Artificial targets
.PHONY: all app clean cleanall test run release

all: subprojects.all .WAIT app

name:
	@echo $(OUT_FILE)

app: $(OUT_FILE)

run: app
	@$(OUT_FILE)

release: app
	$(RELEASE_COMMAND)

clean:
	@rm -rf ./$(OBJ_PATH)

cleanall: clean subprojects.cleanall
	@rm -rf ./$(OUT_FILE)
	@rm -rf ./release
	@rm -rf ./$(dir $(OUT_FILE))

subprojects.%:
	@$(SUBPROJECTS:%=$(MAKE) --no-print-directory -e -C % $* COMMON_MK_PATH=$(COMMON_MK_PATH);)

$(basename $(OUT_FILE)): $(PRECOMPILED_MODULES) $(OBJECTS)
	$(LINK.executable)

lib%.a: $(OBJECTS)
	$(LINK.static)

%.so %.dll: $(OBJECTS)
	$(LINK.shared)

$(OBJ_PATH)/%.o: %.c
	$(COMPILE.c)

$(OBJ_PATH)/%.o: %.cpp $(PRECOMPILED_MODULES)
	$(COMPILE.cc)

$(OBJ_PATH)/%.o: %.cc $(PRECOMPILED_MODULES)
	$(COMPILE.cc)

$(OBJ_PATH)/%.pcm: %.ccm
	$(COMPILE.ccm)

# Do not delete intermediate files
.PRECIOUS: $(OBJ_PATH)/%.d $(OBJ_PATH)/%.pcm
$(OBJ_PATH)/%.d: ;
$(OBJ_PATH)/%.pcm: ;

# Include all dependecy files for recompile on changing one of them
-include $(DEPS)
