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
    rev = "f8f0da6d7eba6ad4af82ace24ef172f3ce098165";
    sha256 = "0pvnym4hn9a8xicvxmk6nf3lddsfv1sxl32qblzz96ndq5m8wiyp";
  };

  nativeBuildInputs = [ utillinux elmPackages.elm ];

  # src = "${src_all}/ui";

    # yarn install
    # ./node-packages/.bin/parcel index.html --out-dir=$out/static
  buildPhase = ''
    # ln -s ${src}/index.html node_modules ${src}/node_modules 
    cp -r ${src}/* .
    ls
    elm --version 
    ./node_modules/.bin/parcel build index.html --out-dir=$out/static 
  '';

}

