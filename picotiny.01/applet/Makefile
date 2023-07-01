PROJ_NAME=applet
# DEBUG=no
DEBUG=yes
BENCH=no
MULDIV=no
COMPRESSED=no

SRCS = 	$(wildcard src/*.c)	\
		$(wildcard src/*.S)

LDSCRIPT = src/linker_flash.ld

RISCV_PATH ?= D:/Programs/GNU_RiscV_xPack_12.2
RISCV_NAME ?= riscv-none-elf
# RISCV_PATH ?= D:/Programs/GNU_RiscV_Eclipse_8.2.0
# RISCV_NAME ?= riscv-none-embed

MABI=ilp32
MARCH := rv32i
ifeq ($(MULDIV),yes)
	MARCH := $(MARCH)m
endif
ifeq ($(COMPRESSED),yes)
	MARCH := $(MARCH)ac
endif


CFLAGS += -march=$(MARCH)  -mabi=$(MABI)  -ffunction-sections -fdata-sections --specs=nano.specs
LDFLAGS += -march=$(MARCH)  -mabi=$(MABI)  -Wl,--gc-sections

ifeq ($(DEBUG),yes)
	CFLAGS += -g3 -O0 
endif

ifeq ($(DEBUG),no)
	CFLAGS += -g -O3 
endif

ifeq ($(BENCH),yes)
	CFLAGS += -fno-inline  
endif

RISCV_CLIB=$(RISCV_PATH)/$(RISCV_NAME)/lib/$(MARCH)/$(MABI)/

RISCV_CC = $(RISCV_PATH)/bin/$(RISCV_NAME)-gcc
RISCV_OBJDUMP = $(RISCV_PATH)/bin/$(RISCV_NAME)-objdump
# RISCV_OBJCOPY = $(RISCV_PATH)/bin/$(RISCV_NAME)-objcopy
# Can't understand why newer objcopy util does not work???
RISCV_OBJCOPY = D:/Programs/GNU_RiscV_Eclipse_8.2.0/bin/riscv-none-embed-objcopy

CFLAGS +=  -MD -fstrict-volatile-bitfields 
LDFLAGS +=  -lgcc -mcmodel=medany -nostartfiles -ffreestanding \
	-Wl,-Bstatic,-T,$(LDSCRIPT),-Map,$(OBJDIR)/$(PROJ_NAME).map,--print-memory-usage

OBJDIR = build
OBJS := $(SRCS)
OBJS := $(OBJS:.c=.o)
OBJS := $(OBJS:.cpp=.o)
OBJS := $(OBJS:.S=.o)
OBJS := $(addprefix $(OBJDIR)/,$(OBJS))

SUBOBJ := $(addprefix $(OBJDIR)/,$(SUBDIRS))
SUBOBJ := $(addsuffix /*.o,$(SUBOBJ))

export RISCV_CC CFLAGS LDFLAGS OBJDIR

all: $(SUBDIRS) $(OBJDIR)/$(PROJ_NAME).elf $(OBJDIR)/$(PROJ_NAME).bin \
	$(OBJDIR)/$(PROJ_NAME).hex $(OBJDIR)/$(PROJ_NAME).asm $(OBJDIR)/$(PROJ_NAME).v

$(SUBDIRS): ECHO
	make -C $@

ECHO:
	@echo $(SUBDIRS)

$(OBJDIR)/%.elf: $(OBJS) | $(OBJDIR)
	$(RISCV_CC) $(CFLAGS) -o $@ $^ $(SUBOBJ) $(LDFLAGS) $(LIBS)

%.hex: %.elf
	$(RISCV_OBJCOPY) -O ihex $^ $@

%.bin: %.elf
	$(RISCV_OBJCOPY) -O binary $^ $@
	
%.v: %.elf
	$(RISCV_OBJCOPY) -O verilog $^ $@
	cp $@ .

%.asm: %.elf
	$(RISCV_OBJDUMP) -S -d $^ > $@

$(OBJDIR)/%.o: %.c
	mkdir -p $(dir $@)
	$(RISCV_CC) -c $(CFLAGS)  $(INC) -o $@ $^
	
$(OBJDIR)/%.o: %.cpp
	mkdir -p $(dir $@)
	$(RISCV_CC) -c $(CFLAGS)  $(INC) -o $@ $^	

$(OBJDIR)/%.o: %.S
	mkdir -p $(dir $@)
	$(RISCV_CC) -c $(CFLAGS) -o $@ $^ -D__ASSEMBLY__=1

$(OBJDIR):
	mkdir -p $@

upload: $(OBJDIR)/$(PROJ_NAME).v
	pico-programmer.py $(OBJDIR)/$(PROJ_NAME).v com6


clean:
	rm -f $(OBJDIR)/$(PROJ_NAME).elf
	rm -f $(OBJDIR)/$(PROJ_NAME).bin
	rm -f $(OBJDIR)/$(PROJ_NAME).hex
	rm -f $(OBJDIR)/$(PROJ_NAME).map
	rm -f $(OBJDIR)/$(PROJ_NAME).v
	rm -f $(OBJDIR)/$(PROJ_NAME).asm
	find $(OBJDIR) -type f -name '*.d' -print0 | xargs -0 -r rm
	find $(OBJDIR) -type f -name '*.o' -print0 | xargs -0 -r rm

.SECONDARY: $(OBJS)


			
