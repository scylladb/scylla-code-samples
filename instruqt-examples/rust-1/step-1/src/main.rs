
use crate::result::Result;

mod db;
mod result;
mod temperature_measurement;

#[tokio::main]
async fn main() -> Result<()> {
    println!("connecting to db");
    let uri = std::env::var("SCYLLA_URI").unwrap_or_else(|_| "127.0.0.1:9042".to_string());
    let session = db::create_session(&uri).await?;
    db::initialize(&session).await?;
    println!("db initialized");

    Ok(())
}
