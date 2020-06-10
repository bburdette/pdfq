{ stdenv
, fetchFromGitHub
, rustPlatform
, Security
, openssl
, pkgconfig
, sqlite
, callPackage }:

# , lib
# , packr

rustPlatform.buildRustPackage rec {
  pname = "pdfq";
  version = "1.0";

  # ui = callPackage ./ui.nix { };

  src = fetchFromGitHub {
    owner = "bburdette";
    repo = pname;
    rev = "b3f680260c65dc613371dce8b9045bb8122c5803";
    sha256 = "1xjqvxp5gcnj9cgh28g5vvj0829i87y39zclnqgw4w36fxfhx9bp";
  };

  # preBuild = ''
  #   cp -r ${ui}/libexec/gotify-ui/deps/gotify-ui/build ui/build && packr
  # '';

  # cargo-culting this from the gotify package.
  subPackages = [ "." ];


  sourceRoot = "source/server";
  cargoSha256 = "117r9z48wszi2y0wshxmd4nawd472zrg1qiz91if991bijv3pl9m";
  # dontMakeSourcesWritable=1;

  buildInputs = [(stdenv.lib.optional stdenv.isDarwin Security) openssl sqlite];

  nativeBuildInputs = [ pkgconfig ];

  meta = with stdenv.lib; {
    description = "A pdf reader that saves your place.";
    homepage = https://github.com/bburdette/pdfq;
    license = with licenses; [ bsd3 ];
    maintainers = [ ];
    platforms = platforms.all;
  };
}

