extern crate actix;
extern crate actix_web;
extern crate env_logger;
extern crate failure;
extern crate futures;
extern crate rand;
extern crate serde_json;
extern crate time;
extern crate toml;
extern crate uuid;
#[macro_use]
extern crate log;

use actix_web::fs::NamedFile;
use actix_web::http::{Method, StatusCode};
use actix_web::middleware::Logger;
use actix_web::Binary;
use actix_web::{
  http, server, App, AsyncResponder, HttpMessage, HttpRequest, HttpResponse, Responder, Result,
};
// use openssl::ssl::{SslAcceptor, SslFiletype, SslMethod};

#[macro_use]
extern crate serde_derive;

use failure::Error;
use futures::future::Future;
use std::path::{Path, PathBuf};
use std::sync::{Arc, RwLock};
use std::time::SystemTime;
mod process_json;
mod util;
use process_json::{process_public_json, PublicMessage, ServerResponse};

#[derive(Deserialize, Debug, Clone)]
pub struct Config {
  ip: String,
  port: u16,
  pdfdir: String,
}

fn files(req: &HttpRequest<Config>) -> Result<NamedFile> {
  println!("files!");
  let path: PathBuf = req.match_info().query("tail")?;
  info!("files: {:?}", path);
  let stpath = Path::new("static/").join(path);
  Ok(NamedFile::open(stpath)?)
}

fn pdffiles(req: &HttpRequest<Config>) -> Result<NamedFile> {
  let path: PathBuf = req.match_info().query("tail")?;
  println!("pdffiles! {:?}", path);
  println!("pdffiles! {:?}", req.match_info());
  let uripath = Path::new(req.uri().path());
  println!("path {:?}", uripath);
  println!("path {:?}", uripath.strip_prefix("/pdfs"));
  uripath
    .strip_prefix("/pdfs")
    .map_err(|e| actix_web::error::ErrorImATeapot(e))
    .and_then(|path| {
      println!("alsopath: {:?}", path);
      let stpath = Path::new(&req.state().pdfdir.to_string()).join(path);
      println!("stpath: {:?}", stpath);
      let nf = NamedFile::open(stpath.clone());
      match nf {
        Ok(_) => println!("ef: "),
        Err(e) => println!("err: {}", e),
      }
      // println!("nf: {:?}", nf);
      let nf = NamedFile::open(stpath);
      nf.map_err(|e| actix_web::error::ErrorImATeapot(e))
    })

  // info!("files: {:?}", path);
  // info!("stpath: {:?}", stpath);
}

fn favicon(_req: &HttpRequest<Config>) -> Result<NamedFile> {
  let stpath = Path::new("static/favicon.ico");
  Ok(NamedFile::open(stpath)?)
}

fn sitemap(_req: &HttpRequest<Config>) -> Result<NamedFile> {
  let stpath = Path::new("static/sitemap.txt");
  Ok(NamedFile::open(stpath)?)
}

// simple index handler
fn mainpage(req: &HttpRequest<Config>) -> Result<HttpResponse> {
  info!(
    "remote ip: {:?}, request:{:?}",
    req.connection_info().remote(),
    req
  );

  match util::load_string("static/index.html") {
    Ok(s) => {
      // response
      Ok(
        HttpResponse::build(StatusCode::OK)
          .content_type("text/html; charset=utf-8")
          .body(s),
      )
    }
    Err(e) => Err(e.into()),
  }
}

fn public(req: &HttpRequest<Config>) -> Box<dyn Future<Item = String, Error = Error>> {
  let ci = req.connection_info().clone();
  let pd = req.state().pdfdir.clone();
  req
    .json()
    .from_err()
    .and_then(move |msg: PublicMessage| {
      Ok(
        match process_json::process_public_json(pd.as_str(), &(ci.remote()), msg) {
          Ok(sr) => match serde_json::to_string(&sr) {
            Ok(s) => s,
            Err(e) => e.to_string(),
          },
          Err(e) => {
            error!("uh oh, 'public' err: {:?}", e);
            let se = ServerResponse {
              what: "server error".to_string(),
              content: serde_json::Value::String(e.to_string()),
            };
            match serde_json::to_string(&se) {
              Ok(s) => s,
              Err(e) => e.to_string(),
            }
          }
        },
      )
    })
    .responder()
}

/*
fn binfile(req: &HttpRequest) -> Box<Future<Item = Binary, Error = Error>> {
  req
    .json()
    .from_err()
    .and_then(move |msg: PublicMessage| {
      Ok(match process_json::process_binfile_json(msg) {
        Ok(sr) => Binary::from(sr),
        Err(e) => Binary::from(""),
      })
    })
    .responder()
}
*/

fn defcon() -> Config {
  Config {
    ip: "127.0.0.1".to_string(),
    port: 8000,
    pdfdir: "./pdfs".to_string(),
  }
}

fn load_config() -> Config {
  match util::load_string("config.toml") {
    Err(e) => {
      error!("error loading config.toml: {:?}", e);
      defcon()
    }
    Ok(config_str) => match toml::from_str(config_str.as_str()) {
      Ok(c) => c,
      Err(e) => {
        error!("error loading config.toml: {:?}", e);
        defcon()
      }
    },
  }
}

fn main() {
  match err_main() {
    Err(e) => println!("error: {:?}", e),
    Ok(_) => (),
  }
}
fn err_main() -> Result<(), Error> {
  env_logger::init();

  info!("server init!");

  let config = load_config();

  println!("config: {:?}", config);

  let sys = actix::System::new("whatevs");

  let nf = NamedFile::open("/home/bburdette/papers/7Sketches2.pdf");
  match nf {
    Ok(_) => println!("ef: "),
    Err(e) => println!("err: {}", e),
  }

  {
    let c = config.clone();
    let s = server::new(move || {
      App::with_state(c.clone())
        .resource("/public", |r| r.method(Method::POST).f(public))
        //            .resource("/binfile", |r| r.method(Method::POST).f(binfile))
        .resource("/favicon.ico", |r| r.method(Method::GET).f(favicon))
        .resource("/sitemap.txt", |r| r.method(Method::GET).f(sitemap))
        .resource(r"/", |r| r.method(Method::GET).f(mainpage))
        .resource(r"/pdfs/{tail:.*}", |r| r.method(Method::GET).f(pdffiles))
        .resource(r"/{tail:.*}", |r| r.method(Method::GET).f(files))
    });

    s.bind(format!("{}:{}", config.ip, config.port))
  }
  .expect(format!("Can not bind to port {}", config.port).as_str())
  .start();

  sys.run();

  Ok(())
}
