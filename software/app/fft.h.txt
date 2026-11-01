/* fft.h - 256-point complex FFT and IFFT in single-precision float.
 * In-place radix-2 decimation in time. No board-specific code. */

#ifndef FFT_H
#define FFT_H

#include <stdint.h>

/* Build the twiddle and bit-reversal tables. Call once at start-up. */
void fft_init(void);

/* Forward FFT, in place. Input: real part xr[], imaginary part xi[] (256 each).
 * No scaling: X(k) = sum x(n) e^(-j 2 pi k n / 256). */
void fft(float *xr, float *xi);

/* Inverse FFT, in place, including the 1/256 factor, so ifft(fft(x)) = x. */
void ifft(float *xr, float *xi);

/* Read access to the tables, for the tests. */
const float    *fft_tw_cos(void);   /* 128 entries: cos(2 pi i / 256) */
const float    *fft_tw_sin(void);   /* 128 entries: sin(2 pi i / 256) */
const uint16_t *fft_bitrev(void);   /* 256 entries */

#endif /* FFT_H */
