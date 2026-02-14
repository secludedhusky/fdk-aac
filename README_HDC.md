# FDK-AAC 2.0.3 with HDC (HD Radio) Support

This is a patched version of FDK-AAC 2.0.3 that adds support for **HDC encoding** (Audio Object Type 127) and **HDC-PS encoding** (Audio Object Type 128) used in **HD Radio (NRSC-5)** broadcasting.

## What is HDC?

HDC (HD Digital Codec) is the audio codec used in the NRSC-5 HD Radio standard. It's based on HE-AAC (AAC with SBR) but uses a modified bitstream format specific to HD Radio. This patched FDK-AAC library enables encoding audio for HD Radio transmissions.

## Supported Audio Object Types

| AOT | Name | Description |
|-----|------|-------------|
| 127 | HDC | HD Radio codec (HE-AAC based, stereo) |
| 128 | HDC-PS | HD Radio codec with Parametric Stereo |

## Features

- Full HDC (AOT 127) encoding support
- HDC-PS (AOT 128) encoding support with Parametric Stereo
- Compatible with gr-nrsc5 for GNU Radio HD Radio transmission
- Based on FDK-AAC 2.0.3 (latest stable release)
- SBR (Spectral Band Replication) support for HDC
- Scalable syntax mode for HD Radio compatibility
- Clean build with CMake or autotools
- All standard AAC modes still work (AAC-LC, HE-AAC, HE-AACv2, etc.)

## Quick Start

```bash
# Install dependencies (Ubuntu/Debian)
sudo apt-get install build-essential cmake

# Build and install
./build_and_install.sh

# Test HDC encoding
aac-enc -t 127 -r 96000 input.wav output.aac

# Test HDC-PS encoding
aac-enc -t 128 -r 48000 input.wav output.aac
```

## Building Manually

### Using CMake (recommended)

```bash
mkdir build && cd build
cmake .. -DCMAKE_BUILD_TYPE=Release -DBUILD_PROGRAMS=ON
make -j$(nproc)
sudo make install
sudo ldconfig
```

### Using Autotools

```bash
autoreconf -fiv
./configure --prefix=/usr/local
make -j$(nproc)
sudo make install
sudo ldconfig
```

## Integration with gr-nrsc5

After installing this patched FDK-AAC library, rebuild gr-nrsc5 to link against it:

```bash
cd gr-nrsc5
mkdir build && cd build
cmake ..
make -j$(nproc)
sudo make install
sudo ldconfig
```

The `hdc_encoder` block in gr-nrsc5 will now be able to use AOT 127 (HDC) and AOT 128 (HDC-PS).

## HDC Encoder Parameters

For gr-nrsc5 / HD Radio compatibility, use these settings:

| Parameter | Value | Notes |
|-----------|-------|-------|
| Sample Rate | 44100 Hz | Required for HD Radio |
| Frame Length | 1024 samples | Core frame (2048 with SBR) |
| Bitrate | 24000-96000 bps | Depends on HD Radio mode |
| Transport | ADTS (2) | For HDC stream framing |

### Example C API Usage

```c
#include <aacenc_lib.h>

HANDLE_AACENCODER handle;
aacEncOpen(&handle, 0, 2);  // stereo

// For HDC (stereo)
aacEncoder_SetParam(handle, AACENC_AOT, 127);
// OR for HDC-PS (parametric stereo)
aacEncoder_SetParam(handle, AACENC_AOT, 128);

aacEncoder_SetParam(handle, AACENC_SAMPLERATE, 44100);
aacEncoder_SetParam(handle, AACENC_CHANNELMODE, MODE_2);
aacEncoder_SetParam(handle, AACENC_BITRATE, 96000);
aacEncoder_SetParam(handle, AACENC_TRANSMUX, TT_MP4_ADTS);

// Initialize
aacEncEncode(handle, NULL, NULL, NULL, NULL);

// Now encode frames...
```

## Technical Details

### Changes from upstream FDK-AAC 2.0.3

1. **FDK_audio.h**: Added `AOT_HDC = 127` and `AOT_HDC_PS = 128` to `AUDIO_OBJECT_TYPE` enum, added `AC_HDC = 0x10000000` syntax flag
2. **sbr_encoder.h**: Added `SBR_SYNTAX_HDC = 0x0020` bitstream syntax flag
3. **aacenc_lib.cpp**: Added HDC/HDC-PS handling throughout:
   - AOT validation and acceptance
   - SBR activation for HDC modes
   - PS activation for HDC-PS
   - Transport configuration
   - Signaling mode support
4. **sbr_encoder.cpp**: Added HDC/HDC-PS cases for:
   - SBR syntax flag setting
   - PS mode detection
   - Single-rate possibility check
5. **env_bit.cpp**: Modified fill bit handling for HDC syntax

### Key Insight: AC_HDC Flag Value

The `AC_HDC` flag was carefully chosen as `0x10000000` to avoid conflicts with existing flags, particularly `AC_LD_MPS` (`0x2000000`). This prevents false triggering of the MPS encoder path when HDC is used.

## License

This library is based on FDK-AAC which is licensed under a Fraunhofer FDK AAC license. The HDC patches are provided for educational and experimental use only.

**Important**: HD Radio is a proprietary technology. Transmitting HD Radio signals may require licensing from iBiquity Digital Corporation.

## Credits

- Original FDK-AAC: Fraunhofer IIS
- HDC patches: Based on community work for gr-nrsc5
- FDK-AAC 2.0.3 forward-port: This release

## Changelog

### v2.0.3-hdc (2025-01-10)
- Ported HDC patches to FDK-AAC 2.0.3
- Added HDC-PS (AOT 128) support
- Fixed AC_HDC flag conflict with AC_LD_MPS
- Added comprehensive transport layer support for HDC-PS
- Verified compatibility with standard AAC modes
