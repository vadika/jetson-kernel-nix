{ pkgs ? import <nixpkgs> {} }:

let
  kernelSrc = pkgs.fetchurl {
    url = "https://developer.download.nvidia.com/embedded/L4T/r36_Release_v4.0/sources/public_sources.tbz2";
    sha256 = "sha256-qZy5F2qWz/Gd3rkoyeSixdW/RXh7LClB/T6ULudUApI=";
  };

in pkgs.stdenv.mkDerivation {
  name = "jetson-linux-kernel";
  src = kernelSrc;

  nativeBuildInputs = with pkgs; [
    bc
    bison
    flex
    openssl
    perl
    rsync
    gmp
    libmpc
    mpfr
    gnutar
    gcc9
    gnumake
  ];

  CC = "${pkgs.gcc9}/bin/gcc";
  CROSS_COMPILE = "${pkgs.gcc9}/bin/";
  ARCH = "arm64";
  KERNEL_SRC_DIR = "kernel-jammy-src";
  KERNEL_DEF_CONFIG = "defconfig";
  OOT_SOURCE_LIST = "nvidia-oot nvgpu";
  KERNEL_MODULAR_BUILD = "y";

  # Export variables for use in phases
  KERNEL_SRC_DIR_EXPORT = "kernel-jammy-src";

  unpackPhase = ''
    tar xjf $src
    cd Linux_for_Tegra/source
    tar xjf kernel_src.tbz2
    tar xjf kernel_oot_modules_src.tbz2
    tar xjf nvidia_kernel_display_driver_source.tbz2
  '';

  configurePhase = ''
    mkdir -p kernel_out/kernel
    rsync -a --delete kernel/$KERNEL_SRC_DIR_EXPORT kernel_out/kernel/
    cp -a kernel/Makefile kernel_out/kernel/
    for dir in $OOT_SOURCE_LIST; do
      rsync -a --delete $dir kernel_out/
    done
    cp -a Makefile kernel_out/
    ls kernel_out
    read a
  '';

  buildPhase = ''
    cd kernel_out/kernel/$KERNEL_SRC_DIR_EXPORT
    make ARCH=$ARCH CROSS_COMPILE=$CROSS_COMPILE $KERNEL_DEF_CONFIG
    make ARCH=$ARCH CROSS_COMPILE=$CROSS_COMPILE -j$(nproc)
    
    #export KERNEL_HEADERS=$PWD
    cd ../..
    
    make ARCH=$ARCH CROSS_COMPILE=$CROSS_COMPILE modules
    make ARCH=$ARCH CROSS_COMPILE=$CROSS_COMPILE dtbs
  '';

  installPhase = ''
    mkdir -p $out/{boot,lib/modules,kernel-headers}
    
    # Install kernel image
    cp kernel/$KERNEL_SRC_DIR_EXPORT/arch/$ARCH/boot/Image $out/boot/Image
    
    # Install modules
    make -C kernel/$KERNEL_SRC_DIR_EXPORT ARCH=$ARCH CROSS_COMPILE=$CROSS_COMPILE INSTALL_MOD_PATH=$out/lib/modules modules_install
    make ARCH=$ARCH CROSS_COMPILE=$CROSS_COMPILE INSTALL_MOD_PATH=$out/lib/modules INSTALL_MOD_DIR=updates modules_install
    
    # Copy kernel headers for building external modules
    cp -r kernel/$KERNEL_SRC_DIR_EXPORT $out/kernel-headers
    
    # Install DTBs
    mkdir -p $out/boot/dtb
    cp kernel/$KERNEL_SRC_DIR_EXPORT/arch/$ARCH/boot/dts/nvidia/*.dtb $out/boot/dtb/
  '';

  # For building out-of-tree modules
  shellHook = ''
    export KERNEL_HEADERS=$out/kernel-headers
    export CROSS_COMPILE=${pkgs.gcc9}/bin/
    export ARCH=arm64
  '';
}
