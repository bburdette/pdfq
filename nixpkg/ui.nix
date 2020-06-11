{ yarn2nix-moretea
, fetchFromGitHub
# , Security
, utillinux
, elmPackages
, callPackage
, pkgs
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
    rev = "25e29e4f432eca12f84a8c71a295e3d185bc5a90";
    sha256 = "1k0x8z6m2326prsmz3mrs9yjn6kq92jaqw74if77di6pwz26qcig";
  };

  packageJSON = "${src}/elm/package.json";
  yarnLock = "${src}/elm/yarn.lock";

  # let this build the elm stuff, not parcel.
  # the_elm = callPackage "${src}/elm/default.nix" { };
  the_elm = callPackage "${src}/elm" {  };

  preConfigure = ''
    echo "preconfigure"
    ls -al
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
    # empty
    '';

  # postBuild = ''
  buildPhase = ''
    # we need the node_modules because parcel is in there.
    cp -r $src/elm elmwat
    chmod +w elmwat
    ln -s $node_modules elmwat/node_modules
    cp $the_elm/Main.js elmwat/main.js
    cd elmwat
    mkdir -p $out/static
    ./node_modules/.bin/parcel build index.html --out-dir=$out/static
    '';

  # parcel already built into $out/static, so we're done.
  installPhase = ''
    runHook preInstall
    runHook postInstall
    '';
  distPhase = ''
    # doing nothing
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

