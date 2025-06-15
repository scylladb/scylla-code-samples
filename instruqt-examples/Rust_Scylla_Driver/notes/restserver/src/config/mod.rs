use color_eyre::Result;
use dotenv::dotenv;
use eyre::WrapErr;

use serde::Deserialize;
use tracing::{debug, info};
use tracing_subscriber::EnvFilter;

#[derive(Debug, Deserialize, Clone)]
pub struct Config {
    pub host: String,
    pub port: i32,
    pub db_url: String,
    pub db_user: String,
    pub db_password: String,
    pub db_dc: String,
    pub parallel_inserts: usize,
    pub db_parallelism: usize,
    pub schema_file: String,
}

fn init_tracer() {
    #[cfg(debug_assertions)]
    let tracer = tracing_subscriber::fmt();
    #[cfg(not(debug_assertions))]
    let tracer = tracing_subscriber::fmt().json();

    tracer.with_env_filter(EnvFilter::from_default_env()).init();
}

impl Config {
    pub fn from_env() -> Result<Config> {
        dotenv().ok();

        init_tracer();

        info!("Loading configuration");

        let c = config::Config::builder()
            .set_default("host", "localhost")?
            .set_default("port", 3001)?
            .set_default("db_url", "localhost:9042")?
            .set_default("db_user", "cassandra")?
            .set_default("db_password", "cassandra")?
            .set_default("parallel_inserts", 100)?
            .set_default("db_parallelism", 100)?
            .add_source(config::Environment::default())
            .build()
            .unwrap();

        let config = c
            .try_deserialize()
            .context("loading configuration from environment");

        debug!("Config: {:?}", config);
        config
    }
}
