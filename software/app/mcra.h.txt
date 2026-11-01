/* mcra.h - MCRA noise estimation (minima controlled recursive averaging).
 * The five pieces are separate functions on caller-owned arrays, so each one can be tested
 * alone. mcra_update() runs all of them in order. No board-specific code. */

#ifndef MCRA_H
#define MCRA_H

#include "params.h"

/* ---- the five pieces (all arrays have NB entries) ---- */

/* 1a. frequency smoothing: Sf[k] = 0.25 P[k-1] + 0.5 P[k] + 0.25 P[k+1]; the end bins repeat. */
void mcra_smooth_freq(const float *P, float *Sf);

/* 1b. time smoothing, in place: S = A_S * S + (1 - A_S) * Sf */
void mcra_smooth_time(const float *Sf, float *S);

/* 2. minimum tracker with two registers. Call once per frame. After MCRA_L frames the
 *    running minimum is replaced by the temporary minimum, and the temporary one restarts. */
void mcra_min_track(const float *S, float *Smin, float *Stmp, int *fc);

/* 3. speech presence decision: I[k] = 1 if S[k] > DELTA * Smin[k], else 0 */
void mcra_decide(const float *S, const float *Smin, float *I);

/* 4. speech presence probability, in place: p = A_P * p + (1 - A_P) * I */
void mcra_prob(const float *I, float *p);

/* 5. adaptive noise update, in place:
 *      a = A_D + (1 - A_D) * p            (with MCRA_FREEZE_ON_DECISION: p replaced by max(p, I))
 *      lamd = a * lamd + (1 - a) * P */
void mcra_noise_update(const float *P, const float *p, const float *I, float *lamd);

/* ---- the whole estimator ---- */

typedef struct {
    float S[NB];       /* smoothed power */
    float Smin[NB];    /* running minimum */
    float Stmp[NB];    /* temporary minimum */
    float p[NB];       /* speech presence probability */
    float I[NB];       /* last decision */
    int   fc;          /* frames since the last minimum swap */
    int   have_S;      /* 0 until the first smoothing step */
} mcra_state;

void mcra_reset(mcra_state *st);

/* During the initial frames: only the smoothing runs (the caller averages lamd itself). */
void mcra_smooth_step(mcra_state *st, const float *P);

/* After the initial frames: start the minimum tracker from the smoothed power. */
void mcra_start(mcra_state *st);

/* One frame of the full estimator: smoothing, minimum, decision, probability, noise update. */
void mcra_update(mcra_state *st, const float *P, float *lamd);

#endif /* MCRA_H */
