nix-build -E 'with import <nixpkgs> { }; callPackage ./ui.nix {
  inherit (darwin.apple_sdk.frameworks) Security; }'
