use scylla::client::session::Session;
use scylla::client::session_builder::SessionBuilder;

use crate::Result;

static CREATE_KEYSPACE_QUERY: &str = r#"
  CREATE KEYSPACE IF NOT EXISTS fast_logger
    WITH REPLICATION = {
      'class': 'NetworkTopologyStrategy',
      'replication_factor': 1
    };
"#;

static CREATE_TEMPERATURE_TABLE_QUERY: &str = r#"
  CREATE TABLE IF NOT EXISTS fast_logger.temperature (
    device UUID,
    time timestamp,
    temperature smallint,
    PRIMARY KEY(device, time)
  );
"#;

pub async fn create_session(uri: &str) -> Result<Session> {
    SessionBuilder::new()
        .known_node(uri)
        .build()
        .await
        .map_err(From::from)
}

pub async fn initialize(session: &Session) -> Result<()> {
    create_keyspace(session).await?;
    create_temperature_table(session).await?;
    Ok(())
}

async fn create_keyspace(session: &Session) -> Result<()> {
    session
        .query_unpaged(CREATE_KEYSPACE_QUERY, ())
        .await
        .map(|_| ())
        .map_err(From::from)
}

async fn create_temperature_table(session: &Session) -> Result<()> {
    session
        .query_unpaged(CREATE_TEMPERATURE_TABLE_QUERY, ())
        .await
        .map(|_| ())
        .map_err(From::from)
}

