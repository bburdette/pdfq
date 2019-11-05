extern crate failure;
extern crate rand;
extern crate serde_json;
extern crate time;
extern crate uuid;
extern crate actix_web;
extern crate futures;
extern crate toml;
extern crate actix;
extern crate env_logger;
#[macro_use]
extern crate log;

use actix_web::{AsyncResponder, server, App, Result, HttpMessage, HttpRequest, Responder,
                HttpResponse, http};
use actix_web::middleware::Logger;
use actix_web::fs::NamedFile;
use actix_web::http::{Method,StatusCode};
use actix_web::Binary;
// use openssl::ssl::{SslAcceptor, SslFiletype, SslMethod};

#[macro_use]
extern crate serde_derive;

use failure::Error;
use futures::future::Future;
use std::path::{Path, PathBuf};
use std::sync::{Arc, RwLock};
mod util;
mod process_json;
use process_json::{PublicMessage, 
                   process_public_json, ServerResponse};


fn files(req: &HttpRequest) -> Result<NamedFile> {
  let path: PathBuf = req.match_info().query("tail")?;
  info!("files: {:?}", path); 
  let stpath = Path::new("static/").join(path);
  Ok(NamedFile::open(stpath)?)
}

fn favicon(req: &HttpRequest) -> Result<NamedFile> {
  let stpath = Path::new("static/favicon.ico");
  Ok(NamedFile::open(stpath)?)
}

fn sitemap(req: &HttpRequest) -> Result<NamedFile> {
  let stpath = Path::new("static/sitemap.txt");
  Ok(NamedFile::open(stpath)?)
}

// simple index handler
fn mainpage(req: &HttpRequest) -> Result<HttpResponse> {
    info!("remote ip: {:?}, request:{:?}", req.connection_info().remote(), req);

    match util::load_string("static/index.html") { 
      Ok(s) => {
        // response
        Ok(HttpResponse::build(StatusCode::OK)
            .content_type("text/html; charset=utf-8")
            .body(s))
      }
      Err(e) => Err(e.into())
    }
}

fn public(req: &HttpRequest) -> Box<Future<Item = String, Error = Error>> {
  let ci = req.connection_info().clone(); 
  req
    .json()
    .from_err()
    .and_then(move |msg: PublicMessage| {
      Ok(match process_json::process_public_json(&(ci.remote()), msg) {
        Ok(sr) => {
          match serde_json::to_string(&sr) {
            Ok(s) => s,
            Err(e) => e.to_string(),
          }
        }
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
      })
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

 
#[derive(Deserialize, Debug)]
struct Config {
  ip: String,
  port: u16,
}

fn defcon() -> Config {
  Config {
    ip: "127.0.0.1".to_string(),
    port: 8000,
  }
}


fn load_config() -> Config {
  match util::load_string("config.toml") {
    Err(e) => {
      error!("error loading config.toml: {:?}", e);
      defcon()
    }
    Ok(config_str) => {
      match toml::from_str(config_str.as_str()) {
        Ok(c) => c,
        Err(e) => {
          error!("error loading config.toml: {:?}", e);
          defcon()
        }
      }
    }
  }
}



fn main() {
  let config = load_config();
  env_logger::init();

  info!("server init!");

  let sys = actix::System::new("whatevs");

  {
    let s = server::new(move || {
      
        App::new()
            .resource("/public", |r| r.method(Method::POST).f(public))
//            .resource("/binfile", |r| r.method(Method::POST).f(binfile))
            .resource(r"/static/{tail:.*}", |r| r.method(Method::GET).f(files))
            .resource("/favicon.ico", |r| r.method(Method::GET).f(favicon))
            .resource("/sitemap.txt", |r| r.method(Method::GET).f(sitemap))
            .resource(r"/{tail:.*}", |r| r.method(Method::GET).f(mainpage))

    });
 
    s.bind(format!("{}:{}", config.ip, config.port))
  }.expect(format!("Can not bind to port {}", config.port).as_str())
   .start();

  sys.run();
}
