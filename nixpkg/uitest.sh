nix-build -E 'with import <nixos-unstable> { }; callPackage ./ui.nix {
  inherit (darwin.apple_sdk.frameworks) Security; }'
