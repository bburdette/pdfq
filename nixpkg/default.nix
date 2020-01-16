{ stdenv, fetchFromGitHub, rustPlatform, Security }:

rustPlatform.buildRustPackage rec {
  pname = "pdfq";
  version = "1.0";

  src = fetchFromGitHub {
    owner = "bburdette";
    repo = pname;
    rev = "74aaa3f410219588d6187fa16fd4e41ffc432eb9";
    sha256 = "17v1bd2mdqbyiq88q1ab854fzh454v3wq777w7cziqnj5zb3mjmr";
  };

  sourceRoot = "source/server";
  cargoSha256 = "0hh3sgcdcp0llgf3i3dysrr3vry3fv3fzzf44ad1953d5mnyhvap";
  # dontMakeSourcesWritable=1;

  buildInputs = stdenv.lib.optional stdenv.isDarwin Security;

  meta = with stdenv.lib; {
    description = "A pdf reader that saves your place.";
    homepage = https://github.com/bburdette/pdfq;
    license = with licenses; [ bsd3 ];
    maintainers = [ ];
    platforms = platforms.all;
  };
}

