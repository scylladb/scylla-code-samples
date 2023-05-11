mod config;
mod data;
mod db;

extern crate num_cpus;
extern crate serde_json;

use crate::config::Config;
use crate::db::scylladb::ScyllaDbService;
use actix_web::error::ErrorInternalServerError;
use actix_web::middleware::Logger;
use actix_web::web::Json;
use actix_web::{delete, get, post, web, web::Data, App, Error, HttpResponse, HttpServer};
use color_eyre::Result;
use data::model::Note;
use data::rest_api::AddNoteRequest;
use std::sync::Arc;
use std::time::Instant;
use tokio::sync::{AcquireError, OwnedSemaphorePermit, Semaphore};
use tokio::task;
use tokio::task::JoinHandle;
use tracing::{debug, error, info};

use crate::db::model::DbNote;
use scylla::transport::errors::QueryError;
use std::string::ToString;
use uuid::Uuid;

use actix_cors::Cors;
//use actix_web::http::header;

struct AppState {
    db_svc: ScyllaDbService,
    semaphore: Arc<Semaphore>,
}

#[get("/notes")]
async fn get_all_notes(state: Data<AppState>) -> Result<HttpResponse, Error> {
    let now = Instant::now();
    info!("get_all_notes");

    //TODO this needs to be improved with paging
    let ret = get_notes(&state.db_svc).await?;

    let elapsed = now.elapsed();
    info!("get_all time: {:.2?}", elapsed);
    Ok(HttpResponse::Ok().json(ret))
}

async fn get_notes(db: &ScyllaDbService) -> Result<Vec<Json<Note>>, Error> {
    let db_notes = db.get_notes().await.map_err(ErrorInternalServerError)?;

    let notes = Note::from_all(db_notes);
    let jiter = notes.into_iter();
    let mut ret = vec![];
    for note in jiter {
        ret.push(web::Json(note));
    }
    Ok(ret)
}

#[get("/note/{id}")]
async fn get_by_id(path: web::Path<String>, state: Data<AppState>) -> Result<HttpResponse, Error> {
    let now = Instant::now();
    let id = path.into_inner();
    info!("get_by_id {}", id);

    let ret = get_note(&state.db_svc, &id).await?;

    let elapsed = now.elapsed();
    info!("get_by_id time: {:.2?}", elapsed);
    Ok(HttpResponse::Ok().json(ret))
}

#[delete("/note/{id}")]
async fn delete_by_id(
    path: web::Path<String>,
    state: Data<AppState>,
) -> Result<HttpResponse, Error> {
    let now = Instant::now();
    let id = path.into_inner();
    info!("get_by_id {}", id);

    let ret = delete_note(&state.db_svc, &id).await?;

    let elapsed = now.elapsed();
    info!("delete_by_id time: {:.2?}", elapsed);
    if ret.is_some() {
        Err(ErrorInternalServerError(ret.unwrap().to_string()))
    } else {
        Ok(HttpResponse::Ok().json(r#"{ "status": "OK"}"#))
    }
}

async fn delete_note(db: &ScyllaDbService, id: &str) -> Result<Option<QueryError>, Error> {
    let ret = db.delete_note(id).await.map_err(ErrorInternalServerError);
    ret
}

async fn get_note(db: &ScyllaDbService, id: &str) -> Result<Json<Option<Note>>, Error> {
    let db_notes = db.get_note(id).await.map_err(ErrorInternalServerError)?;

    let note = Note::from(db_notes);

    Ok(web::Json(note))
}

#[post("/note")]
async fn insert_note(
    payload: web::Json<AddNoteRequest>,
    state: Data<AppState>,
) -> Result<HttpResponse, Error> {
    info!("Ingest Request: {:?}", payload.topic);
    let now = Instant::now();

    let mut handlers: Vec<JoinHandle<_>> = Vec::new(); //sample multi insert parsing

    let jid = payload.id.clone().unwrap_or_default();
    let permit = state.semaphore.clone().acquire_owned().await;
    let id = if !jid.is_empty() {
        Uuid::parse_str(jid.as_str()).unwrap()
    } else {
        Uuid::new_v4()
    };
    handlers.push(task::spawn(add_note(
        id,
        state.clone(),
        payload.topic.to_string(),
        payload.content.to_string(),
        permit,
    )));

    debug!("Waiting for notes to be processed...");
    for thread in handlers {
        match thread.await {
            Err(e) => return Err(ErrorInternalServerError(e)),
            Ok(r) => {
                if let Err(e) = r {
                    error!("Error: {:?}", e);
                    return Err(ErrorInternalServerError(e));
                }
            }
        }
    }

    let elapsed = now.elapsed();
    info!("Ingestion Time: {:.2?}", elapsed);
    Ok(HttpResponse::Ok().json(r#"{ "status": "OK"}"#))
}

async fn add_note(
    id: Uuid,
    state: Data<AppState>,
    topic: String,
    content: String,
    permit: Result<OwnedSemaphorePermit, AcquireError>,
) -> Result<(), Box<dyn std::error::Error + Sync + Send>> {
    let ltopic = topic.clone();
    info!("Processing note {} with ID {}. ", ltopic, id);
    let now = Instant::now();
    // persist in DB and wait
    state
        .db_svc
        .save_note(DbNote { id, topic, content })
        .await?;

    let elapsed = now.elapsed();
    info!("Note {} processed. Took {:.2?}", ltopic, elapsed);

    let _permit = permit;

    Ok(())
}

#[actix_web::main]
async fn main() -> Result<()> {
    let config = Config::from_env().expect("Server configuration");

    let port = config.port;
    let host = config.host.clone();
    let num_cpus = num_cpus::get();
    let parallel_inserts = config.parallel_inserts;
    let db_parallelism = config.db_parallelism;

    info!(
        "Starting application. Num CPUs {}. Max Parallel Files {}. DB Parallelism {}. ",
        num_cpus, parallel_inserts, db_parallelism
    );

    let db = ScyllaDbService::new(
        config.db_dc,
        config.db_url,
        config.db_user,
        config.db_password,
        db_parallelism,
        config.schema_file,
    )
    .await;

    let sem = Arc::new(Semaphore::new(parallel_inserts));
    let data = Data::new(AppState {
        db_svc: db,
        semaphore: sem,
    });

    info!("Starting server at http://{}:{}/", host, port);
    //     let cors = Cors::default() //if you want production safe code, you need to send Cors headers in your server
    // //        .allowed_origin("http://localhost")
    //         .send_wildcard()
    //         .allowed_methods(vec!["GET", "POST", "DELETE"])
    //         .allowed_headers(vec![header::AUTHORIZATION, header::ACCEPT])
    //         .allowed_header(header::CONTENT_TYPE)
    //         .max_age(3600);

    HttpServer::new(move || {
        let cors_develop = Cors::permissive(); //temporary development trick
        App::new()
            .wrap(cors_develop)
            .wrap(Logger::default())
            .app_data(data.clone())
            .service(insert_note)
            .service(get_all_notes)
            .service(get_by_id)
            .service(delete_by_id)
    })
    .bind(format!("{}:{}", host, port))?
    .workers(num_cpus * 2)
    .run()
    .await?;

    Ok(())
}
