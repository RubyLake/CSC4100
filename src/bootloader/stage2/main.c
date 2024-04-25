#include "stdint.h"
#include "stdio.h"

void _cdecl cstart_(uint16_t bootDrive)
{
    for (int i = 0; i < 10; i ++)
    {
        puts("Hello, World!\r\n");
    }

    for(;;);
}
