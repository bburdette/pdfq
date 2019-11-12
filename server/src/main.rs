extern crate actix_files;
extern crate actix_rt;
extern crate actix_web;
extern crate env_logger;
extern crate failure;
extern crate futures;
extern crate json;
extern crate rand;
extern crate serde_json;
extern crate time;
extern crate toml;
extern crate uuid;
#[macro_use]
extern crate log;

use actix_files::NamedFile;
use actix_web::http::{Method, StatusCode};
use actix_web::middleware::Logger;
// use actix_web::Binary;
use actix_web::{
  http, middleware, web, App, HttpMessage, HttpRequest, HttpResponse, HttpServer, Responder, Result,
};
// use openssl::ssl::{SslAcceptor, SslFiletype, SslMethod};

#[macro_use]
extern crate serde_derive;

// use failure::Error;
use futures::future::Future;
use std::path::{Path, PathBuf};
use std::sync::{Arc, RwLock};
use std::time::SystemTime;
mod process_json;
mod util;
use json::JsonValue;
use process_json::{process_public_json, PublicMessage, ServerResponse};

#[derive(Deserialize, Debug, Clone)]
pub struct Config {
  ip: String,
  port: u16,
  pdfdir: String,
  statedir: String,
  createdirs: bool,
}

fn files(req: &HttpRequest) -> Result<NamedFile> {
  println!("files!");
  let path: PathBuf = req.match_info().query("tail").parse()?;
  info!("files: {:?}", path);
  let stpath = Path::new("static/").join(path);
  Ok(NamedFile::open(stpath)?)
}

// fn index(state: web::Data<Mutex<usize>>, req: HttpRequest) -> HttpResponse {
//     println!("{:?}", req);
//     *(state.lock().unwrap()) += 1;

//     HttpResponse::Ok().body(format!("Num of requests: {}", state.lock().unwrap()))
// }

fn pdffiles(state: web::Data<Config>, req: &HttpRequest) -> Result<NamedFile> {
  let path: PathBuf = req.match_info().query("tail").parse()?;
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
      let stpath = Path::new(&state.pdfdir.to_string()).join(path);
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

fn favicon(_req: &HttpRequest) -> Result<NamedFile> {
  let stpath = Path::new("static/favicon.ico");
  Ok(NamedFile::open(stpath)?)
}

fn sitemap(_req: &HttpRequest) -> Result<NamedFile> {
  let stpath = Path::new("static/sitemap.txt");
  Ok(NamedFile::open(stpath)?)
}

// simple index handler
fn mainpage(state: web::Data<Config>, req: HttpRequest) -> HttpResponse {
  println!("mainpage");
  info!(
    "remote ip: {:?}, request:{:?}",
    req.connection_info().remote(),
    req
  );

  match util::load_string("static/index.html") {
    Ok(s) => {
      println!("okaey");
      // response
      HttpResponse::Ok()
        .content_type("text/html; charset=utf-8")
        .body(s)
    }
    Err(e) => {
      println!("err");
      HttpResponse::from_error(e.into())
    }
  }
}
fn public(
  state: web::Data<Config>,
  item: web::Json<PublicMessage>,
  req: HttpRequest,
) -> HttpResponse {
  println!("model: {:?}", &item);

  let ci = req.connection_info().clone();
  let pd = state.pdfdir.clone();
  let sd = state.statedir.clone();

  match process_json::process_public_json(
    sd.as_str(),
    pd.as_str(),
    &(ci.remote()),
    item.into_inner(),
  ) {
    Ok(sr) => HttpResponse::Ok().json(sr),
    Err(e) => {
      error!("uh oh, 'public' err: {:?}", e);
      let se = ServerResponse {
        what: "server error".to_string(),
        content: serde_json::Value::String(e.to_string()),
      };
      HttpResponse::Ok().json(se)
    }
  }
}

fn defcon() -> Config {
  Config {
    ip: "127.0.0.1".to_string(),
    port: 8000,
    pdfdir: "./pdfs".to_string(),
    statedir: "./state".to_string(),
    createdirs: false,
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
fn err_main() -> Result<(), std::io::Error> {
  env_logger::init();

  info!("server init!");

  let config = load_config();

  if config.createdirs {
    std::fs::create_dir_all(config.pdfdir.clone())?;
    std::fs::create_dir_all(config.statedir.clone())?;
  } else {
    if !Path::new(&config.pdfdir).exists() {
      Err(std::io::Error::new(
        std::io::ErrorKind::NotFound,
        "pdfdir not found!",
      ))?
    }
    if !Path::new(&config.statedir).exists() {
      Err(std::io::Error::new(
        std::io::ErrorKind::NotFound,
        "statedir not found!",
      ))?
    }
  }

  println!("config: {:?}", config);

  let sys = actix_rt::System::new("pdf-server");

  let nf = NamedFile::open("/home/bburdette/papers/7Sketches2.pdf");
  match nf {
    Ok(_) => println!("ef: "),
    Err(e) => println!("err: {}", e),
  }

  let c = web::Data::new(config.clone());
  HttpServer::new(move || {
    App::new()
      .register_data(c.clone()) // <- create app with shared state
      // enable logger
      .wrap(middleware::Logger::default())
      .route("/", web::get().to(mainpage))
      .route("/public", web::post().to(public))
      .service(actix_files::Files::new("/pdfs", c.pdfdir.as_str()))
      .service(actix_files::Files::new("/", "static/"))
  })
  .bind(format!("{}:{}", config.ip, config.port))?
  .run()
}
