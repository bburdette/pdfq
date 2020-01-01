extern crate actix_files;
extern crate actix_rt;
extern crate actix_web;
extern crate reqwest;
#[macro_use]
extern crate simple_error;
extern crate env_logger;
extern crate futures;
extern crate json;
extern crate rand;
extern crate serde_json;
extern crate time;
extern crate toml;
extern crate uuid;
#[macro_use]
extern crate log;
extern crate rusqlite;
#[macro_use]
extern crate serde_derive;
extern crate barrel;
extern crate base64;
extern crate refinery;

mod migrations;
mod process_json;
mod sqldata;
mod util;

use actix_files::NamedFile;
use actix_web::http::{Method, StatusCode};
use actix_web::middleware::Logger;
use actix_web::web::JsonConfig;
use actix_web::{
  http, middleware, web, App, FromRequest, HttpMessage, HttpRequest, HttpResponse, HttpServer,
  Responder,
};
use futures::future::Future;
use process_json::{PublicMessage, ServerResponse};
use std::convert::Into;
use std::convert::TryInto;
use std::error::Error;
use std::path::{Path, PathBuf};
use std::result::Result;
use std::sync::{Arc, RwLock};
use std::time::SystemTime;

#[derive(Deserialize, Debug, Clone)]
pub struct Config {
  ip: String,
  port: u16,
  pdfdir: String,
  createdirs: bool,
  pdfdb: String,
}

fn files(req: &HttpRequest) -> actix_web::Result<NamedFile> {
  println!("files!");
  let path: PathBuf = req.match_info().query("tail").parse()?;
  info!("files: {:?}", path);
  let stpath = Path::new("static/").join(path);
  Ok(NamedFile::open(stpath)?)
}

fn pdffiles(state: web::Data<Config>, req: &HttpRequest) -> actix_web::Result<NamedFile> {
  let uripath = Path::new(req.uri().path());
  uripath
    .strip_prefix("/pdfs")
    .map_err(|e| actix_web::error::ErrorImATeapot(e))
    .and_then(|path| {
      let stpath = Path::new(&state.pdfdir.to_string()).join(path);
      let nf = NamedFile::open(stpath.clone());
      match nf {
        Ok(_) => println!("ef: "),
        Err(e) => println!("err: {}", e),
      }
      let nf = NamedFile::open(stpath);
      nf.map_err(|e| actix_web::error::ErrorImATeapot(e))
    })
}

fn favicon(_req: &HttpRequest) -> actix_web::Result<NamedFile> {
  let stpath = Path::new("static/favicon.ico");
  Ok(NamedFile::open(stpath)?)
}

fn sitemap(_req: &HttpRequest) -> actix_web::Result<NamedFile> {
  let stpath = Path::new("static/sitemap.txt");
  Ok(NamedFile::open(stpath)?)
}

// simple index handler
fn mainpage(_state: web::Data<Config>, req: HttpRequest) -> HttpResponse {
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
      HttpResponse::from_error(actix_web::error::ErrorImATeapot(e))
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
  let pdb = state.pdfdb.clone();

  match process_json::public_interface(pd.as_str(), pdb.as_str(), &(ci.remote()), item.into_inner())
  {
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
    createdirs: false,
    pdfdb: "./pdf.db".to_string(),
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
  //  sqldata::migrate_test();

  match err_main() {
    Err(e) => println!("error: {:?}", e),
    Ok(_) => (),
  }
}
fn err_main() -> Result<(), Box<dyn Error>> {
  env_logger::init();

  info!("server init!");

  let config = load_config();

  let pdfdbp = Path::new(&config.pdfdb);

  sqldata::dbinit(pdfdbp)?;
  // if !pdfdbp.exists() {
  //   println!("before dbinit");
  //   sqldata::dbinit(pdfdbp)?;
  //   println!("after dbinit");
  // }

  if config.createdirs {
    std::fs::create_dir_all(config.pdfdir.clone())?;
  } else {
    if !Path::new(&config.pdfdir).exists() {
      Err(std::io::Error::new(
        std::io::ErrorKind::NotFound,
        "pdfdir not found!",
      ))?
    }
  }

  println!("config: {:?}", config);

  // let sys = actix_rt::System::new("pdf-server");

  let c = web::Data::new(config.clone());
  HttpServer::new(move || {
    App::new()
      .register_data(c.clone()) // <- create app with shared state
      // enable logger
      .wrap(middleware::Logger::default())
      .route("/", web::get().to(mainpage))
      .service(
        web::resource("/public")
          .data(
            // change json extractor configuration
            // TODO: break incoming pdfs into parts to use smaller buffer.
            web::Json::<PublicMessage>::configure(|cfg| cfg.limit(4096000)),
          )
          .route(web::post().to(public)),
      )
      .service(actix_files::Files::new("/pdfs", c.pdfdir.as_str()))
      .service(actix_files::Files::new("/", "static/"))
  })
  .bind(format!("{}:{}", config.ip, config.port))?
  .run()?;

  Ok(())
}
