#
#	MaPr - (ma)ke (pr)oject build system
#	AIG <AIG.Livny@gmail.com>  
#

# always run multithread
MAKEFLAGS += -j

# no built-in rules
MAKEFLAGS += -r

# Assert variable / set default value if not set
check_variable = $(if $(value $(1)),, $(error $(1) not defined))
default_variable = $(if $(value $(1)),, $(eval $(1) = $(2)))

# Recursive search
rwildcard=$(foreach d,$(wildcard $(1:=/*)),$(call rwildcard,$d,$2) $(filter $(subst *,%,$2),$d))

# Colorful text Win/Lin
ifneq ("$(filter Windows_NT, $(OS)"),"")
color_text = "[$(1)m$(2)[0m"
else
color_text = "\\033[$(1)m$(2)\\033[0m"
endif

# Variables checking, setting defaults
$(call check_variable ,OUT_FILE)
$(call default_variable ,SRC_DIRS,src)
$(call default_variable ,MODULES_DIRS,modules)
$(call default_variable ,INCLUDE_DIRS,$(SRC_DIRS))
$(call default_variable ,EXPORT_INCLUDE_DIRS,$(INCLUDE_DIRS))
$(call default_variable ,OBJ_PATH,obj)
$(call default_variable ,SRC_EXTS,*.cpp *.c)
$(call default_variable ,COMPILER,g++)
$(call default_variable ,LOCAL_COMPILER,$(COMPILER))
$(call default_variable ,CFLAGS,-O3)
$(call default_variable ,AR_FLAGS,rcs)

LIB_DIRS 		:= $(addprefix -L, $(LIB_DIRS))
INCLUDE_DIRS 	:= $(addprefix -I, $(INCLUDE_DIRS))
LIBS 			:= $(addprefix -l, $(LIBS))

ifneq ("$(PKG_SEARCH)","")
ifneq (, $(shell which pkg-config))
ALL_FLAGS = $(shell pkg-config --cflags --libs $(PKG_SEARCH) 2>&1)

ifneq (,$(findstring No package,$(ALL_FLAGS)))
    $(error LIBRARY NOT FOUND \n $(ALL_FLAGS))
endif

INCLUDE_DIRS    += $(filter -I%, $(ALL_FLAGS))
LIBS    		+= $(filter -l%, $(ALL_FLAGS))
LIB_DIRS    	+= $(filter -L%, $(ALL_FLAGS))

else
$(error PKG_SEARCH present, but pkg-config not found!)
endif
endif

#Sub make options
SP_OPTIONS += --no-print-directory -e -s
SP_OPTIONS += DEBUG=$(DEBUG)
SP_OPTIONS += COMMON_MK_PATH=$(COMMON_MK_PATH)
SP_OPTIONS += COMPILER=$(COMPILER)
SP_OPTIONS += CFLAGS="$(CFLAGS)"

## Automatic obtain options from subproject libraries
ifdef SUBPROJECT_LIBS
ALL_VARS = $(foreach sp,$(SUBPROJECT_LIBS),$(shell $(MAKE) $(SP_OPTIONS) -C $(sp) vars))
SP_TARGETS 		+= $(subst NAM.,, $(filter NAM.%, $(ALL_VARS)))
SP_INCLUDE_DIRS += $(subst INC.,-I, $(filter INC.%, $(ALL_VARS)))
SP_LIB_DIRS 	+= $(subst LDR.,-L, $(filter LDR.%, $(ALL_VARS)))
SP_LIBS			+= $(subst LIB.,-l, $(filter LIB.%, $(ALL_VARS)))
SP_OBJECTS 		+= $(subst OBJ.,, $(filter OBJ.%, $(ALL_VARS)))
LOCAL_CFLAGS	+= $(subst EXD.,-D, $(filter EXD.%, $(ALL_VARS)))

SUBPROJECTS += $(SUBPROJECT_LIBS)
endif

# Add export defs to our target too
LOCAL_CFLAGS += $(addprefix -D,$(EXPORT_DEFINITIONS))

# Project files
SOURCES += $(foreach dr,$(SRC_RECURSIVE_DIRS),$(foreach ext,$(SRC_EXTS),$(call rwildcard,$(dr),$(ext))))
SOURCES += $(foreach dr,$(SRC_DIRS),$(foreach ext,$(SRC_EXTS),$(wildcard $(dr)/$(ext))))
SOURCES := $(filter-out $(EXCLUDESRC),$(SOURCES))
OBJECTS = $(foreach src, $(SOURCES),$(OBJ_PATH)/$(subst ../,,$(basename $(src))).o)
DEPS    = $(OBJECTS:%.o=%.d)

# Modules
MODULES += $(foreach dr, $(MODULES_DIRS), $(call rwildcard,$(dr),*.ccm))
PRECOMPILED_MODULES = $(foreach mod, $(MODULES), $(OBJ_PATH)/$(subst ../,,$(basename $(mod))).pcm)

DEPFLAGS 	= -MT $@ -MD -MP -MF $*.Td
POSTCOMPILE += && mv -f $*.Td $*.d 2>/dev/null

CMD.COMPILE_C   	= $(LOCAL_COMPILER) $(DEPFLAGS) $(CFLAGS) $(LOCAL_CFLAGS) $(INCLUDE_DIRS) $(SP_INCLUDE_DIRS) -c -o $@ $< 
CMD.COMPILE_CCM   	= $(LOCAL_COMPILER) --precompile $(DEPFLAGS) $(CFLAGS) $(LOCAL_CFLAGS) $(INCLUDE_DIRS) $(SP_INCLUDE_DIRS) -c -o $@ $< 
CMD.LINK_SHARED		= $(LOCAL_COMPILER) -shared $(LIB_DIRS) $(SP_LIB_DIRS) $(LINK_FLAGS) $(PRECOMPILED_MODULES) $(OBJECTS) -o $@ $(LIBS) $(SP_LIBS)
CMD.LINK_STATIC		= $(AR) $(AR_FLAGS) $@ $(PRECOMPILED_MODULES) $(OBJECTS) $(SP_OBJECTS)
CMD.LINK_EXEC		= $(LOCAL_COMPILER) $(LINK_FLAGS) $(LIB_DIRS) $(SP_LIB_DIRS) $(PRECOMPILED_MODULES) $(OBJECTS) -o $@ $(LIBS) $(SP_LIBS)

COMPILE.c 		= @echo $(call color_text,94,Building): $@ ; $(PRECOMPILE) $(CMD.COMPILE_C) $(POSTCOMPILE)
COMPILE.cc 		= $(COMPILE.c)
COMPILE.ccm 	= @echo $(call color_text,95,Module): $@ ; $(PRECOMPILE) $(CMD.COMPILE_CCM) $(POSTCOMPILE)
LINK.shared 	= @echo $(call color_text,33,Linking shared): $@ ; $(PRELINK) $(CMD.LINK_SHARED) $(POSTLINK)
LINK.static 	= @echo $(call color_text,33,Linking static): $@ ; $(PRELINK) $(CMD.LINK_STATIC) $(POSTLINK)
LINK.executable = @echo $(call color_text,32,Linking executable): $@ ; $(PRELINK) $(CMD.LINK_EXEC) $(POSTLINK)

# Print debug information to mapr/debug.log
ifdef DEBUG
$(shell echo OUT_FILE=$(OUT_FILE): \
MAKECMDGOALS=$(MAKECMDGOALS) \
SP_TARGETS=$(SP_TARGETS) \
SUBPROJECTS=$(SUBPROJECTS) \
ALL_VARS=$(ALL_VARS) \
EXPORT_DEFINITIONS=$(EXPORT_DEFINITIONS) \
LOCAL_CFLAGS=$(LOCAL_CFLAGS) \
>> $(dir $(COMMON_MK_PATH))/debug.log)
endif #DEBUG

# Artificial targets
.PHONY: all app clean cleanall test run release compile makedirs $(SUBPROJECTS)

all: $(SUBPROJECTS) makedirs .WAIT $(OUT_FILE)

makedirs:
	$(shell mkdir -p $(dir $(OUT_FILE)) 2> /dev/null)
	$(shell mkdir -p $(dir $(OBJECTS)) 2> /dev/null)
	$(shell mkdir -p $(dir $(DEPS)) 2> /dev/null)
	$(shell mkdir -p $(dir $(PRECOMPILED_MODULES)) 2> /dev/null)

run: all
	@$(OUT_FILE)

release: all
	$(RELEASE_COMMAND)

clean: subprojects.clean subprojects.cleanmapr
	@rm -rf ./$(OBJ_PATH)

cleanmapr:
	@rm -rf ./mapr

cleanall: clean subprojects.cleanall .WAIT cleanmapr
ifneq ("$(dir $(OUT_FILE))","./")
	@rm -rf $(dir $(OUT_FILE))
else
	@rm -f $(OUT_FILE)
endif
	@rm -rf ./release

name:
	@echo $(abspath $(OUT_FILE))

# Return variables to use in upper level project
vars:
	@echo \
$(addprefix INC., $(abspath $(EXPORT_INCLUDE_DIRS))) \
$(addprefix OBJ., $(abspath $(OBJECTS))) \
LDR.$(dir $(abspath $(OUT_FILE))) \
NAM.$(abspath $(OUT_FILE)) \
LIB.$(notdir $(subst .a,,$(subst lib,,$(OUT_FILE)))) \
$(addprefix EXD.,$(EXPORT_DEFINITIONS))

# Target to call targets in subs
subprojects.%:
	@$(SUBPROJECTS:%=$(MAKE) $(SP_OPTIONS) -C % $* ;)

# Target for building subs
$(SUBPROJECTS):
	@$(MAKE) $(SP_OPTIONS) -C $@

# Empty target for doing nothing for subproject target, only watch for them products
# and if they changes, main file (OBJ_PATH) will be rebuilded.
$(SP_TARGETS): ;

$(basename $(OUT_FILE)): $(SP_TARGETS) $(PRECOMPILED_MODULES) $(OBJECTS)
	$(LINK.executable)

lib%.a: $(SP_TARGETS) $(PRECOMPILED_MODULES) $(OBJECTS)
	$(LINK.static)

%.so %.dll: $(SP_TARGETS) $(PRECOMPILED_MODULES) $(OBJECTS)
	$(LINK.shared)

%.o: $(filter %.c, $(SOURCES))
	$(COMPILE.c)

%.o: $(filter %.cpp, $(SOURCES)) $(PRECOMPILED_MODULES)
	$(COMPILE.cc)

%.o: $(filter %.cc, $(SOURCES)) $(PRECOMPILED_MODULES)
	$(COMPILE.cc)

%.pcm: $(MODULES)
	$(COMPILE.ccm)

# Do not delete intermediate files
.PRECIOUS: $(OBJ_PATH)/%.d $(OBJ_PATH)/%.pcm
$(OBJ_PATH)/%.d: ;
$(OBJ_PATH)/%.pcm: ;

# Include all dependecy files for recompile on changing one of them
-include $(DEPS)
