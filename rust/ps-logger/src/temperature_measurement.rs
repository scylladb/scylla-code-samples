use cdrs::{
  query::QueryValues,
  query_values,
  types::{from_cdrs::FromCDRSByName, prelude::*},
};
use time::Timespec;
use uuid::Uuid;

#[derive(Debug, TryFromRow)]
pub struct TemperatureMeasurement {
  pub device: Uuid,
  pub time: Timespec,
  pub temperature: i16,
}

impl TemperatureMeasurement {
  pub fn into_query_values(self) -> QueryValues {
    query_values!("device" => self.device, "time" => self.time, "temperature" => self.temperature)
  }
}
