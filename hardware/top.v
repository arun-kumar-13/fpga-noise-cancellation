module top (
    input         CLOCK_50,
    input  [3:0]  KEY,
    input  [17:0] SW,
    output [17:0] LEDR,
    output [8:0]  LEDG,
 
    // Audio codec (WM8731)
    output        AUD_XCK,
    input         AUD_BCLK,
    input         AUD_ADCLRCK,
    input         AUD_DACLRCK,
    input         AUD_ADCDAT,
    output        AUD_DACDAT,
 
    // I2C bus for the codec configuration
    output        I2C_SCLK,
    inout         I2C_SDAT
);
 
    nios_sys u0 (
        .clk_clk         (CLOCK_50),
        .reset_reset_n   (KEY[0]),
 
        .switches_export (SW),
        .keys_export     (KEY),
        .ledr_export     (LEDR),
        .ledg_export     (LEDG),
 
        .audio_pll_clk   (AUD_XCK),
 
        .audio_ADCDAT    (AUD_ADCDAT),
        .audio_ADCLRCK   (AUD_ADCLRCK),
        .audio_BCLK      (AUD_BCLK),
        .audio_DACDAT    (AUD_DACDAT),
        .audio_DACLRCK   (AUD_DACLRCK),
 
        .av_config_SDAT  (I2C_SDAT),
        .av_config_SCLK  (I2C_SCLK)
    );
 
endmodule
 