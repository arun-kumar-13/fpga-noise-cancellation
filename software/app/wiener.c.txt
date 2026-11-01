/* wiener.c - power spectrum and Wiener gain with decision-directed SNR. */

#include <math.h>
#include <string.h>
#include "params.h"
#include "wiener.h"

#ifdef __NIOS2__
#include "system.h"      /* makes fmaxf/fminf use the floating-point hardware */
#endif

#define XI_MAX 1.0e4f    /* upper limit of the a priori SNR: far above any useful value,
                            and it keeps every value finite */

static float M[NB];      /* G^2 * gamma of the previous frame */

void wiener_reset(void)
{
    memset(M, 0, sizeof(M));
}

const float *wiener_memory(void)
{
    return M;
}

void power_spectrum(const float *re, const float *im, float *P)
{
    int k;
    for (k = 0; k < NB; k++) {
        P[k] = re[k] * re[k] + im[k] * im[k];
    }
}

void wiener_gain(const float *P, const float *lamd, float *G)
{
    int k;
    for (k = 0; k < NB; k++) {
        float gamma = P[k] / (lamd[k] + EPS);
        float xi = A_DD * M[k] + (1.0f - A_DD) * fmaxf(gamma - 1.0f, 0.0f);
        float g;

        if (xi > XI_MAX) xi = XI_MAX;

        g = xi / (1.0f + xi);
        if (g < G_MIN) g = G_MIN;

        G[k] = g;
        M[k] = g * g * gamma;
        if (M[k] > XI_MAX) M[k] = XI_MAX;
    }
}
