/* params.h - all constants of the noise suppressor (Wiener filter with MCRA).
 * Keep every tunable value here so it can be changed in one place.
 * All floating-point constants carry the f suffix: a constant without it is a
 * double, and double arithmetic is very slow on the Nios II (no double hardware). */

#ifndef PARAMS_H
#define PARAMS_H

#define PI_F      3.14159265358979f

/* Framing */
#define FS_HZ     8000      /* sample rate */
#define N         256       /* frame length */
#define HOP       128       /* hop (50 percent overlap) */
#define NB        129       /* unique FFT bins, 0..N/2 */

/* MCRA noise estimation */
#ifndef A_S
#define A_S       0.8f      /* time smoothing of the power */
#endif
#ifndef MCRA_L
#define MCRA_L    64        /* minimum tracker window in frames (about 1 s) */
#endif
#ifndef DELTA
#define DELTA     5.0f      /* speech presence threshold */
#endif
#ifndef A_P
#define A_P       0.2f      /* smoothing of the speech presence probability */
#endif
#ifndef A_D
#define A_D       0.95f     /* noise update forgetting factor */
#endif
#ifndef INIT_FRAMES
#define INIT_FRAMES 8       /* frames averaged to start the noise estimate */
#endif
/* 1: a frame flagged as speech freezes the noise update at once (weight uses max(p, I));
   0: use p only, as in the textbook formula */
#ifndef MCRA_FREEZE_ON_DECISION
#define MCRA_FREEZE_ON_DECISION 1
#endif

/* Wiener gain */
#ifndef A_DD
#define A_DD      0.98f     /* decision-directed smoothing */
#endif
#ifndef G_MIN
#define G_MIN     0.15f     /* gain floor, about -16 dB */
#endif
#ifndef EPS
#define EPS       1e-10f    /* guard against division by zero */
#endif

/* Noise gate (optional, switched with dsp_set_gate): mutes frames that contain noise only */
#ifndef GATE_THRESH
#define GATE_THRESH 2.0f    /* frame power / noise power below this = noise only */
#endif
#ifndef GATE_SMOOTH
#define GATE_SMOOTH 0.7f    /* smoothing of the frame power ratio over frames */
#endif
#ifndef GATE_HANG
#define GATE_HANG   6       /* frames the gate stays open after speech (about 100 ms) */
#endif
#ifndef GATE_REL
#define GATE_REL    0.6f    /* per-frame closing factor (smooth fade, no click) */
#endif
#ifndef GATE_FLOOR
#define GATE_FLOOR  0.02f   /* gate gain when fully closed, about -34 dB extra */
#endif

#endif /* PARAMS_H */
