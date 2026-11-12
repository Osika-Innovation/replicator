# P0 controller firmware for an RP2350B board. Not built in this repository:
#   export PICO_SDK_PATH=…; cmake -B build -DPICO_PLATFORM=rp2350 -DPICO_BOARD=<the board> && cmake --build build
cmake_minimum_required(VERSION 3.13)
include($ENV{PICO_SDK_PATH}/external/pico_sdk_import.cmake)
project(p0 C CXX ASM)
pico_sdk_init()
add_executable(p0 pico_main.c fcore.c)
pico_generate_pio_header(p0 ${CMAKE_CURRENT_LIST_DIR}/p0.pio)
target_link_libraries(p0 pico_stdlib hardware_pio hardware_dma hardware_adc hardware_i2c m)
pico_enable_stdio_usb(p0 1)
pico_enable_stdio_uart(p0 0)
pico_add_extra_outputs(p0)
