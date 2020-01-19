{ yarn2nix-moretea
, fetchFromGitHub
, Security
, utillinux
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

  nativeBuildInputs = [ utillinux ];

  # src = "${src_all}/ui";

    # yarn install
    # ./node-packages/.bin/parcel index.html --out-dir=$out/static
  buildPhase = ''
    ls deps
    ./node_modules/.bin/parcel build ${src}/index.html --out-dir=$out/static 
  '';

}

