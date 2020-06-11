# ~/code/nix-error-project/nix/inst/bin/nix-build --show-trace -E 'with import <nixos-unstable> { }; callPackage ./default.nix {}'
nix-build --show-trace -E 'with import <nixos> { }; callPackage ./default.nix {}'
