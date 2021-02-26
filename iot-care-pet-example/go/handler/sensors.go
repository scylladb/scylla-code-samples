package handler

import (
	"log"
	"net/http"

	"github.com/go-openapi/strfmt"
	"github.com/go-openapi/strfmt/conv"

	"github.com/go-openapi/runtime/middleware"
	"github.com/scylladb/scylla-code-samples/iot-care-pet-example/go/cmd/server/models"
	"github.com/scylladb/scylla-code-samples/iot-care-pet-example/go/cmd/server/restapi/operations"
	"github.com/scylladb/scylla-code-samples/iot-care-pet-example/go/db"
	"github.com/scylladb/scylla-code-samples/iot-care-pet-example/go/model"
	"github.com/scylladb/gocqlx/v2"
)

// FindSensorsByPetID finds pet sensors
// $ curl http://127.0.0.1:8000/api/pet/{id}/sensors
func FindSensorsByPetID(ses gocqlx.Session) operations.FindSensorsByPetIDHandlerFunc {
	return func(params operations.FindSensorsByPetIDParams) middleware.Responder {
		var sensors []model.Sensor

		if err := db.TableSensor.SelectQuery(ses).Bind(params.ID.String()).SelectRelease(&sensors); err != nil {
			log.Println("find sensors by pet id query: ", err)
			return operations.NewFindSensorsByPetIDDefault(http.StatusInternalServerError)
		}

		res := &operations.FindSensorsByPetIDOK{
			Payload: []*models.Sensor{},
		}

		for _, sen := range sensors {
			res.Payload = append(res.Payload, &models.Sensor{
				PetID:    conv.UUID(strfmt.UUID(sen.PetID.String())),
				SensorID: conv.UUID(strfmt.UUID(sen.SensorID.String())),
				Type:     sen.Type,
			})
		}

		return res
	}
}
