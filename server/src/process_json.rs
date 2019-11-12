extern crate serde_json;
use serde_json::Value;
use simple_error;
use std::convert::TryInto;
use std::error::Error;
use std::fs::File;
use std::io::Read;
use std::path::{Path, PathBuf};
use std::time::{Duration, SystemTime, UNIX_EPOCH};
use util;

#[derive(Deserialize, Debug)]
pub struct PublicMessage {
  what: String,
  data: Option<serde_json::Value>,
}

#[derive(Deserialize, Debug)]
pub struct Message {
  pub uid: String,
  pwd: String,
  what: String,
  data: Option<serde_json::Value>,
}

#[derive(Serialize, Deserialize)]
pub struct ServerResponse {
  pub what: String,
  pub content: Value,
}

#[derive(Serialize, Debug)]
struct PdfList {
  pdfs: Vec<PdfInfo>,
}

#[derive(Serialize, Debug)]
struct PdfInfo {
  last_read: Option<i64>,
  filename: String,
  state: Option<PersistentState>,
}

#[derive(Deserialize, Serialize, Debug)]
struct PersistentState {
  pdf_name: String,
  zoom: f32,
  page: i32,
  page_count: i32,
}

fn pdfscan(pdfdir: &str, statedir: &str) -> Result<std::vec::Vec<PdfInfo>, Box<Error>> {
  let p = Path::new(pdfdir);

  let mut v = Vec::new();

  if p.exists() {
    for fr in p.read_dir()? {
      let f = fr?;
      let fname = f
        .file_name()
        .into_string()
        .map_err(|e| format!("bad pdf filename: {:?}", f))?;

      let spath = format!("{}/{}.state", statedir, fname);
      let pst = Path::new(spath.as_str()).to_str().ok_or("invalid path")?;

      let state: Option<PersistentState> = match util::load_string(pst) {
        Err(_) => None,
        Ok(s) => {
          println!("loading state: {}", pst);
          let ps: PersistentState = serde_json::from_str(s.as_str())?;
          Some(ps)
        }
      };

      v.push(PdfInfo {
        filename: f
          .file_name()
          .into_string()
          .unwrap_or("non utf filename".to_string()),
        last_read: f
          .metadata()
          .and_then(|f| {
            f.accessed().and_then(|t| {
              let dur = t.duration_since(UNIX_EPOCH).expect("unix-epoch-error");
              let meh: i64 = dur
                .as_millis()
                .try_into()
                .expect("i64 insufficient for posix date!");
              Ok(meh)
            })
          })
          .ok(),
        state: state,
      });

      // println!("eff {:?}", f);
    }
  } else {
    error!("pdf directory not found: {}", pdfdir);
  }

  Ok(v)
}

// public json msgs don't require login.
pub fn process_public_json(
  statedir: &str,
  pdfdir: &str,
  ip: &Option<&str>,
  msg: PublicMessage,
) -> Result<Option<ServerResponse>, Box<Error>> {
  match msg.what.as_str() {
    "getfilelist" => {
      let pl = PdfList {
        pdfs: pdfscan(pdfdir, statedir)?,
      };
      println!("pdflist: {:?}", pl);
      Ok(Some(ServerResponse {
        what: "filelist".to_string(),
        content: serde_json::to_value(pl)?,
      }))
    }
    "savepdfstate" => {
      // write the pdfstate to the appropriate file.
      msg.data.map_or(
        Ok(()),
        (|json| {
          let ps: PersistentState = serde_json::from_value(json.clone())?;
          util::write_string(
            format!("{}/{}.state", statedir, ps.pdf_name).as_str(),
            json.to_string().as_str(),
          )
          .map(|_| ())
        }),
      )?;
      Ok(Some(ServerResponse {
        what: "pdfstatesaved".to_string(),
        content: serde_json::Value::Null,
      }))
    }
    wat => bail!(format!("invalid 'what' code:'{}'", wat)),
  }
}
