// A generic RP2350B (QFN-80, 48 GPIO) controller for P0: Waveshare Core2350B,
// Solder Party Stamp XL or any board that leaves GPIO0–31, 32/33 and 40 free.
// Flash is declared at 4 MB, the least any of them carries.
#ifndef _BOARDS_P0_RP2350B_H
#define _BOARDS_P0_RP2350B_H
#define P0_RP2350B
#define PICO_RP2350A 0
#define PICO_DEFAULT_I2C 0
#define PICO_DEFAULT_I2C_SDA_PIN 32
#define PICO_DEFAULT_I2C_SCL_PIN 33
#define PICO_BOOT_STAGE2_CHOOSE_W25Q080 1
#ifndef PICO_FLASH_SPI_CLKDIV
#define PICO_FLASH_SPI_CLKDIV 2
#endif
#ifndef PICO_FLASH_SIZE_BYTES
#define PICO_FLASH_SIZE_BYTES (4 * 1024 * 1024)
#endif
#ifndef PICO_RP2350_A2_SUPPORTED
#define PICO_RP2350_A2_SUPPORTED 1
#endif
#endif
