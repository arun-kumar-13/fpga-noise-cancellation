/* wiener.h - power spectrum and Wiener gain (decision-directed a priori SNR).
 * No board-specific code. */

#ifndef WIENER_H
#define WIENER_H

#include "params.h"

/* Clear the previous-frame memory. Call at start-up and whenever the noise
 * estimate is restarted. */
void wiener_reset(void);

/* P[k] = re[k]^2 + im[k]^2 for k = 0 .. NB-1 */
void power_spectrum(const float *re, const float *im, float *P);

/* For every bin k = 0 .. NB-1 computes the gain G[k] from the power P[k] and the
 * noise power estimate lamd[k]:
 *     gamma = P / (lamd + EPS)                       a posteriori SNR
 *     xi    = A_DD * M + (1 - A_DD) * max(gamma-1,0) a priori SNR
 *     G     = max( xi / (1 + xi), G_MIN )
 * and stores M = G^2 * gamma for the next frame. */
void wiener_gain(const float *P, const float *lamd, float *G);

/* Read access to the previous-frame memory, for the tests. */
const float *wiener_memory(void);

#endif /* WIENER_H */
