use chrono::{DateTime, Utc};
use uuid::Uuid;

use crate::result::Result;
use crate::temperature_measurement::TemperatureMeasurement;

mod db;
mod result;
mod temperature_measurement;

#[tokio::main]
async fn main() -> Result<()> {
    println!("connecting to db");
    let uri = std::env::var("SCYLLA_URI").unwrap_or_else(|_| "127.0.0.1:9042".to_string());
    let session = db::create_session(&uri).await?;
    db::initialize(&session).await?;

    println!("Adding measurements");
    let measurement = TemperatureMeasurement {
        device: Uuid::parse_str("72f6d49c-76ea-44b6-b1bb-9186704785db")?,
        time: DateTime::<Utc>::from_timestamp(1000000000001, 0).unwrap(),
        temperature: 40,
    };
    db::add_measurement(&session, measurement).await?;

    let measurement = TemperatureMeasurement {
        device: Uuid::parse_str("72f6d49c-76ea-44b6-b1bb-9186704785db")?,
        time: DateTime::<Utc>::from_timestamp(1000000000003, 0).unwrap(),
        temperature: 60,
    };
    db::add_measurement(&session, measurement).await?;

    println!("Selecting measurements");
    let measurements = db::select_measurements(
        &session,
        Uuid::parse_str("72f6d49c-76ea-44b6-b1bb-9186704785db")?,
        DateTime::<Utc>::from_timestamp(1000000000000, 0).unwrap(),
        DateTime::<Utc>::from_timestamp(1000000000009, 0).unwrap(),
    )
    .await?;
    println!("     >> Measurements: {:?}", measurements);

    Ok(())
}
