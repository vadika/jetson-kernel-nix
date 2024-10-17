{ pkgs ? import <nixpkgs> {} }:

let
  jetsonKernel = import ./default.nix { inherit pkgs; };

in pkgs.mkShell {
  buildInputs = jetsonKernel.nativeBuildInputs;

  shellHook = ''
    export KERNEL_HEADERS=${jetsonKernel}/kernel-headers
    export CROSS_COMPILE=${pkgs.gcc9}/bin/
    export ARCH=arm64
  '';
}
