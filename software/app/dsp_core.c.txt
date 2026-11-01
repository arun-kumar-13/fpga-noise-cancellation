/* dsp_core.c - phase 9: framing, windowing, FFT, MCRA noise estimation, Wiener gain,
 * IFFT, overlap-add. With MCRA switched off, the noise estimate stays at the value
 * measured in the first INIT_FRAMES frames (the phase 7 behaviour). */

#include <math.h>
#include <string.h>
#include "params.h"
#include "fft.h"
#include "wiener.h"
#include "mcra.h"
#include "dsp_core.h"

static float win[N];        /* sqrt-Hann window */
static float inbuf[N];      /* sliding analysis buffer: old half, then new half */
static float re[N];         /* real part of the working spectrum / frame */
static float im[N];         /* imaginary part */
static float overlap[HOP];  /* second half of the previous output frame */
static float P[NB];         /* power spectrum */
static float lamd[NB];      /* noise power estimate */
static float G[NB];         /* gain of the last frame */
static int   calib_left = INIT_FRAMES;
static int   fft_on     = 1;
static int   denoise_on = 0;
static int   mcra_on    = 1;
static mcra_state mst;
static int   gate_on    = 0;
static float gate_g     = 1.0f;
static int   gate_hang  = 0;
static float gate_ratio = 1.0f;   /* frame power / noise power, smoothed over frames */

void dsp_recalibrate(void)
{
    int k;
    memset(lamd, 0, sizeof(lamd));
    for (k = 0; k < NB; k++) G[k] = 1.0f;
    wiener_reset();
    mcra_reset(&mst);
    calib_left = INIT_FRAMES;
    gate_g = 1.0f;
    gate_hang = 0;
    gate_ratio = 1.0f;
}

void dsp_reset(void)
{
    memset(inbuf,   0, sizeof(inbuf));
    memset(re,      0, sizeof(re));
    memset(im,      0, sizeof(im));
    memset(overlap, 0, sizeof(overlap));
    dsp_recalibrate();
}

void dsp_init(void)
{
    int n;
    for (n = 0; n < N; n++) {
        /* periodic Hann: divide by N, not N-1, so that w^2(n) + w^2(n+HOP) = 1 */
        win[n] = sqrtf(0.5f - 0.5f * cosf(2.0f * PI_F * (float)n / (float)N));
    }
    fft_init();
    dsp_reset();
}

void dsp_set_denoise(int on)
{
    if (on && !denoise_on) dsp_recalibrate();
    denoise_on = on;
}

int dsp_calibrating(void)
{
    return calib_left > 0;
}

void dsp_use_fft(int on)
{
    fft_on = on;
}

void dsp_set_gate(int on)
{
    gate_on = on;
    gate_g = 1.0f;
    gate_hang = 0;
    gate_ratio = 1.0f;
}

void dsp_use_mcra(int on)
{
    mcra_on = on;
}

const float *dsp_window(void) { return win; }
const float *dsp_noise(void)  { return lamd; }
const float *dsp_gain(void)   { return G; }

void dsp_process_block(const float *in128, float *out128)
{
    int n, k;

    /* 1. slide the buffer: old half moves down, new samples go in the top half */
    memmove(inbuf, inbuf + HOP, HOP * sizeof(float));
    memcpy(inbuf + HOP, in128, HOP * sizeof(float));

    /* 2. analysis window; imaginary part is zero for a real signal */
    for (n = 0; n < N; n++) {
        re[n] = inbuf[n] * win[n];
        im[n] = 0.0f;
    }

    if (fft_on) {
        /* 3. to the frequency domain */
        fft(re, im);

        if (denoise_on) {
            /* 4. power spectrum */
            power_spectrum(re, im, P);

            if (calib_left > 0) {
                /* 5a. calibration: average the power of the first INIT_FRAMES frames.
                 *     The audio passes unchanged (gain 1) meanwhile. */
                for (k = 0; k < NB; k++) lamd[k] += P[k] * (1.0f / (float)INIT_FRAMES);
                mcra_smooth_step(&mst, P);
                calib_left--;
                if (calib_left == 0) mcra_start(&mst);
            } else {
                /* 5b. MCRA keeps the noise estimate following the noise (or the fixed
                 *     estimate stays, when MCRA is switched off) */
                if (mcra_on) mcra_update(&mst, P, lamd);

                /* 5c. Wiener gain from the power and the noise estimate, then apply it */
                wiener_gain(P, lamd, G);

                /* 5d. optional gate: frame power against the noise estimate. Open at once
                 *     on speech, hold GATE_HANG frames, then fade down to GATE_FLOOR. */
                if (gate_on) {
                    float sp = 0.0f, sl = 0.0f;
                    for (k = 0; k < NB; k++) { sp += P[k]; sl += lamd[k]; }
                    gate_ratio = GATE_SMOOTH * gate_ratio + (1.0f - GATE_SMOOTH) * (sp / (sl + EPS));
                    if (gate_ratio > GATE_THRESH) {
                        gate_hang = GATE_HANG;
                        gate_g = 1.0f;
                    } else if (gate_hang > 0) {
                        gate_hang--;
                    } else {
                        gate_g = GATE_REL * gate_g + (1.0f - GATE_REL) * GATE_FLOOR;
                    }
                }
                for (k = 0; k < NB; k++) {
                    float g = gate_on ? G[k] * gate_g : G[k];
                    re[k] *= g;
                    im[k] *= g;
                }
            }
        }

        /* 6. rebuild the upper half as the conjugate mirror, so the result is real */
        for (k = 1; k < HOP; k++) {
            re[N - k] =  re[k];
            im[N - k] = -im[k];
        }

        /* 7. back to the time domain */
        ifft(re, im);
    }

    /* 8. synthesis window */
    for (n = 0; n < N; n++) {
        re[n] = re[n] * win[n];
    }

    /* 9. overlap-add: first half plus the saved second half of the previous frame */
    for (n = 0; n < HOP; n++) {
        out128[n] = re[n] + overlap[n];
        overlap[n] = re[n + HOP];
    }
}
