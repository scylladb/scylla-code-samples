-- Q1: Find a Follower with a specific ID
SELECT owner_id, address, name FROM owner WHERE owner_id = ?;

-- Q2: Find the Pets that the follower tracks
SELECT owner_id, pet_id, age, weight, address, name FROM pet WHERE owner_id = ?;

-- Q3: Find the sensors of a dog
SELECT pet_id, sensor_id, type FROM sensor WHERE pet_id = ?;

-- Q4: Find the measurements for a sensor in a date range
SELECT sensor_id, ts, value FROM measurement WHERE sensor_id = ? AND ts <= ? and ts >= ?;

-- Q5: Find a daily summary of hour based aggregates
SELECT sensor_id, date, hour, value FROM sensor_avg WHERE sensor_id = ? AND date = ? ORDER BY date ASC, hour ASC;
