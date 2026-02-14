#include <stdio.h>
#include <stdint.h>
#include <aacenc_lib.h>

int main(int argc, char *argv[]) {
    HANDLE_AACENCODER hAacEncoder = NULL;
    AACENC_InfoStruct info = { 0 };
    AACENC_ERROR err;

    int bitrate = (argc > 1) ? atoi(argv[1]) : 64000;
    int channels = (argc > 2) ? atoi(argv[2]) : 2;
    int aot = (argc > 3) ? atoi(argv[3]) : 128;

    printf("=== HDC Encoding Debug Tool ===\n");
    printf("Testing with:\n");
    printf("  AOT: %d (%s)\n", aot, aot == 127 ? "HDC" : aot == 128 ? "HDC-PS" : "Unknown");
    printf("  Bitrate: %d bps\n", bitrate);
    printf("  Channels: %d\n", channels);
    printf("  Sample Rate: 44100 Hz\n\n");

    // Open encoder
    printf("Step 1: Opening encoder...\n");
    err = aacEncOpen(&hAacEncoder, 0, channels);
    if (err != AACENC_OK) {
        printf("  FAILED: aacEncOpen returned %d\n", err);
        return 1;
    }
    printf("  SUCCESS\n\n");

    // Set AOT
    printf("Step 2: Setting AOT to %d...\n", aot);
    err = aacEncoder_SetParam(hAacEncoder, AACENC_AOT, aot);
    if (err != AACENC_OK) {
        printf("  FAILED: AACENC_AOT returned %d\n", err);
        aacEncClose(&hAacEncoder);
        return 1;
    }
    printf("  SUCCESS\n\n");

    // Set sample rate
    printf("Step 3: Setting sample rate to 44100...\n");
    err = aacEncoder_SetParam(hAacEncoder, AACENC_SAMPLERATE, 44100);
    if (err != AACENC_OK) {
        printf("  FAILED: AACENC_SAMPLERATE returned %d\n", err);
        aacEncClose(&hAacEncoder);
        return 1;
    }
    printf("  SUCCESS\n\n");

    // Set channel mode
    printf("Step 4: Setting channel mode...\n");
    CHANNEL_MODE mode = (channels == 1) ? MODE_1 : MODE_2;
    err = aacEncoder_SetParam(hAacEncoder, AACENC_CHANNELMODE, mode);
    if (err != AACENC_OK) {
        printf("  FAILED: AACENC_CHANNELMODE returned %d\n", err);
        aacEncClose(&hAacEncoder);
        return 1;
    }
    printf("  SUCCESS\n\n");

    // Set channel order
    printf("Step 5: Setting channel order...\n");
    err = aacEncoder_SetParam(hAacEncoder, AACENC_CHANNELORDER, 1);
    if (err != AACENC_OK) {
        printf("  FAILED: AACENC_CHANNELORDER returned %d\n", err);
        aacEncClose(&hAacEncoder);
        return 1;
    }
    printf("  SUCCESS\n\n");

    // Set bitrate
    printf("Step 6: Setting bitrate to %d...\n", bitrate);
    err = aacEncoder_SetParam(hAacEncoder, AACENC_BITRATE, bitrate);
    if (err != AACENC_OK) {
        printf("  FAILED: AACENC_BITRATE returned %d\n", err);
        aacEncClose(&hAacEncoder);
        return 1;
    }
    printf("  SUCCESS\n\n");

    // Set transport
    printf("Step 7: Setting transport to ADTS (2)...\n");
    err = aacEncoder_SetParam(hAacEncoder, AACENC_TRANSMUX, 2);
    if (err != AACENC_OK) {
        printf("  FAILED: AACENC_TRANSMUX returned %d\n", err);
        aacEncClose(&hAacEncoder);
        return 1;
    }
    printf("  SUCCESS\n\n");

    // Initialize encoder
    printf("Step 8: Initializing encoder (this is where it usually fails)...\n");
    err = aacEncEncode(hAacEncoder, NULL, NULL, NULL, NULL);
    if (err != AACENC_OK) {
        printf("  FAILED: aacEncEncode(init) returned %d\n", err);
        printf("\n=== Error Code Meanings ===\n");
        printf("  0x0100 = AACENC_INVALID_HANDLE\n");
        printf("  0x0200 = AACENC_MEMORY_ERROR\n");
        printf("  0x0201 = AACENC_UNSUPPORTED_PARAMETER\n");
        printf("  0x0202 = AACENC_INVALID_CONFIG\n");
        printf("  0x0220 = AACENC_INIT_ERROR\n");
        printf("  0x0221 = AACENC_INIT_AAC_ERROR\n");
        printf("  0x0222 = AACENC_INIT_SBR_ERROR (SBR tuning table issue)\n");
        printf("  0x0223 = AACENC_INIT_TP_ERROR\n");
        printf("  0x0224 = AACENC_INIT_META_ERROR\n");
        printf("  0x0225 = AACENC_INIT_MPS_ERROR\n");
        printf("\n  Your error: 0x%04X\n", err);
        aacEncClose(&hAacEncoder);
        return 1;
    }
    printf("  SUCCESS\n\n");

    // Get encoder info
    printf("Step 9: Getting encoder info...\n");
    err = aacEncInfo(hAacEncoder, &info);
    if (err != AACENC_OK) {
        printf("  FAILED: aacEncInfo returned %d\n", err);
        aacEncClose(&hAacEncoder);
        return 1;
    }
    printf("  SUCCESS\n\n");

    // Print encoder info
    printf("=== Encoder Configuration ===\n");
    printf("  Max Output Buffer Size: %d bytes\n", info.maxOutBufBytes);
    printf("  Max Anchor Bytes: %d\n", info.maxAncBytes);
    printf("  Input Channels: %d\n", info.inputChannels);
    printf("  Frame Length: %d samples\n", info.frameLength);
    printf("  Encoder Delay: %d samples\n", info.nDelay);
    printf("  Encoder Delay (core): %d samples\n", info.nDelayCore);
    printf("\n");

    // Cleanup
    aacEncClose(&hAacEncoder);

    printf("=== ALL TESTS PASSED ===\n");
    printf("HDC encoding should work with these parameters!\n");

    return 0;
}
