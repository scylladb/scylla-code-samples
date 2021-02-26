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

// FindPetsByOwnerID finds pets by owner id
// $ http://127.0.0.1:8000/api/owner/{id}/pets
func FindPetsByOwnerID(ses gocqlx.Session) operations.FindPetsByOwnerIDHandlerFunc {
	return func(params operations.FindPetsByOwnerIDParams) middleware.Responder {
		var pets []model.Pet

		if err := db.TablePet.SelectQuery(ses).Bind(params.ID.String()).SelectRelease(&pets); err != nil {
			log.Println("find pets by owner id query: ", err)
			return operations.NewFindOwnerByIDDefault(http.StatusInternalServerError)
		}

		res := &operations.FindPetsByOwnerIDOK{
			Payload: []*models.Pet{},
		}

		for _, pet := range pets {
			res.Payload = append(res.Payload, &models.Pet{
				OwnerID: conv.UUID(strfmt.UUID(pet.OwnerID.String())),
				PetID:   conv.UUID(strfmt.UUID(pet.PetID.String())),
				Age:     int64(pet.Age),
				Weight:  float64(pet.Weight),
				Address: pet.Address,
				Name:    pet.Name,
			})
		}

		return res
	}
}
