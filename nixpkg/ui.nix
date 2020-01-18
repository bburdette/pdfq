{ yarn2nix-moretea
, fetchFromGitHub
, Security
}:

yarn2nix-moretea.mkYarnPackage rec {
  name = "pdfq-ui";

  packageJSON = ../package.json;
  yarnNix = ./yarn.nix;

  version = "1.0";

  src = fetchFromGitHub {
    owner = "bburdette";
    repo = "pdfq";
    rev = "b3f680260c65dc613371dce8b9045bb8122c5803";
    sha256 = "1xjqvxp5gcnj9cgh28g5vvj0829i87y39zclnqgw4w36fxfhx9bp";
  };

  # src = "${src_all}/ui";

  buildPhase = ''
    yarn install
    ./node-packages/.bin/parcel index.html --out-dir=$out/static
  '';

}

