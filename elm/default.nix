{ nixpkgs ? <nixpkgs>
, config ? {}
}:

with (import nixpkgs config);

let
  yarnPkg = yarn2nix-moretea.mkYarnPackage {
    name = "pdfq-parcel";
    # packageJSON = ./package.json;
    # unpackPhase = ":";
    src = ./.;
    # yarnLock = ./yarn.lock;
    # publishBinsFor = ["parcel-bundler"];
    # buildPhase = ''
    #     # ln -s ${src}/index.html node_modules ${src}/node_modules 
    #     export HOME=$(mktemp -d)
    #     # HOME=.
    #     cp -r ${src}/* .
    #     chmod +w -R .
    #     ls $HOME
    #     ./node_modules/.bin/parcel build ./index.html --out-dir=$out/static 
    #   '';
  };

  mkDerivation =
    { srcs ? ./elm-srcs.nix
    , src
    , name
    , srcdir ? "./src"
    , targets ? []
    , versionsDat ? ./versions.dat
    }:
    stdenv.mkDerivation {
      inherit name src;

      buildInputs = [ elmPackages.elm yarnPkg ];

      buildPhase = pkgs.elmPackages.fetchElmDeps {
        elmPackages = import srcs;
        inherit versionsDat;
      };

      installPhase = let
        elmfile = module: "${srcdir}/${builtins.replaceStrings ["."] ["/"] module}.elm";
      in ''
        ls "${yarnPkg.out}"
        echo "installPhase"
        ls 
        mkdir -p $out/share/doc
        ${lib.concatStrings (map (module: ''
          echo "compiling ${elmfile module}"
          elm make ${elmfile module} --output $out/${module}.html --docs $out/share/doc/${module}.json
        '') targets)}
      '';
    };
in mkDerivation {
  name = "elm-app-0.1.0";
  srcs = ./elm-srcs.nix;
  src = ./.;
  targets = ["Main"];
  srcdir = "./src";
}

