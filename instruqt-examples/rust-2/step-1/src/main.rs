use scylla::client::session::Session;
use scylla::client::session_builder::SessionBuilder;
use std::error::Error;

static CREATE_KEYSPACE_QUERY: &str = r#"
  CREATE KEYSPACE IF NOT EXISTS log
    WITH REPLICATION = {
      'class': 'NetworkTopologyStrategy',
      'replication_factor': 1
    };
"#;

static CREATE_ENTRIES_TABLE_QUERY: &str = r#"
  CREATE TABLE IF NOT EXISTS log.messages (
    id timestamp,
    message text,
    PRIMARY KEY(id)
  );
"#;

#[tokio::main]
async fn main() -> Result<(), Box<dyn Error>> {
    println!("connecting to db");
    let session: Session = SessionBuilder::new()
        .known_node("127.0.0.1:9042")
        .build()
        .await?;

    session.query_unpaged(CREATE_KEYSPACE_QUERY, &[]).await?;
    session
        .query_unpaged(CREATE_ENTRIES_TABLE_QUERY, &[])
        .await?;

    println!("done create keyspace and table");

    Ok(())
}
