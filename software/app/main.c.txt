/* main.c - real-time noise suppressor on the DE2-115 (Nios II, polled audio loop).
 *
 * Audio core registers (Altera University Program Audio core, word offsets):
 *   0 control   bit2 CR clear input FIFO, bit3 CW clear output FIFO
 *   1 fifospace [7:0] RARC  [15:8] RALC  [23:16] WSRC  [31:24] WSLC
 *   2 left data   3 right data
 * Controls:  SW0 noise reduction on   SW1 noise gate on   SW2 1 kHz test tone out
 *            KEY0 learn the noise again (keep the room quiet for 1 s)
 *            KEY1 clear the warning lights
 * Lights:    LEDR0..17 input level meter (3 dB per step)
 *            LEDG0 block was late   LEDG1 output ran dry   LEDG2 learning noise
 *            LEDG3 reduction on     LEDG4 gate on          LEDG7 input clipping
 */
#include <stdint.h>
#include <math.h>
#include "system.h"
#include "io.h"
#include "sys/alt_stdio.h"
#include "dsp_core.h"

#define REG_CTRL   0
#define REG_SPACE  1
#define REG_LEFT   2
#define REG_RIGHT  3

#define QSIZE      512            /* output queue, power of 2 */
#define QMASK      (QSIZE - 1)
#define PRIME      HOP            /* zeros queued at start: slack against timing jitter */
#define METER_LEDS 18

static float    outq[QSIZE];
static unsigned qhead, qcount;
static float    thr[METER_LEDS];
static const float tone[8] = {0.0f, 0.2121f, 0.3f, 0.2121f, 0.0f, -0.2121f, -0.3f, -0.2121f};

static void q_push(float v) { outq[(qhead + qcount) & QMASK] = v; qcount++; }
static float q_pop(void)    { float v = outq[qhead]; qhead = (qhead + 1) & QMASK; qcount--; return v; }

static int16_t to_int16(float y)
{
    float v = y * 32768.0f;
    v += (v >= 0.0f) ? 0.5f : -0.5f;
    if (v > 32767.0f)  v = 32767.0f;
    if (v < -32768.0f) v = -32768.0f;
    return (int16_t)v;
}

int main(void)
{
    float    blk[HOP], res[HOP];
    int      nblk = 0, i, tone_i = 0;
    int      sw_prev = 0, started = 0;
    unsigned warn = 0;             /* bit0 late, bit1 underrun */
    uint32_t key_prev = 0xF;
    float    dc_x = 0.0f, dc_y = 0.0f;   /* DC blocker state */

    for (i = 0; i < METER_LEDS; i++)
        thr[i] = powf(10.0f, -(float)(METER_LEDS - 1 - i) * 3.0f / 20.0f);

    alt_putstr("Noise suppressor start\n");
    dsp_init();

    /* clear both FIFOs, then queue some silence so the output never starts dry */
    IOWR(AUDIO_0_BASE, REG_CTRL, 0x0C);
    IOWR(AUDIO_0_BASE, REG_CTRL, 0x00);
    for (i = 0; i < PRIME; i++) q_push(0.0f);

    for (;;) {
        uint32_t fs = IORD(AUDIO_0_BASE, REG_SPACE);
        int ra = (int)(fs & 0xFF), la = (int)((fs >> 8) & 0xFF);
        int avail = (ra < la) ? ra : la;
        int wr = (int)((fs >> 16) & 0xFF), wl = (int)((fs >> 24) & 0xFF);
        int ws = (wr < wl) ? wr : wl;

        /* ---- input: collect samples; the left channel carries the microphone ---- */
        while (avail-- > 0) {
            int16_t s = (int16_t)(IORD(AUDIO_0_BASE, REG_LEFT) & 0xFFFF);
            (void)IORD(AUDIO_0_BASE, REG_RIGHT);          /* keep the FIFOs in step */
            {
                float x = (float)s * (1.0f / 32768.0f);
                float y = x - dc_x + 0.995f * dc_y;      /* remove DC offset */
                dc_x = x; dc_y = y;
                blk[nblk++] = y;
            }

            if (nblk == HOP) {
                uint32_t sw = IORD(SWITCHES_BASE, 0);
                uint32_t key = IORD(KEYS_BASE, 0) & 0xF;
                float peak = 0.0f;
                uint32_t meter = 0;
                int chg = (int)(sw ^ (uint32_t)sw_prev);

                /* controls */
                if (chg & 1) dsp_set_denoise((int)(sw & 1));
                if (chg & 2) dsp_set_gate((int)((sw >> 1) & 1));
                sw_prev = (int)sw;
                if ((key_prev & 1) && !(key & 1)) dsp_recalibrate();   /* KEY0 pressed */
                if ((key_prev & 2) && !(key & 2)) warn = 0;            /* KEY1 pressed */
                key_prev = key;

                for (i = 0; i < HOP; i++) {
                    float a = blk[i] < 0.0f ? -blk[i] : blk[i];
                    if (a > peak) peak = a;
                }
                for (i = 0; i < METER_LEDS; i++) if (peak > thr[i]) meter |= (1u << i);

                dsp_process_block(blk, res);

                if ((sw >> 2) & 1) {                           /* test tone replaces output */
                    for (i = 0; i < HOP; i++) { res[i] = tone[tone_i]; tone_i = (tone_i + 1) & 7; }
                }
                for (i = 0; i < HOP; i++) if (qcount < QSIZE) q_push(res[i]);
                nblk = 0;

                /* late: a whole new block is already waiting although we just finished one */
                if ((int)(IORD(AUDIO_0_BASE, REG_SPACE) & 0xFF) >= HOP) warn |= 1;

                IOWR(LEDR_BASE, 0, meter);
                IOWR(LEDG_BASE, 0,
                     (warn & 1 ? 0x01u : 0) | (warn & 2 ? 0x02u : 0) |
                     (dsp_calibrating() && (sw & 1) ? 0x04u : 0) |
                     ((sw & 1) ? 0x08u : 0) | ((sw & 2) ? 0x10u : 0) |
                     (peak >= 0.98f ? 0x80u : 0));
                started = 1;
            }
        }

        /* ---- output: move queued samples into the codec FIFO ---- */
        if (started && qcount == 0 && ws >= 120) warn |= 2;    /* FIFO ran empty */
        while (qcount > 0 && ws > 0) {
            int16_t o = to_int16(q_pop());
            IOWR(AUDIO_0_BASE, REG_LEFT,  (uint32_t)(uint16_t)o);
            IOWR(AUDIO_0_BASE, REG_RIGHT, (uint32_t)(uint16_t)o);
            ws--;
        }
    }
    return 0;
}
