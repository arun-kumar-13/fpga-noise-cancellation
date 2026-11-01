/* dsp_core.h - the processing core. No board-specific code: the same files are used
 * on the PC for testing and on the Nios II for the real system. */

#ifndef DSP_CORE_H
#define DSP_CORE_H

#include "params.h"

/* Build the tables (window, FFT). Call once at start-up. */
void dsp_init(void);

/* Clear all state (buffers, overlap, noise estimate). Does not rebuild the tables.
 * After this the noise estimate is learned again from the next INIT_FRAMES frames. */
void dsp_reset(void);

/* Process one block: 128 new input samples in, 128 output samples out.
 * The output is the input delayed by one hop (128 samples = 16 ms). */
void dsp_process_block(const float *in128, float *out128);

/* Noise reduction on (1) or off (0, the default: gain 1, transparent).
 * Switching it on restarts the noise calibration. Use it for the bypass switch. */
void dsp_set_denoise(int on);

/* Restart the noise calibration (for example on a key press). The first INIT_FRAMES
 * frames afterwards must contain noise only. */
void dsp_recalibrate(void);

/* 1 while the calibration is running, 0 afterwards. */
int dsp_calibrating(void);

/* Switch the FFT / IFFT stage on (1, the default) or off (0). With it off, the frame
 * only goes through the windows (phase 4 behaviour). Used by the tests. */
void dsp_use_fft(int on);

/* Noise gate on (1) or off (0, the default). With it on, frames that contain noise only are
 * faded down to GATE_FLOOR; speech opens it at once. */
void dsp_set_gate(int on);

/* MCRA noise tracking on (1, the default) or off (0: the estimate stays at the calibrated
 * value). Used to compare the two estimators. */
void dsp_use_mcra(int on);

/* Read access, for the tests: window table, noise estimate, last gain (NB values). */
const float *dsp_window(void);
const float *dsp_noise(void);
const float *dsp_gain(void);

#endif /* DSP_CORE_H */
