use uuid::Uuid;

use chrono::{DateTime, Utc};
use scylla::{DeserializeRow, SerializeRow};

#[derive(Debug, SerializeRow, DeserializeRow)]
pub struct TemperatureMeasurement {
    pub device: Uuid,
    pub time: DateTime<Utc>,
    pub temperature: i16,
}
