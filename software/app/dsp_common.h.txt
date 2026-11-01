/* dsp_common.h - sample format conversions shared by the PC tests and the board code. */

#ifndef DSP_COMMON_H
#define DSP_COMMON_H

#include <stdint.h>

/* 16-bit integer sample -> float in the range -1.0 .. +1.0 */
static inline float to_float(int s)
{
    return (float)s * (1.0f / 32768.0f);
}

/* float -> 16-bit integer sample, rounded to nearest and clipped (no wrap-around) */
static inline int16_t to_int16(float y)
{
    float v = y * 32768.0f;
    int s = (int)(v >= 0.0f ? v + 0.5f : v - 0.5f);
    if (s >  32767) s =  32767;
    if (s < -32768) s = -32768;
    return (int16_t)s;
}

#endif /* DSP_COMMON_H */
