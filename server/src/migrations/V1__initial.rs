use barrel::backend::Sqlite;
use barrel::{types, Migration};

pub fn migration() -> String {
  let mut m = Migration::new();

  m.create_table("pdfinfo", |t| {
    t.add_column("name", types::text().nullable(false).primary(true));
    t.add_column("last_read", types::integer());
    t.add_column( "persistentState", types::text() );
    t.add_column( "notes", types::text().nullable(false) );
  });

  // m.create_table("uistate", |t| {
  //   t.add_column("id", types::integer().nullable(false).primary(true));
  //   t.add_column("state", types::text());
  // });

  let s = m.make::<Sqlite>();
  println!("s: {}", s);
  s
}
