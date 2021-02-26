package model

const SensorTypeTemperature = "T"
const SensorTypePulse = "P"
const SensorTypeLocation = "L"
const SensorTypeRespiration = "R"

var SensorTypes = []string{
	SensorTypeTemperature,
	SensorTypePulse,
	SensorTypeLocation,
	SensorTypeRespiration,
}

type Sensor struct {
	PetID    UUID
	SensorID UUID
	Type     string
}
