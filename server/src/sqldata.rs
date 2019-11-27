
#[macro_use]
use rusqlite::types::ToSql;
use rusqlite::{Connection, Result, NO_PARAMS, params};
use time::Timespec;


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

#[derive(Debug)]
struct Person {
    id: i32,
    name: String,
    time_created: Timespec,
    data: Option<Vec<u8>>,
}

pub fn peeps() -> Result<()> {
    let conn = Connection::open_in_memory()?;

    // try creating a pdfinfo table.
    println!("pdfinfo create: {:?}", conn.execute(
        "CREATE TABLE pdfinfo ( 
                  name            TEXT NOT NULL PRIMARY KEY,
                  last_read       INTEGER,
                  persistentState BLOB,
                  notes           TEXT NOT NULL
                  )",
        params![],
    ));

    let pdoc = PdfInfo {
      last_read : Some(1)
      , filename : "blah".to_string()
      , state: None };

    let s : Option<PersistentState> = None;

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
    };
    

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
    };
    
    Ok(())
}
