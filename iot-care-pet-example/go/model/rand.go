package model

import "math/rand"

func RandOwner() *Owner {
	return &Owner{
		OwnerID: RandomUUID(),
		Address: "home",
		Name:    RandomString(8),
	}
}

func RandPet(o *Owner) *Pet {
	return &Pet{
		OwnerID: o.OwnerID,
		PetID:   RandomUUID(),
		Age:     1 + rand.Intn(100),
		Weight:  float32(5 + rand.Intn(10)),
		Address: "home",
		Name:    RandomString(8),
	}
}

func RandSensor(o *Pet) *Sensor {
	return &Sensor{
		PetID:    o.PetID,
		SensorID: RandomUUID(),
		Type:     SensorTypes[rand.Intn(len(SensorTypes))],
	}
}

func RandSensorData(s *Sensor) float32 {
	switch s.Type {
	case SensorTypeTemperature:
		// average F
		return float32(101 + rand.Intn(10) - 4)
	case SensorTypePulse:
		// average beat per minute
		return float32(100 + rand.Intn(40) - 20)
	case SensorTypeRespiration:
		// average inhales per minute
		return float32(35 + rand.Intn(5) - 2)
	case SensorTypeLocation:
		// pet can teleport
		return 90 * rand.Float32()
	default:
		return 0.0
	}
}
