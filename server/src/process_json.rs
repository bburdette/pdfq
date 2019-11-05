extern crate serde_json;
use failure;
use failure::Error;
use serde_json::Value;
use std::fs::File;
use std::io::Read;
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

// public json msgs don't require login.
pub fn process_public_json(
  ip: &Option<&str>,
  msg: PublicMessage,
) -> Result<Option<ServerResponse>, Error> {
  match msg.what.as_str() {
    "getfilelist" => {
      match msg.data {
        None => Ok(Some(ServerResponse {
          what: "!".to_string(),
          content: serde_json::Value::Null,
        })),
        Some(data) => {
          info!("{}", data);
          // match data.to_string().as_str(){ }
          Ok(Some(ServerResponse {
            what: "!".to_string(),
            content: serde_json::Value::Null,
          }))
        }
      }
    }
    wat => Err(failure::err_msg(format!("invalid 'what' code:'{}'", wat))),
  }
}
