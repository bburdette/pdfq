{ yarn2nix-moretea
, fetchFromGitHub
# , Security
, utillinux
, elmPackages
}:

yarn2nix-moretea.mkYarnPackage rec {

  name = "pdfq-ui";

  packageJSON = ../elm/package.json;
  yarnNix = ./yarn.nix;

  version = "1.0";

  src = fetchFromGitHub {
    owner = "bburdette";
    repo = "pdfq";
    rev = "5918f1bc2b7d9de99968d7e973657c137ef70a91";
    sha256 = "0fh8gdy5cf8n0dxbqyf1rzp05i934drmysdyl1z9zyx80bwiqkr3";
  };
 
  configurePhase = elmPackages.fetchElmDeps {
    elmPackages = import ./elm/elm-srcs.nix;
    registryDat = ./elm/versions.dat;
    elmVersion = "0.19.1";
  };

  nativeBuildInputs = [ utillinux elmPackages.elm ];

  # src = "${src_all}/ui";

    # yarn install
    # ./node-packages/.bin/parcel index.html --out-dir=$out/static

  # parcel = yarnNix.packages.
  

  postBuild = ''
    runHook linkNodeModulesHook
    pwd
    ln -s $node_modules node_modules
    ls -al
    echo "node_modeules?$node_modules"
    # find nixpkg
    echo "out: $out"
    # find $out
    # find ../../bin
    # ls ../../nix
    # find ../../etc
    ./node_modules/.bin/parcel build index.html --out-dir=$out/static
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

