#[macro_use]
use rusqlite::types::ToSql;
use rusqlite::{params, Connection, NO_PARAMS};
use std::convert::TryInto;
use std::error::Error;
use std::fs::File;
use std::io::Read;
use std::path::{Path, PathBuf};
use std::time::{Duration, SystemTime, UNIX_EPOCH};
use time::Timespec;
use util;

/*
// use std::fs::File;
// use std::io::Read;
extern crate serde_json;
use serde_json::Value;
use simple_error;
use std::convert::TryInto;
use std::error::Error;
use std::path::{Path, PathBuf};
use std::time::{Duration, SystemTime, UNIX_EPOCH};
use util;
use sqldata;
*/

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
  pdf_name: String,
  notes: String,
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

#[derive(Debug)]
struct Person {
  id: i32,
  name: String,
  time_created: Timespec,
  data: Option<Vec<u8>>,
}

pub fn pdfdb() -> rusqlite::Result<()> {
  let conn = Connection::open_in_memory()?;

  // try creating a pdfinfo table.
  println!(
    "pdfinfo create: {:?}",
    conn.execute(
      "CREATE TABLE pdfinfo ( 
                  name            TEXT NOT NULL PRIMARY KEY,
                  last_read       INTEGER,
                  persistentState BLOB,
                  notes           TEXT NOT NULL
                  )",
      params![],
    )
  );

  let pdoc = PdfInfo {
    last_read: Some(1),
    filename: "blah".to_string(),
    state: None,
  };

  let s: Option<PersistentState> = None;

  conn.execute(
    "INSERT INTO pdfinfo (name, last_read, persistentState, notes)
                  VALUES (?1, ?2, ?3, '')",
    params![pdoc.filename, pdoc.last_read, ""],
  )?;

  let mut pstmt = conn.prepare("SELECT name, last_read, notes FROM pdfinfo")?;
  let pdfinfo_iter = pstmt.query_map(params![], |row| {
    Ok(PdfInfo {
      filename: row.get(0)?,
      last_read: row.get(1)?,
      state: None,
      // state: row.get(2)?,
      // notes: row.get(3)?,
    })
  })?;

  for pdfinfo in pdfinfo_iter {
    println!("Found pdfinfo {:?}", pdfinfo.unwrap());
  }

  Ok(())
}


// fn pdfentries(Result<std::vec::Vec<PdfInfo>, Box<Error>> {
// }

// scan the pdf dir and return a pdfinfo for each file.
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


pub fn peeps() -> rusqlite::Result<()> {
  let conn = Connection::open_in_memory()?;

  conn.execute(
    "CREATE TABLE person (
                  id              INTEGER PRIMARY KEY,
                  name            TEXT NOT NULL,
                  time_created    TEXT NOT NULL,
                  data            BLOB
                  )",
    params![],
  )?;
  let me = Person {
    id: 0,
    name: "Steven".to_string(),
    time_created: time::get_time(),
    data: None,
  };
  conn.execute(
    "INSERT INTO person (name, time_created, data)
                  VALUES (?1, ?2, ?3)",
    params![me.name, me.time_created, me.data],
  )?;

  let mut stmt = conn.prepare("SELECT id, name, time_created, data FROM person")?;
  let person_iter = stmt.query_map(params![], |row| {
    Ok(Person {
      id: row.get(0)?,
      name: row.get(1)?,
      time_created: row.get(2)?,
      data: row.get(3)?,
    })
  })?;

  for person in person_iter {
    println!("Found person {:?}", person.unwrap());
  }

  Ok(())
}
