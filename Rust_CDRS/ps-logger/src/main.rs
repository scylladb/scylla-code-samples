extern crate cdrs;
#[macro_use]
extern crate cdrs_helpers_derive;
extern crate r2d2;
extern crate time;
extern crate uuid;

mod db;
mod temperature_measurement;

use temperature_measurement::TemperatureMeasurement;
use uuid::Uuid;

fn main() {
    println!("connecting to db");
    let mut session = connect_to_db();

    println!("Adding measurements");
    let measurement = TemperatureMeasurement {
        device: Uuid::parse_str("72f6d49c-76ea-44b6-b1bb-9186704785db").unwrap(),
        time: time::Timespec::new(1000000000001, 0),
        temperature: 40,
    };
    db::add_measurement(&mut session, measurement).expect("add measurement error");

    let measurement = TemperatureMeasurement {
        device: Uuid::parse_str("72f6d49c-76ea-44b6-b1bb-9186704785db").unwrap(),
        time: time::Timespec::new(1000000000003, 0),
        temperature: 60,
    };
    db::add_measurement(&mut session, measurement).expect("add measurement error");

    println!("Selecting measurements");
    let measurements = db::select_measurements(
        &mut session,
        Uuid::parse_str("72f6d49c-76ea-44b6-b1bb-9186704785db").unwrap(),
        time::Timespec::new(1000000000000, 0),
        time::Timespec::new(1000000000009, 0),
    )
    .expect("select measurements error");
    println!("     >> Measurements: {:?}", measurements);
}

fn connect_to_db() -> db::CurrentSession {
    let mut session = db::create_db_session().expect("create db session error");
    db::create_keyspace(&mut session).expect("create keyspace error");
    db::create_temperature_table(&mut session).expect("create keyspace error");
    session
}
