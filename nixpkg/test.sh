~/code/nix-error-project/nix/inst/bin/nix-build -E --show-trace 'with import <nixpkgs> { }; callPackage ./default.nix {
  inherit (darwin.apple_sdk.frameworks) Security; }'
