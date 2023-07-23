## TangNano-9K-picotiny-exps
My experiments with the picotiny RISC-V example from Sipeed on their Tang Nano
9k FPGA module.
<br>
The original picotiny example is from Sipeed's examples github repository:<br>
https://github.com/sipeed/TangNano-9K-example/picotiny

This is a RISC-V configuration, "A PicoRV32-based SoC example with HDMI
terminal from SimpleVout, SPI Flash XIP from picosoc, and custom UART ISP for
flash programming. UART baudrate default at 115200". See the original README
for more details.<br>
My purchased module was bundled with a 7-inch 1026x600 LCD (though advertised
to be 800x480), so my experiments will use that screen and parameters.

### picotiny.01
- Mainly to hookup the FPGA built-in 8MB PSRAM to a memory space of the
PicoRV32 (at 0xc0000000).
- Because I changed the UART's clock (based on simpleuart.v) so many times,
which also needed a modification and re-compile of the BootROM contents, I
changed the simpleuart.v with my own implementation based on the module's fixed
clock oscillator of 27MHz. This module now ignores the CPU_FREQ changes and
works at a fixed 115200bps, which is expected by the BootROM bootloader for 
firmware uploads.
- I changed the HDMI output (based on SVO.v) to VGAMod.v, which displays a
colour bar pattern to a 5-inch 800x480 LCD, but modified for my 7-inch 1024x600
panel. The pixel clock of 33MHz is probably out-of-spec for this 7-inch module
but the colour bars display nicely. There is no exact datasheet from the Sipeed
website, but other similarly parallel-interfaced 7-inch 1024x600 LCD datasheets
show the pixel clock to be typically 51.2MHz.
- The source directories are moved/renamed a bit, and .../applet is the
modified example of the original .../fw-flash. It's a minimal monitor program
that can inspect and write memory from the command-line.
- Though the GNU_RiscV_xPack_12.2/bin/riscv-none-elf-gcc can compile, somehow
the riscv-none-elf-objcopy does not work. So the original example's of 
GNU_RiscV_Eclipse_8.2.0/bin/riscv-none-embed-objcopy had to be used. Both
toolchains can be downloaded from: https://xpack.github.io/

### picotiny.02
- First attempt of picoRV32-read/writeable PSRAM- Framebuffer for LCD.
- Performance is really slow.

___