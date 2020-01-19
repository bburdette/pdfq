{ yarn2nix-moretea
, fetchFromGitHub
, Security
, utillinux
, elmPackages
}:

yarn2nix-moretea.mkYarnPackage rec {
  name = "pdfq-ui";

  packageJSON = ../package.json;
  yarnNix = ./yarn.nix;

  version = "1.0";

  src = fetchFromGitHub {
    owner = "bburdette";
    repo = "pdfq";
    rev = "d72a7620b1a62197afc93523925e3eef061f3120";
    sha256 = "1rqyfdlng1q1l7ivx0av51ayjvkmsjwgrsp6a9wz3sid784d6666";
  };

  nativeBuildInputs = [ utillinux elmPackages.elm ];

  # src = "${src_all}/ui";

    # yarn install
    # ./node-packages/.bin/parcel index.html --out-dir=$out/static
  buildPhase = ''
    # ln -s ${src}/index.html node_modules ${src}/node_modules 
    export HOME=$(mktemp -d)
    # HOME=.
    cp -r ${src}/* .
    ls $HOME
    mkdir .elm
    elm --version 
    ./node_modules/.bin/parcel build index.html --out-dir=$out/static 
  '';

}

