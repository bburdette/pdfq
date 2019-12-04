#[macro_use]
use rusqlite::types::ToSql;
use rusqlite::{params, Connection, NO_PARAMS};
use serde_json;
use std::collections::BTreeSet;
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
pub struct PdfList {
  pdfs: Vec<PdfInfo>,
}

#[derive(Serialize, Debug)]
pub struct PdfInfo {
  last_read: Option<i64>,
  filename: String,
  state: Option<serde_json::Value>,
}

pub fn pdflist(dbfile: &Path) -> rusqlite::Result<PdfList> {
  let conn = Connection::open(dbfile)?;

  let mut pstmt = conn.prepare("SELECT name, last_read, persistentState FROM pdfinfo")?;
  let pdfinfo_iter = pstmt.query_map(params![], |row| {
    let ss: Option<String> = row.get(2)?;
    // we don't get the json parse error if there is one!
    let state: Option<serde_json::Value> = ss.and_then(|s| serde_json::from_str(s.as_str()).ok());

    Ok(PdfInfo {
      filename: row.get(0)?,
      last_read: row.get(1)?,
      state: state,
    })
  })?;

  let mut pv = Vec::new();

  for rspdfinfo in pdfinfo_iter {
    match rspdfinfo {
      Ok(pdfinfo) => {
        println!("Found pdfinfo {:?}", pdfinfo);
        pv.push(pdfinfo);
      }
      Err(_) => (),
    }
  }

  Ok(PdfList { pdfs: pv })
}

pub fn dbinit(dbfile: &Path) -> rusqlite::Result<()> {
  let conn = Connection::open(dbfile)?;

  // create the pdfinfo table.
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

  Ok(())
}

// create entries in the db for pdfs that aren't in there yet.
pub fn pdfentries(dbfile: &Path, pdfinfo: std::vec::Vec<PdfInfo>) -> rusqlite::Result<()> {
  let conn = Connection::open(dbfile)?;

  // get a set of the names in the db already.
  let mut pstmt = conn.prepare("SELECT name FROM pdfinfo")?;
  let pdfname_iter = pstmt.query_map(params![], |row| row.get(0))?;

  let mut nameset: BTreeSet<String> = BTreeSet::new();
  for pdfname in pdfname_iter {
    match pdfname {
      Ok(name) => nameset.insert(name),
      _ => false,
    };
  }

  println!("names: {:?}", nameset);

  for pi in pdfinfo {
    if !nameset.contains(&pi.filename) {
      println!("adding pdf: {}", pi.filename);
      conn.execute(
        "INSERT INTO pdfinfo (name, last_read, persistentState, notes)
                      VALUES (?1, ?2, ?3, '')",
        params![pi.filename, pi.last_read, ""],
      )?;
    }
  }

  // for each pdfinfo

  Ok(())
}
pub fn savePdfState(
  dbfile: &Path,
  pdfname: &str,
  pdfstate: &str,
  last_read: i64,
) -> rusqlite::Result<()> {
  let conn = Connection::open(dbfile)?;

  println!("savePdfState {} {}", pdfname, pdfstate);

  conn.execute(
    "update pdfinfo set persistentState = ?2, last_read = ?3 where name = ?1",
    params![pdfname, pdfstate, last_read],
  )?;

  Ok(())
}

pub fn getPdfNotes(dbfile: &Path, pdfname: &str) -> rusqlite::Result<String> {
  let conn = Connection::open(dbfile)?;

  let mut pstmt = conn.prepare("SELECT notes FROM pdfinfo WHERE name = ?1")?;
  let mut rows = pstmt.query(params![pdfname])?;

  match rows.next() {
    Ok(Some(row)) => row.get(0),
    Ok(None) => Err(rusqlite::Error::QueryReturnedNoRows),
    Err(e) => Err(e),
  }
}

pub fn savePdfNotes(dbfile: &Path, pdfname: &str, pdfnotes: &str) -> rusqlite::Result<()> {
  let conn = Connection::open(dbfile)?;

  conn.execute(
    "update pdfinfo set notes = ?2 where name = ?1",
    params![pdfname, pdfnotes],
  )?;

  Ok(())
}

// scan the pdf dir and return a pdfinfo for each file.
pub fn pdfscan(pdfdir: &str) -> Result<std::vec::Vec<PdfInfo>, Box<Error>> {
  let p = Path::new(pdfdir);

  let mut v = Vec::new();

  if p.exists() {
    for fr in p.read_dir()? {
      let f = fr?;
      let fname = f
        .file_name()
        .into_string()
        .map_err(|e| format!("bad pdf filename: {:?}", f))?;

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
        state: None,
      });

      // println!("eff {:?}", f);
    }
  } else {
    error!("pdf directory not found: {}", pdfdir);
  }

  Ok(v)
}
