#!/bin/bash
#
# FDK-AAC-HDC Build and Install Script
# For use with gr-nrsc5 (HD Radio broadcasting)
#
# This script builds and installs FDK-AAC with HDC (AOT 127) support
# for HD Radio encoding as used in NRSC-5 broadcasting.
#
# Supports: Ubuntu 20.04, 22.04, 24.04 (and similar Debian-based systems)
#
# Usage:
#   ./build_and_install.sh          # Build and install (requires sudo)
#   ./build_and_install.sh --cmake  # Use CMake build system
#   ./build_and_install.sh --autotools  # Use autotools build system
#   ./build_and_install.sh --uninstall  # Uninstall the library
#   ./build_and_install.sh --help   # Show this help
#

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
PREFIX="/usr/local"
BUILD_TYPE="Release"
BUILD_SYSTEM="cmake"  # cmake or autotools
INSTALL_HEADERS=1
BUILD_PROGRAMS=1
NPROC=$(nproc 2>/dev/null || echo 4)

print_banner() {
    echo -e "${BLUE}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║     FDK-AAC 2.0.3 with HDC (HD Radio) Support                ║"
    echo "║     Audio Object Type 127 for NRSC-5 Broadcasting            ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

show_help() {
    echo "FDK-AAC-HDC Build Script"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --cmake       Use CMake build system (default)"
    echo "  --autotools   Use autotools build system"
    echo "  --prefix=DIR  Install to DIR (default: /usr/local)"
    echo "  --uninstall   Uninstall the library"
    echo "  --clean       Clean build artifacts only"
    echo "  --help        Show this help message"
    echo ""
    echo "After installation, you can use AOT 127 (HDC) with:"
    echo "  aacEncoder_SetParam(handle, AACENC_AOT, 127);"
    echo ""
    echo "Compatible with gr-nrsc5 for HD Radio broadcasting."
}

check_dependencies() {
    print_info "Checking dependencies..."
    
    local missing_deps=""
    
    if [ "$BUILD_SYSTEM" = "cmake" ]; then
        if ! command -v cmake &> /dev/null; then
            missing_deps="$missing_deps cmake"
        fi
    else
        if ! command -v autoreconf &> /dev/null; then
            missing_deps="$missing_deps autoconf"
        fi
        if ! command -v libtool &> /dev/null; then
            missing_deps="$missing_deps libtool"
        fi
    fi
    
    if ! command -v g++ &> /dev/null; then
        missing_deps="$missing_deps build-essential"
    fi
    
    if [ -n "$missing_deps" ]; then
        print_warning "Missing dependencies:$missing_deps"
        echo ""
        echo "Install them with:"
        echo "  sudo apt-get update"
        echo "  sudo apt-get install -y$missing_deps"
        echo ""
        read -p "Install now? (y/N) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            sudo apt-get update
            sudo apt-get install -y $missing_deps
        else
            print_error "Cannot continue without dependencies"
            exit 1
        fi
    fi
    
    print_info "All dependencies satisfied"
}

build_cmake() {
    print_info "Building with CMake..."
    
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    BUILD_DIR="$SCRIPT_DIR/build"
    
    mkdir -p "$BUILD_DIR"
    cd "$BUILD_DIR"
    
    cmake .. \
        -DCMAKE_BUILD_TYPE="$BUILD_TYPE" \
        -DCMAKE_INSTALL_PREFIX="$PREFIX" \
        -DBUILD_SHARED_LIBS=ON \
        -DBUILD_PROGRAMS=ON
    
    make -j"$NPROC"
    
    print_info "Build complete"
}

build_autotools() {
    print_info "Building with autotools..."
    
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    cd "$SCRIPT_DIR"
    
    if [ ! -f configure ]; then
        print_info "Running autoreconf..."
        autoreconf -fiv
    fi
    
    ./configure --prefix="$PREFIX" --enable-shared
    
    make -j"$NPROC"
    
    print_info "Build complete"
}

install_lib() {
    print_info "Installing to $PREFIX ..."
    
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    
    if [ "$BUILD_SYSTEM" = "cmake" ]; then
        cd "$SCRIPT_DIR/build"
    else
        cd "$SCRIPT_DIR"
    fi
    
    sudo make install
    
    # Update library cache
    if [ -f /etc/ld.so.conf ]; then
        # Check if prefix lib dir is in ldconfig path
        if ! grep -q "$PREFIX/lib" /etc/ld.so.conf /etc/ld.so.conf.d/* 2>/dev/null; then
            print_info "Adding $PREFIX/lib to library path..."
            echo "$PREFIX/lib" | sudo tee /etc/ld.so.conf.d/fdk-aac-hdc.conf > /dev/null
        fi
        sudo ldconfig
    fi
    
    print_info "Installation complete!"
    echo ""
    echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║  FDK-AAC-HDC installed successfully!                          ║${NC}"
    echo -e "${GREEN}╠══════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${GREEN}║                                                              ║${NC}"
    echo -e "${GREEN}║  Library: $PREFIX/lib/libfdk-aac.so                    ║${NC}"
    echo -e "${GREEN}║  Headers: $PREFIX/include/fdk-aac/                     ║${NC}"
    echo -e "${GREEN}║  Tool:    $PREFIX/bin/aac-enc                          ║${NC}"
    echo -e "${GREEN}║                                                              ║${NC}"
    echo -e "${GREEN}║  HDC (HD Radio) is AOT 127                                   ║${NC}"
    echo -e "${GREEN}║                                                              ║${NC}"
    echo -e "${GREEN}║  Test with: aac-enc -t 127 -r 96000 input.wav output.aac     ║${NC}"
    echo -e "${GREEN}║                                                              ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
}

uninstall_lib() {
    print_info "Uninstalling FDK-AAC-HDC..."
    
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    
    if [ "$BUILD_SYSTEM" = "cmake" ] && [ -d "$SCRIPT_DIR/build" ]; then
        cd "$SCRIPT_DIR/build"
        if [ -f install_manifest.txt ]; then
            xargs sudo rm -f < install_manifest.txt
        fi
    else
        cd "$SCRIPT_DIR"
        sudo make uninstall 2>/dev/null || true
    fi
    
    # Remove ldconfig entry
    sudo rm -f /etc/ld.so.conf.d/fdk-aac-hdc.conf
    sudo ldconfig
    
    print_info "Uninstall complete"
}

clean_build() {
    print_info "Cleaning build artifacts..."
    
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    
    rm -rf "$SCRIPT_DIR/build"
    
    # Clean autotools artifacts
    if [ -f "$SCRIPT_DIR/Makefile" ]; then
        cd "$SCRIPT_DIR"
        make clean 2>/dev/null || true
        make distclean 2>/dev/null || true
    fi
    
    print_info "Clean complete"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --cmake)
            BUILD_SYSTEM="cmake"
            shift
            ;;
        --autotools)
            BUILD_SYSTEM="autotools"
            shift
            ;;
        --prefix=*)
            PREFIX="${1#*=}"
            shift
            ;;
        --uninstall)
            uninstall_lib
            exit 0
            ;;
        --clean)
            clean_build
            exit 0
            ;;
        --help|-h)
            show_help
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Main execution
print_banner
check_dependencies

if [ "$BUILD_SYSTEM" = "cmake" ]; then
    build_cmake
else
    build_autotools
fi

install_lib

echo ""
print_info "To use with gr-nrsc5, rebuild gr-nrsc5 after this installation."
print_info "The gr-nrsc5 hdc_encoder block will now be able to use AOT_HDC (127)."
