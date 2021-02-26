package handler

import (
	"log"
	"net/http"
	"time"

	"github.com/go-openapi/runtime/middleware"

	"github.com/scylladb/scylla-code-samples/iot-care-pet-example/go/cmd/server/restapi/operations"
	"github.com/scylladb/gocqlx/v2"
)

// FindSensorDataBySensorIDAndTimeRange reads sensors data in a time window.
// $ curl http://127.0.0.1:8000/api/sensor/{id}/values?from=2006-01-02T15:04:05Z07:00&to=2006-01-02T15:04:05Z07:00
func FindSensorDataBySensorIDAndTimeRange(ses gocqlx.Session) operations.FindSensorDataBySensorIDAndTimeRangeHandlerFunc {
	return func(params operations.FindSensorDataBySensorIDAndTimeRangeParams) middleware.Responder {
		var data []float32

		iter := ses.Session.
			Query("SELECT value FROM measurement WHERE sensor_id = ? AND ts >= ? and ts <= ?").
			Bind(params.ID.String(), time.Time(params.From), time.Time(params.To)).
			Iter()

		for {
			var t float32
			if !iter.Scan(&t) {
				break
			}
			data = append(data, t)
		}

		if err := iter.Close(); err != nil {
			log.Println("read sensors data query: ", err)
			return operations.NewFindOwnerByIDDefault(http.StatusInternalServerError)
		}

		return &operations.FindSensorDataBySensorIDAndTimeRangeOK{Payload: data}
	}
}
