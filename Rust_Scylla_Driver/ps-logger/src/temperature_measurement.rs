use uuid::Uuid;

use scylla::FromRow;
use scylla::ValueList;

use crate::Duration;

#[derive(Debug, FromRow, ValueList)]
pub struct TemperatureMeasurement {
    pub device: Uuid,
    pub time: Duration,
    pub temperature: i16,
}
