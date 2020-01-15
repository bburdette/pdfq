{ stdenv, cargo }:

stdenv.mkDerivation rec {
  pname = "pdfq";
  version = "1.0";

  src = builtins.fetchGit {
    url = "git@github.com:bburdette/pdfq.git";
    ref = "master";
    rev = "74aaa3f410219588d6187fa16fd4e41ffc432eb9";
  };

  builder=./builder.sh;
  inherit cargo;

  doCheck = true;

  meta = with stdenv.lib; {
    description = "pdf reader web server";
    longDescription = ''
     pdfq is a web server that tracks progress on reading pdfs in 
     your collection.
    '';
    homepage = https://github.com/bburdette/pdfq;
    license = licenses.bsd3;
    # maintainers = [ maintainers.eelco ];
    platforms = platforms.all;
  };
}
