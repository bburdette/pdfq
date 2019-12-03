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
use sqldata;

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

#[derive(Serialize, Deserialize, Debug)]
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

#[derive(Deserialize, Debug)]
struct PdfNotes {
  pdf_name: String, // we only need the name!
                    // notes: String,
                    // page_notes: map int -> string,
}

#[derive(Deserialize, Serialize, Debug)]
struct PersistentState {
  pdf_name: String,
  zoom: f32,
  page: i32,
  page_count: i32,
  last_read: i64,
}

// public json msgs don't require login.
pub fn process_public_json(
  pdfdir: &str,
  pdfdb: &str,
  statedir: &str,
  ip: &Option<&str>,
  msg: PublicMessage,
) -> Result<Option<ServerResponse>, Box<dyn Error>> {
  let pdbp = Path::new(&pdfdb);
  match msg.what.as_str() {
    "getfilelist" => {
      let pl = sqldata::pdflist(pdbp)? ;
      // println!("pdflist: {:?}", pl);
      Ok(Some(ServerResponse {
        what: "filelist".to_string(),
        content: serde_json::to_value(pl)?,
      }))
    }
    "savepdfstate" => {
      // write the pdfstate to the appropriate file.
      // msg.data.map_or(
      //   Ok(()),
      //   (|json| {
      //     let ps: PersistentState = serde_json::from_value(json.clone())?;
      //     util::write_string(
      //       format!("{}/{}.state", statedir, ps.pdf_name).as_str(),
      //       json.to_string().as_str(),
      //     )
      //     .map(|_| ())
      //   }),
      // )?;
      Ok(Some(ServerResponse {
        what: "pdfstatesaved".to_string(),
        content: serde_json::Value::Null,
      }))
    }
    "getlaststate" => util::load_string(format!("{}/laststate", statedir).as_str())
      .and_then(|statestring| {
        println!("statestring: {}", statestring);
        serde_json::from_str(statestring.as_str())
          .and_then(|v| {
            println!("json success {}", v);
            Ok(Some(ServerResponse {
              what: "laststate".to_string(),
              content: v,
            }))
          })
          .or_else(|e| {
            println!("json fail {}", e);
            Ok(Some(ServerResponse {
              what: "laststate".to_string(),
              content: serde_json::Value::Null,
            }))
          })
      })
      .or_else(|e| {
        println!("not found {}", e);
        Ok(Some(ServerResponse {
          what: "laststate".to_string(),
          content: serde_json::Value::Null,
        }))
      }),
    "savelaststate" => {
      println!("savelaststate");
      // write the pdfstate to the appropriate file.
      msg.data.map_or(
        Ok(()),
        (|json| {
          util::write_string(
            format!("{}/laststate", statedir).as_str(),
            json.to_string().as_str(),
          )
          .map(|_| ())
        }),
      )?;
      Ok(Some(ServerResponse {
        what: "laststatesaved".to_string(),
        content: serde_json::Value::Null,
      }))
    }
    // error for unsupported whats
    wat => bail!(format!("invalid 'what' code:'{}'", wat)),

  }
}
    /*"getnotes" => {
      // read the notes file, or if none exists return null.
      msg.data.map_or(
        Ok(None),
        (|json| {
          let pdfname: String = serde_json::from_value(json.clone())?;
          let blah = util::load_string(format!("{}/{}.notes", statedir, pdfname).as_str())
            .and_then(|s| {
              serde_json::from_str(s.as_str())
                .and_then(|v| {
                  println!("loaded");
                  Ok(Some(ServerResponse {
                    what: "notesresponse".to_string(),
                    content: v,
                  }))
                })
                .or_else(|e| {
                  println!("json fail {}", e);
                  Ok(Some(ServerResponse {
                    what: "notesresponse".to_string(),
                    content: serde_json::Value::Null,
                  }))
                })
            })
            .or_else(|e| {
              println!("load fail {}", e);
              Ok(Some(ServerResponse {
                what: "notesresponse".to_string(),
                content: serde_json::Value::Null,
              }))
            });
          println!("blah {:?}", blah);
          blah
        }),
      )
    }
    "savenotes" => msg.data.map_or(Ok(None), |json| {
      let pdfnotes: PdfNotes = serde_json::from_value(json.clone())?;
      util::write_string(
        format!("{}/{}.notes", statedir, pdfnotes.pdf_name).as_str(),
        json.to_string().as_str(),
      )
      .and_then(|_| {
        Ok(Some(ServerResponse {
          what: "notesaved".to_string(),
          content: serde_json::Value::Null,
        }))
      })
      .or(Ok(Some(ServerResponse {
        what: "notessavefailed".to_string(),
        content: serde_json::Value::Null,
      })))
    }),
  }*/
