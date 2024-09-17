
#![allow(warnings, unused)]
use chrono::NaiveDate;
use chrono::{DateTime, NaiveDateTime, TimeZone, Utc};
use rand::Rng;
use rand::seq::SliceRandom;
use rand::thread_rng;
use scylla::frame::value::CqlTimestamp;
use scylla::frame::value::ValueList;
use scylla::prepared_statement::PreparedStatement;
use scylla::statement::Consistency;
use scylla::load_balancing::DefaultPolicy;
use scylla::transport::ExecutionProfile;
use scylla::transport::retry_policy::DefaultRetryPolicy;
use scylla::transport::downgrading_consistency_retry_policy::DowngradingConsistencyRetryPolicy;
use scylla::transport::Compression;
use scylla::IntoTypedRows;
use scylla::{Session, SessionBuilder};
use std::env;
use std::error::Error;
use std::process;
use std::sync::Arc;
use std::time::Duration;
use std::{thread, time};
use std::sync::atomic::{AtomicU32, Ordering};
use std::ops::{Deref, Range};
use tokio::sync::Semaphore;
use uuid::Uuid;

fn help() {
    println!("usage: <host> <dc> <user> <password> <filter_value>");
    println!("<filter_value> for column owner_id to be filtered on");
}

#[tokio::main]
async fn main() -> Result<(), Box<dyn Error>> {
    // Simple argparse

    let args: Vec<String> = env::args().collect();

    let mut host = "127.0.0.1";
    let mut dc = "datacenter1";
    let mut usr = "scylla";
    let mut pwd = "scylla";

    let mut filter_value = "d46cb523-4202-4212-a8e9-024d46529907";
    filter_value = "00000000-0000-046f-0000-00000000046f";
    filter_value = "00000000-0000-0000-0000-000000000000";

    let delete= false;
    let ttlUpdate = false;
    let TTLinS=100000;

    host = "192.168.1.120";
    dc = "datacenter1";
    usr = "fullscan";
    pwd = "password";

    match args.len() {
        1 => {
            println!("Using default values (pass as params to override). Host: {}, DC: {}, Username: {}, Password: ********", host, dc, usr);
        }
        2 => {
            host = &args[1];
        }
        3 => {
            host = &args[1];
            dc = &args[2];
        }
        5 => {
            host = &args[1];
            dc = &args[2];
            usr = &args[3];
            pwd = &args[4];
        }
        6 => {
            host = &args[1];
            dc = &args[2];
            usr = &args[3];
            pwd = &args[4];
            filter_value = &args[5];
        }
        _ => {
            help();
        }
    }

    let ks = "datastore";
    let table = "data";

    use std::time::Instant;
    let now = Instant::now();

    // Initiate cluster session
    println!("Connecting to {} ...", host);
    let default_policy = DefaultPolicy::builder()
        .prefer_datacenter(dc.to_string())
        .token_aware(true)
        .enable_shuffling_replicas(true)
        .permit_dc_failover(false)
        .build();

    println!("Load balancing policy: {:?}",default_policy);

    let profile = ExecutionProfile::builder()
        .load_balancing_policy(default_policy)
        .build();

    let handle = profile.into_handle();

    let session: Session = SessionBuilder::new()
        .known_node(host)
        .default_execution_profile_handle(handle)
        .compression(Some(Compression::Lz4))
        .user(usr, pwd)
        .build()
        .await?;
    let session = Arc::new(session);

    println!("Connected successfully!");

    // Set-up full table scan token ranges, shards and nodes

    let min_token = -(i128::pow(2, 63) - 1);
    let max_token = (i128::pow(2, 63) - 1);
    println!("Min token: {} \nMax token: {}", min_token, max_token);

    //TODO below should be parametrized
    let num_nodes = 3;
    // below is important - it should mimick max load we can put on scylla nodes (e.g. if we want to make busy 2 out of 14 cpus used, then cores per node should be set to that)
    // both below and above numbers will also mandate size of loader/executor of this code
    let cores_per_node = 2;

    // Parallelism is number of nodes * shards * 300% (ensure we keep them busy)
    //TODO maybe parametrize this 3 value, we need a loader big enough to take care of below
    // could we count it dynamically based on loader cpus ? or some input to not overload cluster?
    let PARALLEL = (num_nodes * cores_per_node * 3);

    // Subrange is a division applied to our token ring. How many queries we'll send in total ?
    // each thread will carry on below multiplier number of queries
    let SUBRANGE = PARALLEL * 1000;

    println!(
        "Max Parallel queries: {}\nToken-ring Subranges:{}",
        PARALLEL, SUBRANGE
    );

    // How many tokens are there?
    let total_token = max_token - min_token;
    println!("Total tokens: {}", total_token);

    // Chunk size determines the number of iterations needed to query the whole token ring
    let chunk_size = total_token / SUBRANGE;
    println!("Number of iterations: {}", chunk_size);

//    let stmt = format!("SELECT id, group_id, owner_id FROM {}.{} WHERE token(id, group_id) >= ? AND token(id, group_id) <= ? and owner_id = {}  BYPASS CACHE", ks, table, filter_value);
// Above just works WITHOUT tokens if there is an index on top of owner_id and is a SINGLE query !!! (so no need for all above token scans)
    let timeout_in_s ="300";
    // IF NO index is created you need ALLOW FILTERING and you scan WHOLE DB !!!
    let stmt = format!("SELECT id, group_id, owner_id FROM {}.{} WHERE token(id, group_id) >= ? AND token(id, group_id) <= ? and owner_id = {}  ALLOW FILTERING BYPASS CACHE USING TIMEOUT {}s", ks, table, filter_value, timeout_in_s);

    let stmt_delete = format!("DELETE FROM {}.{} WHERE id = ? AND group_id = ?", ks, table);

    //SELECT id, group_id, owner_id FROM datastore.data WHERE token(id, group_id) >= -9222211942430207527 AND token(id, group_id) <= -9198124745268510018 and owner_id = 00000000-0000-046f-0000-00000000046f  ALLOW FILTERING BYPASS CACHE;

    // Prepare Statement - use LocalQuorum
    let mut ps: PreparedStatement = session.prepare(stmt).await?;
    ps.set_consistency(Consistency::LocalQuorum);
    // Retry policy
    ps.set_retry_policy(Some(Arc::new(DefaultRetryPolicy::new())));
    ps.set_retry_policy(Some(Arc::new(DowngradingConsistencyRetryPolicy::new())));

    let mut ps_delete: PreparedStatement = session.prepare(stmt_delete).await?;
    ps_delete.set_consistency(Consistency::LocalQuorum);
    // Retry policy
    ps_delete.set_retry_policy(Some(Arc::new(DefaultRetryPolicy::new())));
    ps_delete.set_retry_policy(Some(Arc::new(DowngradingConsistencyRetryPolicy::new())));

    println!("Running full scan ... ");

    // 1. Spawn a new semaphore to limit number of threads run on this executor - make sure it's big enough
    //if we want to take over whole loader VM, then 2x cpus of loader VM should give max parallelism ?
    let sem = Arc::new(Semaphore::new((PARALLEL) as usize));

    let mut mcounter = Arc::new(AtomicU32::new(0));

    // Initiate querying the token ring
    //below needs shuffling, so we don't create hot partitions
    let ranges = (min_token..max_token).step_by((chunk_size as usize));
    let mut vranges: Vec<i128> = ranges.collect();
    let mut rng = thread_rng();
    //shuffled vector should do
    vranges.shuffle(&mut rng);
    for x in vranges { // TODO to distribute horizontally we need a way to split this list to multiple nodes, also with good distributed shuffling
        let session = session.clone();
        let ps = ps.clone();
        let ps_delete = ps_delete.clone();
        let permit = sem.clone().acquire_owned().await;

        let mut v = vec![(x as i64), ((x + chunk_size - 1) as i64)];
        // Debug: Run this [ cargo run 172.17.0.2 north ks bla| egrep '^.[0-9][0-9][0-9][0-9][0-9]' | wc -l ]
        // This will return exact SUBRANGES numbers ;-)
        // println!("Querying: {} to {}", v[0], v[1]);
        let counter = Arc::clone(&mcounter);
        tokio::task::spawn(async move {
            if let Some(query_result) = session.execute_unpaged(&ps, (&v[0], &v[1])).await.unwrap().rows {
                for row in query_result {
                    if row.columns[0] != None {
                        // val filtered_dataset = dataset.filter(row =>
                        //                                       row.getString(3) == filterValue //row.fieldIndex(compareFieldName)  // IF we have our subset of data found
                        //                                           && row.get(4) == null // IF TTL is null (so old data before alter TTL was done, we can even check if TTL is too low, etc. )
                        // )
                        counter.fetch_add(1, Ordering::SeqCst);
                        // process the row here - sample ETL
                        //TTL or delete ?
                        if delete {
                            let typed_row = row.into_typed::<(Uuid, Uuid, Uuid)>();
                            let (id, group_id, owner_id) = typed_row.unwrap();
                            //TODO move this to separate execution group to avoid blocking
                            let delete = session.execute_unpaged(&ps_delete, (&id, &group_id)).await.unwrap().warnings;
                        }

                        if ttlUpdate {
                            //TODO we need to read and then write WHOLE row so all cells get the TTL update
                        }
                        // (  id uuid,
                        //                        group_id uuid,
                        //                        owner_id uuid,
                        //                        data blob,
                        //                        changed_at timestamp,
                        //                        PRIMARY KEY ((id, group_id)) )

                    }

                }
            }
            let _permit = permit;
        });
    }

    // Wait for all in-flight requests to finish
    for _ in 0..PARALLEL {
        sem.acquire().await.unwrap().forget();
    }

    println!("Found owner_id {} with count {:?}", filter_value, mcounter);

    let elapsed = now.elapsed();
    println!("Time it took to run above full scan: {:.2?}", elapsed);

    // Print final metrics
    let metrics = session.get_metrics();
    println!("Queries requested: {}", metrics.get_queries_num());
    println!("Iter queries requested: {}", metrics.get_queries_iter_num());
    println!("Iter errors occured: {}", metrics.get_errors_iter_num());
    println!("Errors occured: {}", metrics.get_errors_num());
    println!("Retries occured: {}", metrics.get_retries_num());
    println!("Average latency: {}", metrics.get_latency_avg_ms().unwrap());
    println!(
        "95 percentile latency: {}",
        metrics.get_latency_percentile_ms(95.0).unwrap()
    );
    println!(
        "99.9 percentile latency: {}",
        metrics.get_latency_percentile_ms(99.9).unwrap()
    );

    Ok(())
}