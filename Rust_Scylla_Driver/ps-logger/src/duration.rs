use scylla::frame::response::result::CqlValue;
use scylla::frame::value::{Value, ValueTooBig};
use scylla::frame::{
    response::cql_to_rust::{FromCqlVal, FromCqlValError},
    value::Timestamp,
};

#[derive(Debug)]
pub struct Duration(chrono::Duration);

impl Duration {
    pub fn seconds(secs: i64) -> Self {
        Self(chrono::Duration::seconds(secs))
    }
}

impl Value for Duration {
    fn serialize(&self, buf: &mut Vec<u8>) -> Result<(), ValueTooBig> {
        Timestamp(self.0).serialize(buf)
    }
}

impl FromCqlVal<Option<CqlValue>> for Duration {
    fn from_cql(cql_val: Option<CqlValue>) -> Result<Self, FromCqlValError> {
        chrono::Duration::from_cql(cql_val).map(Self)
    }
}
