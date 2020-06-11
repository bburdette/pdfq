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

  ui = callPackage ./ui.nix { };

  src = fetchFromGitHub {
    owner = "bburdette";
    repo = "pdfq";
    rev = "25e29e4f432eca12f84a8c71a295e3d185bc5a90";
    sha256 = "1k0x8z6m2326prsmz3mrs9yjn6kq92jaqw74if77di6pwz26qcig";
  };

  # preBuild = ''
  #   cp -r ${ui}/libexec/gotify-ui/deps/gotify-ui/build ui/build && packr
  # '';

  postInstall = ''
    echo "postInttall"
    ls -l $out
    cp -r ${ui}/static $out
  '';

  # cargo-culting this from the gotify package.
  subPackages = [ "." ];


  sourceRoot = "source/server";
  cargoSha256 = "1jdbjx3xa7f4yhq4l7xsgy6jpdr2lkgqrzarqb5vj2s3jg13kyl4";
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

