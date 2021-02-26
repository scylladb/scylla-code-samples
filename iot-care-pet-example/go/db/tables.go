package db

import (
	"github.com/scylladb/gocqlx/v2/table"
)

var TableOwner = table.New(OwnerMetadata)
var TablePet = table.New(PetMetadata)
var TableSensor = table.New(SensorMetadata)
var TableMeasure = table.New(MeasureMetadata)
var TableSensorAvg = table.New(SensorAvgMetadata)

var OwnerMetadata = table.Metadata{
	Name:    "owner",
	Columns: []string{"owner_id", "address", "name"},
	PartKey: []string{"owner_id"},
	SortKey: []string{},
}

var PetMetadata = table.Metadata{
	Name:    "pet",
	Columns: []string{"owner_id", "pet_id", "age", "weight", "address", "name"},
	PartKey: []string{"owner_id"},
	SortKey: []string{"pet_id"},
}

var SensorMetadata = table.Metadata{
	Name:    "sensor",
	Columns: []string{"pet_id", "sensor_id", "type"},
	PartKey: []string{"pet_id"},
	SortKey: []string{"sensor_id"},
}

var MeasureMetadata = table.Metadata{
	Name:    "measurement",
	Columns: []string{"sensor_id", "ts", "value"},
	PartKey: []string{"sensor_id"},
	SortKey: []string{"ts"},
}

var SensorAvgMetadata = table.Metadata{
	Name:    "sensor_avg",
	Columns: []string{"sensor_id", "date", "hour", "value"},
	PartKey: []string{"sensor_id"},
	SortKey: []string{"date", "hour"},
}
