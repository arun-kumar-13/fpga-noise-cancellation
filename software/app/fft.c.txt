/* fft.c - in-place radix-2 FFT, 256 points, single-precision float. */

#include <math.h>
#include "params.h"
#include "fft.h"

#define LOG2N 8

#if (1 << LOG2N) != N
#error "fft.c is written for N = 256"
#endif

static float    tw_c[N / 2];
static float    tw_s[N / 2];
static uint16_t bitrev_tab[N];

void fft_init(void)
{
    int i, b;

    for (i = 0; i < N / 2; i++) {
        tw_c[i] = cosf(2.0f * PI_F * (float)i / (float)N);
        tw_s[i] = sinf(2.0f * PI_F * (float)i / (float)N);
    }
    for (i = 0; i < N; i++) {
        unsigned r = 0;
        for (b = 0; b < LOG2N; b++) {
            if (i & (1u << b)) r |= 1u << (LOG2N - 1 - b);
        }
        bitrev_tab[i] = (uint16_t)r;
    }
}

const float    *fft_tw_cos(void) { return tw_c; }
const float    *fft_tw_sin(void) { return tw_s; }
const uint16_t *fft_bitrev(void) { return bitrev_tab; }

void fft(float *xr, float *xi)
{
    int i, j, len, half, step;

    /* bit-reversal reordering */
    for (i = 0; i < N; i++) {
        int r = bitrev_tab[i];
        if (r > i) {
            float t;
            t = xr[i]; xr[i] = xr[r]; xr[r] = t;
            t = xi[i]; xi[i] = xi[r]; xi[r] = t;
        }
    }

    /* butterflies, LOG2N stages */
    for (len = 2; len <= N; len <<= 1) {
        half = len >> 1;
        step = N / len;
        for (i = 0; i < N; i += len) {
            for (j = 0; j < half; j++) {
                float wr =  tw_c[j * step];
                float wi = -tw_s[j * step];          /* e^(-j ...) for the forward FFT */
                int a = i + j;
                int b = a + half;
                float tr = xr[b] * wr - xi[b] * wi;
                float ti = xr[b] * wi + xi[b] * wr;
                xr[b] = xr[a] - tr;
                xi[b] = xi[a] - ti;
                xr[a] = xr[a] + tr;
                xi[a] = xi[a] + ti;
            }
        }
    }
}

void ifft(float *xr, float *xi)
{
    const float scale = 1.0f / (float)N;
    int i;

    /* ifft(X) = conj( fft( conj(X) ) ) / N */
    for (i = 0; i < N; i++) xi[i] = -xi[i];
    fft(xr, xi);
    for (i = 0; i < N; i++) {
        xr[i] =  xr[i] * scale;
        xi[i] = -xi[i] * scale;
    }
}
