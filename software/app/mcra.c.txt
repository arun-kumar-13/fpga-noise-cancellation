/* mcra.c - MCRA noise estimation. */

#include <math.h>
#include <string.h>
#include "params.h"
#include "mcra.h"

#ifdef __NIOS2__
#include "system.h"      /* makes fmaxf/fminf use the floating-point hardware */
#endif

void mcra_smooth_freq(const float *P, float *Sf)
{
    int k;
    Sf[0] = 0.75f * P[0] + 0.25f * P[1];
    for (k = 1; k < NB - 1; k++) {
        Sf[k] = 0.25f * P[k - 1] + 0.5f * P[k] + 0.25f * P[k + 1];
    }
    Sf[NB - 1] = 0.25f * P[NB - 2] + 0.75f * P[NB - 1];
}

void mcra_smooth_time(const float *Sf, float *S)
{
    int k;
    for (k = 0; k < NB; k++) {
        S[k] = A_S * S[k] + (1.0f - A_S) * Sf[k];
    }
}

void mcra_min_track(const float *S, float *Smin, float *Stmp, int *fc)
{
    int k;
    for (k = 0; k < NB; k++) {
        Smin[k] = fminf(Smin[k], S[k]);
        Stmp[k] = fminf(Stmp[k], S[k]);
    }
    (*fc)++;
    if (*fc >= MCRA_L) {
        for (k = 0; k < NB; k++) {
            Smin[k] = fminf(Stmp[k], S[k]);
            Stmp[k] = S[k];
        }
        *fc = 0;
    }
}

void mcra_decide(const float *S, const float *Smin, float *I)
{
    int k;
    for (k = 0; k < NB; k++) {
        I[k] = (S[k] > DELTA * Smin[k]) ? 1.0f : 0.0f;
    }
}

void mcra_prob(const float *I, float *p)
{
    int k;
    for (k = 0; k < NB; k++) {
        p[k] = A_P * p[k] + (1.0f - A_P) * I[k];
    }
}

void mcra_noise_update(const float *P, const float *p, const float *I, float *lamd)
{
    int k;
    for (k = 0; k < NB; k++) {
        float q = p[k];
#if MCRA_FREEZE_ON_DECISION
        q = fmaxf(q, I[k]);
#else
        (void)I;
#endif
        {
            float a = A_D + (1.0f - A_D) * q;
            lamd[k] = a * lamd[k] + (1.0f - a) * P[k];
        }
    }
}

void mcra_reset(mcra_state *st)
{
    memset(st, 0, sizeof(*st));
}

void mcra_smooth_step(mcra_state *st, const float *P)
{
    float Sf[NB];
    mcra_smooth_freq(P, Sf);
    if (!st->have_S) {
        memcpy(st->S, Sf, sizeof(Sf));       /* first frame: start from the measured value */
        st->have_S = 1;
    } else {
        mcra_smooth_time(Sf, st->S);
    }
}

void mcra_start(mcra_state *st)
{
    memcpy(st->Smin, st->S, sizeof(st->S));
    memcpy(st->Stmp, st->S, sizeof(st->S));
    memset(st->p, 0, sizeof(st->p));
    memset(st->I, 0, sizeof(st->I));
    st->fc = 0;
}

void mcra_update(mcra_state *st, const float *P, float *lamd)
{
    mcra_smooth_step(st, P);
    mcra_min_track(st->S, st->Smin, st->Stmp, &st->fc);
    mcra_decide(st->S, st->Smin, st->I);
    mcra_prob(st->I, st->p);
    mcra_noise_update(P, st->p, st->I, lamd);
}
