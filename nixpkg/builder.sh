source $stdenv/setup

PATH=$cargo/bin:$PATH

echo "vblahha"

# tar xvfz $src 
cd $src/server
cargo build --release --out-dir=$out -Z unstable-options
