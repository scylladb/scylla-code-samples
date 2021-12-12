use std::cell::RefCell;
use time::Timespec;
use uuid::Uuid;

use cdrs::{
  authenticators::NoneAuthenticator,
  cluster::{
    session::{
      new as new_session,
      // other option: new_lz4 as new_lz4_session,
      // other option: new_snappy as new_snappy_session
      Session,
    },
    ClusterTcpConfig, NodeTcpConfigBuilder, TcpConnectionPool,
  },
  load_balancing::SingleNode,
  query::*,
  query_values,
  transport::CDRSTransport,
  types::prelude::*,
  Error as CDRSError, Result as CDRSResult,
};

use crate::temperature_measurement::TemperatureMeasurement;

pub type CurrentSession = Session<SingleNode<TcpConnectionPool<NoneAuthenticator>>>;

static CREATE_KEYSPACE_QUERY: &'static str = r#"
  CREATE KEYSPACE IF NOT EXISTS fast_logger
    WITH REPLICATION = {
      'class': 'SimpleStrategy',
      'replication_factor': 1
    };
"#;

static CREATE_TEMPERATURE_TABLE_QUERY: &'static str = r#"
  CREATE TABLE IF NOT EXISTS fast_logger.temperature (
    device UUID,
    time timestamp,
    temperature smallint,
    PRIMARY KEY(device, time)
  );
"#;

static ADD_MEASUREMENT_QUERY: &'static str = r#"
  INSERT INTO fast_logger.temperature (device, time, temperature)
    VALUES (?, ?, ?);
"#;

static SELECT_MEASUREMENTS_QUERY: &'static str = r#"
  SELECT * FROM fast_logger.temperature
    WHERE device = ?
      AND time > ?
      AND time < ?;
"#;

pub fn create_db_session() -> CDRSResult<CurrentSession> {
  let auth = NoneAuthenticator;
  let node = NodeTcpConfigBuilder::new("127.0.0.1:9042", auth).build();
  let cluster_config = ClusterTcpConfig(vec![node]);
  new_session(&cluster_config, SingleNode::new())
}

pub fn create_keyspace<T, M>(session: &mut impl QueryExecutor<T, M>) -> CDRSResult<()>
where
  T: CDRSTransport + 'static,
  M: r2d2::ManageConnection<Connection = RefCell<T>, Error = CDRSError> + Sized,
{
  session.query(CREATE_KEYSPACE_QUERY).map(|_| (()))
}

pub fn create_temperature_table<T, M>(session: &mut impl QueryExecutor<T, M>) -> CDRSResult<()>
where
  T: CDRSTransport + 'static,
  M: r2d2::ManageConnection<Connection = RefCell<T>, Error = CDRSError> + Sized,
{
  session.query(CREATE_TEMPERATURE_TABLE_QUERY).map(|_| (()))
}

pub fn add_measurement<T, M>(
  session: &mut impl QueryExecutor<T, M>,
  measurement: TemperatureMeasurement,
) -> CDRSResult<()>
where
  T: CDRSTransport + 'static,
  M: r2d2::ManageConnection<Connection = RefCell<T>, Error = CDRSError> + Sized,
{
  session
    .query_with_values(ADD_MEASUREMENT_QUERY, measurement.into_query_values())
    .map(|_| (()))
}

pub fn select_measurements<T, M>(
  session: &mut impl QueryExecutor<T, M>,
  devices: Uuid,
  time_from: Timespec,
  time_to: Timespec,
) -> CDRSResult<Vec<TemperatureMeasurement>>
where
  T: CDRSTransport + 'static,
  M: r2d2::ManageConnection<Connection = RefCell<T>, Error = CDRSError> + Sized,
{
  let values = query_values!(devices, time_from, time_to);
  session
    .query_with_values(SELECT_MEASUREMENTS_QUERY, values)
    .and_then(|res| res.get_body())
    .and_then(|body| {
      body
        .into_rows()
        .ok_or(CDRSError::from("cannot get rows from a response body"))
    })
    .and_then(|rows| {
      let mut measurements: Vec<TemperatureMeasurement> = Vec::with_capacity(rows.len());

      for row in rows {
        measurements.push(TemperatureMeasurement::try_from_row(row)?);
      }

      Ok(measurements)
    })
}
