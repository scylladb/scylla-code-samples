package handler

import (
	"log"
	"net/http"

	"github.com/go-openapi/runtime/middleware"
	"github.com/go-openapi/strfmt"
	"github.com/go-openapi/strfmt/conv"
	"github.com/gocql/gocql"

	"github.com/scylladb/scylla-code-samples/iot-care-pet-example/go/cmd/server/models"
	"github.com/scylladb/scylla-code-samples/iot-care-pet-example/go/cmd/server/restapi/operations"
	"github.com/scylladb/scylla-code-samples/iot-care-pet-example/go/db"
	"github.com/scylladb/scylla-code-samples/iot-care-pet-example/go/model"
	"github.com/scylladb/gocqlx/v2"
)

// FindOwnerByID finds an owner by id
// $ curl http://127.0.0.1:8000/api/owner/{id}
func FindOwnerByID(ses gocqlx.Session) operations.FindOwnerByIDHandlerFunc {
	return func(params operations.FindOwnerByIDParams) middleware.Responder {
		var owner model.Owner

		if err := db.TableOwner.GetQuery(ses).Bind(params.ID.String()).GetRelease(&owner); err == gocql.ErrNotFound {
			return operations.NewFindOwnerByIDDefault(http.StatusNotFound)
		} else if err != nil {
			log.Println("find owner by id query: ", err)
			return operations.NewFindOwnerByIDDefault(http.StatusInternalServerError)
		}

		return &operations.FindOwnerByIDOK{Payload: &models.Owner{
			Address: owner.Address,
			Name:    owner.Name,
			OwnerID: conv.UUID(strfmt.UUID(owner.OwnerID.String())),
		}}
	}
}
