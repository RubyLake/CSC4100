#include "stdint.h"
#include "stdio.h"

void _cdecl cstart_(uint16_t bootDrive)
{
    uint8_t i;
    for (i = 0; i < 10; i ++)
    {
        puts("Hello, World!\r\n");
    }

    for(;;);
}
