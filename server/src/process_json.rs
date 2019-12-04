extern crate serde_json;
use serde_json::Value;
use simple_error;
use sqldata;
use sqldata::{PdfList, PdfInfo};
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

#[derive(Serialize, Deserialize, Debug)]
pub struct ServerResponse {
  pub what: String,
  pub content: Value,
}

#[derive(Serialize, Deserialize, Debug)]
struct PdfNotes {
  pdf_name: String,
  notes: String,
}

#[derive(Deserialize, Serialize, Debug)]
struct PersistentState {
  pdf_name: String,
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
      let pl = sqldata::pdflist(pdbp)?;
      // println!("pdflist: {:?}", pl);
      Ok(Some(ServerResponse {
        what: "filelist".to_string(),
        content: serde_json::to_value(pl)?,
      }))
    }
    "savepdfstate" => {
      // write the pdfstate to the appropriate file.
      let json = msg
        .data
        .ok_or(simple_error::SimpleError::new("pdfstate data not found!"))?;
      let ps: PersistentState = serde_json::from_value(json.clone())?;
      sqldata::savePdfState(pdbp, ps.pdf_name.as_str(), json.to_string().as_str(), ps.last_read)?;
      Ok(Some(ServerResponse {
        what: "pdfstatesaved".to_string(),
        content: serde_json::Value::Null,
      }))
    }
    "getnotes" => {
      let json = msg
        .data
        .ok_or(simple_error::SimpleError::new("getnotes data not found!"))?;
      let pdfname: String = serde_json::from_value(json.clone())?;
      let notes = sqldata::getPdfNotes(pdbp, pdfname.as_str())?;
      let data = serde_json::to_value(PdfNotes {
        pdf_name: pdfname,
        notes: notes,
      })?;

      println!("getnotes: {}", data);
      Ok(Some(ServerResponse {
        what: "notesresponse".to_string(),
        content: data,
      }))
      // read the notes file, or if none exists return null.
    }
    "savenotes" =>
    {
      let json = msg
        .data
        .ok_or(simple_error::SimpleError::new("savenotes data not found!"))?;
      let pdfnotes: PdfNotes = serde_json::from_value(json.clone())?;
      sqldata::savePdfNotes(pdbp, pdfnotes.pdf_name.as_str(), pdfnotes.notes.as_str())?;
      Ok(Some(ServerResponse {
        what: "notesaved".to_string(),
        content: serde_json::Value::Null,
      }))
    }
    // get app state.
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
    // save app state.
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

