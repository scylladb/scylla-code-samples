use chrono::{DateTime, Utc};
use futures::stream::StreamExt;
use scylla::client::session::Session;
use scylla::client::session_builder::SessionBuilder;
use scylla::statement::unprepared::Statement;
use std::error::Error;
use tokio::io::{stdin, AsyncBufReadExt, BufReader};

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

    let insert_message = session
        .prepare("INSERT INTO log.messages (id, message) VALUES (?, ?)")
        .await?;

    let mut lines_from_stdin = BufReader::new(stdin()).lines();
    while let Some(line) = lines_from_stdin.next_line().await? {
        let id = Utc::now();

        session.execute_unpaged(&insert_message, (id, line)).await?;
    }

    println!("session executed");

    let mut select_query = Statement::new("SELECT id, message FROM log.messages");
    select_query.set_is_idempotent(true);

    let mut row_stream = session
        .query_iter(select_query, &[])
        .await?
        .rows_stream::<(DateTime<Utc>, String)>()?;

    while let Some(row) = row_stream.next().await {
        let (id, message) = row?;
        println!("{}: {}", id, message);
    }

    Ok(())
}
