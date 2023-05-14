use crate::db::model::DbNote;

use futures::stream::StreamExt;
use scylla::load_balancing::DefaultPolicy;
use scylla::prepared_statement::PreparedStatement;
use scylla::statement::Consistency;
use scylla::transport::errors::QueryError;
use scylla::transport::ExecutionProfile;
use scylla::transport::Compression;
use scylla::{Session, SessionBuilder};
use std::fs;
use std::sync::Arc;
use std::time::Duration;
use std::time::Instant;
use tokio::sync::Semaphore;
use tokio::task::JoinHandle;
use tracing::{debug, error, info};
use uuid::Uuid;

pub struct ScyllaDbService {
    parallelism: usize,
    db_session: Arc<Session>,
    ps: Arc<PreparedStatement>,
}

const INSERT_QUERY: &str = "INSERT INTO mykb.notes (id, content, topic) VALUES (?, ?, ?)";
const GET_ONE_QUERY: &str = "SELECT id, content, topic FROM mykb.notes WHERE id = ?";
// order IS important for later case object into_typed cast
const DELETE_ONE_QUERY: &str = "DELETE FROM mykb.notes WHERE id = ?";
const GET_ALL_QUERY: &str = "SELECT * FROM mykb.notes"; // this is a FULL SCAN, it will only work for few thousands, then likely perf problems or timeouts might happen
                                                        // * is also very tricky here, since you get non-pk columns ordered by alphabet !!! (so copying it then has to be again in order)

// "SELECT count(*) FROM mykb.notes "

impl ScyllaDbService {
    pub async fn new(
        dc: String,
        host: String,
        db_user: String,
        db_password: String,
        db_parallelism: usize,
        schema_file: String,
    ) -> Self {
        debug!("ScyllaDbService: Connecting to {}. DC: {}.", host, dc);

        let default_policy = DefaultPolicy::builder()
            .prefer_datacenter(dc.to_string())
//            .prefer_rack("rack1".to_string())
            .token_aware(true)
            .permit_dc_failover(false)
            .build();
        let profile = ExecutionProfile::builder()
            .load_balancing_policy(default_policy)
            .build();
        let handle = profile.into_handle();

        let session: Session = SessionBuilder::new()
            .user(db_user, db_password)
            .known_node(host.clone())
            .default_execution_profile_handle(handle)
            .compression(Some(Compression::Lz4))
            .build()
            .await
            .expect("Error Connecting to ScyllaDB");

        info!("ScyllaDbService: Connected to {}", host);

        info!("ScyllaDbService: Creating Schema..");

        let schema = fs::read_to_string(&schema_file).unwrap_or_else(|_| {
            panic!(
                "{}",
                ("Error Reading Schema File".to_owned() + schema_file.as_str()).as_str()
            )
        });

        let schema_query = schema.trim().replace('\n', "");

        for q in schema_query.split(';') {
            let query = q.to_owned() + ";";
            if !query.starts_with("--") && query.len() > 1 {
                info!("Running Query {}", query);
                session
                    .query(query, &[])
                    .await
                    .expect("Error creating schema!");
            }
        }

        if session
            .await_timed_schema_agreement(Duration::from_secs(10))
            .await
            .expect("Error Awaiting Schema Creation")
        {
            info!("Schema Created!");
        } else {
            panic!("Timed schema is NOT in agreement");
        }

        info!("ScyllaDbService: Schema created. Creating preprared query...");
        let mut ps = session
            .prepare(INSERT_QUERY)
            .await
            .expect("Error Creating Prepared Query");
        ps.set_consistency(Consistency::Quorum);

        let db_session = Arc::new(session);
        info!("ScyllaDbService: Parallelism {}", db_parallelism);

        let prepared_query = Arc::new(ps);

        ScyllaDbService {
            db_session,
            parallelism: db_parallelism,
            ps: prepared_query,
        }
    }

    pub async fn delete_note(
        &self,
        id: &str,
    ) -> Result<Option<QueryError>, Box<dyn std::error::Error + Sync + Send>> {
        return self.delete_note_int(id).await;
    }

    async fn delete_note_int(
        &self,
        id: &str,
    ) -> Result<Option<QueryError>, Box<dyn std::error::Error + Sync + Send>> {
        let now = Instant::now();
        info!("ScyllaDbService: delete_note: {} ", id);

        let uuid = Uuid::parse_str(id)?;

        let q = DELETE_ONE_QUERY;

        let session = self.db_session.clone();
        let result = session.query(q, (uuid,)).await;

        let elapsed = now.elapsed();
        info!(
            "ScyllaDbService: delete_note: Deleted note {}. Took {:.2?}",
            id, elapsed
        );

        Ok(result.err())
    }

    pub async fn get_notes(&self) -> Result<Vec<DbNote>, Box<dyn std::error::Error + Sync + Send>> {
        return self.get_notes_int().await;
    }

    async fn get_notes_int(&self) -> Result<Vec<DbNote>, Box<dyn std::error::Error + Sync + Send>> {
        let now = Instant::now();
        info!("ScyllaDbService: get_notes: ");

        let mut ret = vec![];

        let q = GET_ALL_QUERY;

        let session = self.db_session.clone();
        let mut result = session.query_iter(q, ()).await?.into_typed::<DbNote>();
        //TODO  this should be implemented by paging towards REST, not by creating this huge response
        while let Some(r) = result.next().await {
            let note = r.unwrap();
            ret.push(note);
        }

        let elapsed = now.elapsed();
        info!(
            "ScyllaDbService: get_notes: Got notes: {}. Took {:.2?}",
            ret.len(),
            elapsed
        );

        Ok(ret)
    }

    pub async fn get_note(
        &self,
        id: &str,
    ) -> Result<Vec<DbNote>, Box<dyn std::error::Error + Sync + Send>> {
        return self.get_note_int(id).await;
    }

    async fn get_note_int(
        &self,
        id: &str,
    ) -> Result<Vec<DbNote>, Box<dyn std::error::Error + Sync + Send>> {
        let now = Instant::now();
        info!("ScyllaDbService: get_note: {} ", id);

        let uuid = Uuid::parse_str(id)?;
        let mut ret = vec![];

        let q = GET_ONE_QUERY;

        let session = self.db_session.clone();
        let result = session.query(q, (uuid,)).await?;

        if let Some(rows) = result.rows {
            for r in rows {
                let node = r.into_typed::<DbNote>()?;
                // let simple = r.into_typed::<DbNoteSimple>()?;
                // node = DbNote::from_simple(simple);
                ret.push(node);
            }
        }

        let elapsed = now.elapsed();
        info!(
            "ScyllaDbService: get_note: Got note {}. Took {:.2?}",
            id, elapsed
        );

        Ok(ret)
    }

    pub async fn save_note(
        &self,
        entry: DbNote,
    ) -> Result<(), Box<dyn std::error::Error + Sync + Send>> {
        let now = Instant::now();
        let sem = Arc::new(Semaphore::new(self.parallelism));
        info!("ScyllaDbService: save_nodes: Saving Nodes...");

        let mut i = 0;
        let mut handlers: Vec<JoinHandle<_>> = Vec::new();

        let session = self.db_session.clone();
        let prepared = self.ps.clone();
        let permit = sem.clone().acquire_owned().await;
        debug!("save_nodes: Creating Task...");
        handlers.push(tokio::task::spawn(async move {
            debug!("save_nodes: Running query for node {}", entry.topic);
            let result = session
                .execute(&prepared, (entry.id, entry.content, entry.topic))
                .await;

            let _permit = permit;

            result
        }));
        debug!("save_nodes: Task Created");
        i += 1;

        info!(
            "ScyllaDbService: save_nodes: Waiting for {} tasks to complete...",
            i
        );

        let mut error_count = 0;
        for thread in handlers {
            match thread.await? {
                Err(e) => {
                    error!("save_nodes: Error Executing Query. {:?}", e);
                    error_count += 1;
                }
                Ok(r) => debug!("save_nodes: Query Result: {:?}", r),
            };
        }

        let elapsed = now.elapsed();
        info!(
            "ScyllaDbService: save_nodes: {} save nodes tasks completed. ERRORS: {}. Took: {:.2?}",
            i, error_count, elapsed
        );
        Ok(())
    }
}
