# Fix for AOT 127/128 Encoding Failures in fdk-aac-2.0.3-hdc

## Problem Description

When encoding with AOT 127 (HDC) or AOT 128 (HDC-PS) for HD Radio, the encoder fails with an "Encoding failed" error at certain bitrates. This occurs because the SBR (Spectral Band Replication) tuning table lacks entries that cover the full HD Radio bitrate range for 44.1 kHz input.

## Root Cause

The encoding failure happens during SBR encoder initialization in this call chain:

1. `aacEncEncode()` → `aacEncInit()` → `sbrEncoder_Init()`
2. `FDKsbrEnc_IsSbrSettingAvail()` → `getSbrTuningTableIndex()`
3. `getSbrTuningTableIndex()` returns `INVALID_TABLE_IDX`
4. This causes `AACENC_INIT_SBR_ERROR` at `libAACenc/src/aacenc_lib.cpp:1387`

### Why This Happens

HD Radio uses:
- **Input sample rate**: 44100 Hz
- **Core encoder sample rate**: 22050 Hz (dual-rate SBR)
- **Frame length**: 1024 samples (core), 2048 with SBR
- **Bitrate range**: 24000-96000 bps (mono), 48000-192000 bps (stereo)

The SBR tuning table in `libSBRenc/src/sbrenc_rom.cpp` had:
- A commented-out entry for 8000-11369 bps at 22050 Hz (line 571-572)
- No entries beyond 64001 bps for mono at 22050 Hz
- No entries beyond 128001 bps for stereo at 22050 Hz

This left gaps in coverage for HD Radio bitrates.

## Solution

The patch file `hdc_tuning_table_fix.patch` adds missing SBR tuning table entries to ensure complete coverage of HD Radio bitrates.

### Changes Made

#### 1. Mono Entries (22050 Hz core rate)

**Added:**
- `{CODEC_AAC, 8000, 11369, 22050, 1, ...}` - Restored commented-out low bitrate entry
- `{CODEC_AAC, 64001, 96000, 22050, 1, ...}` - Mid-high bitrate range
- `{CODEC_AAC, 96000, 128001, 22050, 1, ...}` - High bitrate range

**Coverage:** Now supports 8 kbps to 128 kbps mono

#### 2. Stereo Entries (22050 Hz core rate)

**Added:**
- `{CODEC_AAC, 128001, 160000, 22050, 2, ...}` - High bitrate range
- `{CODEC_AAC, 160000, 192001, 22050, 2, ...}` - Very high bitrate range

**Coverage:** Now supports 16 kbps to 192 kbps stereo

### Tuning Parameters Explained

Each entry has this format:
```c
{CODEC_TYPE, bitrateFrom, bitrateTo, sampleRate, numChannels,
 startFreq, startFreqSpeech, stopFreq, stopFreqSpeech,
 numNoiseBands, noiseFloorOffset, noiseMaxLevel, stereoMode, freqScale}
```

- **CODEC_AAC**: Standard AAC codec (vs. CODEC_AACLD for low-delay)
- **bitrateFrom/To**: Bitrate range (inclusive/exclusive)
- **sampleRate**: Core encoder sample rate (22050 Hz)
- **numChannels**: 1 (mono) or 2 (stereo)
- **startFreq**: SBR start frequency index (bs_start_freq)
- **stopFreq**: SBR stop frequency index (bs_stop_freq)
- **numNoiseBands**: Number of noise bands
- **noiseFloorOffset**: Noise floor adjustment
- **noiseMaxLevel**: Maximum noise level
- **stereoMode**: SBR_MONO, SBR_SWITCH_LRC, or SBR_LEFT_RIGHT
- **freqScale**: Frequency scale factor (1-3)

## Application Instructions

### Method 1: Apply the Patch (Recommended)

```bash
cd /n/HD\ Radio\ Machine/home/gnuradio/fdk-aac-2.0.3-hdc
patch -p1 < hdc_tuning_table_fix.patch
```

### Method 2: Manual Edit

If the patch fails, manually edit `libSBRenc/src/sbrenc_rom.cpp`:

1. **Find line 571** (the commented-out entry in the "22.05/44.1 kHz dual rate" mono section)
2. **Uncomment line 571-572** to restore the 8000-11369 bps entry
3. **After line 579** (the `{CODEC_AAC, 44000, 64001, ...}` entry), add:
   ```c
   /* Extended HD Radio coverage for high bitrates */
   {CODEC_AAC, 64001, 96000, 22050, 1, 13, 13, 12, 12, 2, 0, 3, SBR_MONO, 1},
   {CODEC_AAC, 96000, 128001, 22050, 1, 13, 13, 12, 12, 2, 0, 3, SBR_MONO, 1},
   ```

4. **Find line 702** (after the `{CODEC_AAC, 76000, 128001, ...}` stereo entry)
5. **Add these stereo entries**:
   ```c
   /* Extended HD Radio stereo coverage for high bitrates */
   {CODEC_AAC, 128001, 160000, 22050, 2, 14, 14, 12, 12, 3, 0, -3,
    SBR_LEFT_RIGHT, 1},
   {CODEC_AAC, 160000, 192001, 22050, 2, 14, 14, 12, 12, 3, 0, -3, SBR_LEFT_RIGHT, 1},
   ```

### Rebuild fdk-aac

After applying the patch:

```bash
cd /n/HD\ Radio\ Machine/home/gnuradio/fdk-aac-2.0.3-hdc

# Using CMake
mkdir -p build && cd build
cmake .. -DCMAKE_BUILD_TYPE=Release -DBUILD_PROGRAMS=ON
make -j$(nproc)
sudo make install
sudo ldconfig

# OR using Autotools
autoreconf -fiv
./configure --prefix=/usr/local
make -j$(nproc)
sudo make install
sudo ldconfig
```

### Rebuild gr-nrsc5

```bash
cd /n/HD\ Radio\ Machine/home/gnuradio/gr-nrsc5
rm -rf build
mkdir build && cd build
cmake ..
make -j$(nproc)
sudo make install
sudo ldconfig
```

## Verification

Test that AOT 127 and 128 now work:

```bash
# Test HDC mono at 24 kbps
aac-enc -t 127 -r 24000 -c 1 -i input_mono.wav -o output_hdc_24k.aac

# Test HDC stereo at 96 kbps
aac-enc -t 127 -r 96000 -c 2 -i input_stereo.wav -o output_hdc_96k.aac

# Test HDC-PS at 48 kbps
aac-enc -t 128 -r 48000 -c 2 -i input_stereo.wav -o output_hdcps_48k.aac
```

All commands should complete without "Encoding failed" errors.

## Alternative: Bypass Tuning Table Check (Advanced)

If you prefer a more direct fix, you can modify `libSBRenc/src/sbr_encoder.cpp` to bypass the tuning table check for HDC:

### File: `libSBRenc/src/sbr_encoder.cpp`

**Find line 397** (`FDKsbrEnc_IsSbrSettingAvail` function) and add this at the beginning:

```cpp
static UINT FDKsbrEnc_IsSbrSettingAvail(
    UINT bitrate,           /*! the total bitrate in bits/sec */
    UINT vbrMode,           /*! the vbr paramter, 0 means constant bitrate */
    UINT numOutputChannels, /*! the number of channels for the core coder */
    UINT sampleRateInput,   /*! the input sample rate [in Hz] */
    UINT sampleRateCore,    /*! the core's sampling rate */
    AUDIO_OBJECT_TYPE core) {
  INT idx = INVALID_TABLE_IDX;

  /* HDC/HDC-PS always supported at 44.1 kHz input (22.05 kHz core) */
  if ((core == AOT_HDC || core == AOT_HDC_PS) &&
      sampleRateInput == 44100 &&
      sampleRateCore == 22050 &&
      (numOutputChannels == 1 || numOutputChannels == 2)) {
    return 1; /* Force success for HDC */
  }

  /* ... rest of existing function ... */
```

This approach completely bypasses the tuning table check for HDC, which is simpler but less flexible.

## Technical Background

### SBR Tuning Table Structure

The tuning table defines SBR parameters for different bitrate/sample rate combinations. Each entry specifies:

- **Frequency range**: Which frequency bands to encode with SBR
- **Noise bands**: How many noise bands to use
- **Stereo mode**: How to handle stereo encoding
- **Frequency scale**: How aggressively to scale frequencies

### Dual-Rate SBR for HD Radio

HD Radio uses dual-rate SBR:
- Audio input: 44100 Hz
- Core AAC encoder: 22050 Hz (downsampled)
- SBR: Generates high-frequency content to upsample to 44100 Hz
- Frame size: 1024 samples at core rate, 2048 at output rate

### Why 22050 Hz Core Rate?

When the encoder processes AOT_HDC with 44.1 kHz input, it:
1. Sets `downSampleFactor = 2` (line 2105 in `sbr_encoder.cpp`)
2. Calculates `coreSampleRate = 44100 / 2 = 22050` (line 2140)
3. Looks up tuning table entries for 22050 Hz (line 423)

## Testing Matrix

| Bitrate | Channels | AOT | Expected Result |
|---------|----------|-----|-----------------|
| 24 kbps | Mono | 127 (HDC) | ✓ Pass |
| 48 kbps | Mono | 127 (HDC) | ✓ Pass |
| 96 kbps | Mono | 127 (HDC) | ✓ Pass |
| 48 kbps | Stereo | 127 (HDC) | ✓ Pass |
| 96 kbps | Stereo | 127 (HDC) | ✓ Pass |
| 24 kbps | Stereo | 128 (HDC-PS) | ✓ Pass (PS downmixes to mono) |
| 48 kbps | Stereo | 128 (HDC-PS) | ✓ Pass |

## Troubleshooting

### If Encoding Still Fails

1. **Check library version:**
   ```bash
   ldd /path/to/gr-nrsc5/lib/libgnuradio-nrsc5.so | grep fdk-aac
   ```
   Ensure it's linking to the patched library.

2. **Enable debug output:**
   Add debug logging to `sbr_encoder.cpp:423` before `getSbrTuningTableIndex()`:
   ```cpp
   printf("DEBUG: Looking up SBR tuning for bitrate=%u, channels=%u, sampleRate=%u, core=%u\n",
          bitrate, numOutputChannels, sampleRateCore, core);
   ```

3. **Verify patch applied:**
   ```bash
   grep -n "Extended HD Radio coverage" libSBRenc/src/sbrenc_rom.cpp
   ```
   Should return two matches (one for mono, one for stereo).

4. **Check bitrate range:**
   HD Radio MPS modes have specific bitrate requirements. Ensure your bitrate matches an HD Radio service mode (e.g., MP1: 96 kbps, MP3: 48 kbps).

## Files Modified

- `libSBRenc/src/sbrenc_rom.cpp` - SBR tuning table entries

## References

- [HD Radio NRSC-5 Standard](https://www.nrscstandards.org/standards-and-guidelines/documents/standards/nrsc-5-d/nrsc-5-d.pdf)
- [FDK-AAC Documentation](https://github.com/mstorsjo/fdk-aac)
- [gr-nrsc5 Project](https://github.com/argilo/gr-nrsc5)
- `README_HDC.md` - HDC implementation details

## License

This fix is provided under the same Fraunhofer FDK AAC license as the base library. Use for educational and experimental purposes only.

---

**Last Updated:** 2025-02-13
**Version:** 1.0
**Tested With:** fdk-aac-2.0.3-hdc, gr-nrsc5 latest
