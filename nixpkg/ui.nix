{ yarn2nix-moretea
, fetchFromGitHub
# , Security
, utillinux
, elmPackages
}:

yarn2nix-moretea.mkYarnPackage rec {

  name = "pdfq-ui";

  # packageJSON = ../elm/package.json;
  # yarnLock = ../elm/yarn.lock;
  # yarnNix = ./yarn.nix;

  version = "1.0";

  src = fetchFromGitHub {
    owner = "bburdette";
    repo = "pdfq";
    rev = "70c967b04651f079c812561ad5eaa0a160926c1f";
    sha256 = "074zyk6avm8k54y635wwgw7jvb277x1g17xw9plfb16k5c3qj6aw";
  };

  packageJSON = "${src}/elm/package.json";
  yarnLock = "${src}/elm/yarn.lock";

  # let this build the elm stuff, not parcel.
  # the_elm = "./elm/default.nix";

  preConfigure = ''
    echo "preconfigure"
    '';

  # replacing a needed mkYarnPackage configurePhase?
  # configurePhase = elmPackages.fetchElmDeps {
  #   elmPackages = import ./elm/elm-srcs.nix;
  #   registryDat = ./elm/versions.dat;
  #   elmVersion = "0.19.1";
  # };
  #
  # configurePhase = "";

  nativeBuildInputs = [ utillinux # lscpu for parcel.. necessary?
            ];

  # src = "${src_all}/ui";

    # yarn install
    # ./node-packages/.bin/parcel index.html --out-dir=$out/static

  # parcel = yarnNix.packages.

  preBuild = ''
    echo "prebuild"
    ls -l
    '';

  # postBuild = ''
  buildPhase = ''
    # runHook linkNodeModulesHook   # doesn't work
    pwd
    # we need the node_modules because parcel is in there.
    ln -s $node_modules node_modules
    ln -s $src src
    echo "ls -al"
    ls -al
    # ln -s .elm elm/.elm  # elm already built, don't need.
    echo "node_modules: $node_modules"
    # find nixpkg
    echo "out: $out"
    # find $out
    # find ../../bin
    # ls ../../nix
    # find ../../etc
    cd src/elm
    pwd
    ls ../../
    /build/source/node_modules/.bin/parcel build index.html --out-dir=$out/static
    '';

  # buildPhase = ''
  #   echo "find"
  #   find
  #   # ln -s ${src}/index.html node_modules ${src}/node_modules 
  #   export HOME=$(mktemp -d)
  #   # HOME=.
  #   # cp -r ${src}/* .
  #   # chmod +w -R .
  #   # echo "ls home"
  #   ls $HOME
  #   # elm --version
  #   # yarn install --offline
  #   yarn build
  #   echo "find"
  #   find
  #   # ./node_modules/.bin/ build ./index.html --out-dir=$out/static 
  # '';
}

