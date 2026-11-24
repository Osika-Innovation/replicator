#include "desktop_ram.h"
// The figure the README quotes; `arm-none-eabi-nm -S` on this object shows nothing else is allocated here.
const unsigned dr_ram_static_bytes = (unsigned)DR_RAM_STATIC_BYTES;
