# pdfq

pdfq is an attempt to make a pdf reader that's a little better for reading long documents, for me at least.

- I want the reader to always resume where I left off reading last time.
- I don't want to search through my huge folder of documents to find what I was reading.
- I'd like a place to take notes, and have those notes be attached to the document in some way.

Basically I want it to be as thought-free as possible so its as easy to flip over to my pdf reader as 
it is to go to facebook or reddit.

pdfq in its current state is a web server.  It can't be installed with a simple `cargo install` yet.  
To build it, you'll need yarn, parcel, elm, cargo/rustc, and (optionally) cargo-watch.

First, set up a pdfq/server/config.toml.  There's one there already, change it to point at the directory where you keep pdfs.

In a terminal:
```
> cd pdfq/elm
> ./build.sh
```
In another terminal:
```
> cd pdfq/server
> cargo watch -x run
```

Then navigate to localhost:8000.  
