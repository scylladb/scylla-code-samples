// Code generated by go-swagger; DO NOT EDIT.

package operations

// This file was generated by the swagger tool.
// Editing this file might prove futile when you re-run the generate command

import (
	"net/http"

	"github.com/go-openapi/runtime/middleware"
)

// FindPetsByOwnerIDHandlerFunc turns a function with the right signature into a find pets by owner id handler
type FindPetsByOwnerIDHandlerFunc func(FindPetsByOwnerIDParams) middleware.Responder

// Handle executing the request and returning a response
func (fn FindPetsByOwnerIDHandlerFunc) Handle(params FindPetsByOwnerIDParams) middleware.Responder {
	return fn(params)
}

// FindPetsByOwnerIDHandler interface for that can handle valid find pets by owner id params
type FindPetsByOwnerIDHandler interface {
	Handle(FindPetsByOwnerIDParams) middleware.Responder
}

// NewFindPetsByOwnerID creates a new http.Handler for the find pets by owner id operation
func NewFindPetsByOwnerID(ctx *middleware.Context, handler FindPetsByOwnerIDHandler) *FindPetsByOwnerID {
	return &FindPetsByOwnerID{Context: ctx, Handler: handler}
}

/*FindPetsByOwnerID swagger:route GET /owner/{id}/pets findPetsByOwnerId

Find the Pets that the owner tracks

*/
type FindPetsByOwnerID struct {
	Context *middleware.Context
	Handler FindPetsByOwnerIDHandler
}

func (o *FindPetsByOwnerID) ServeHTTP(rw http.ResponseWriter, r *http.Request) {
	route, rCtx, _ := o.Context.RouteInfo(r)
	if rCtx != nil {
		r = rCtx
	}
	var Params = NewFindPetsByOwnerIDParams()

	if err := o.Context.BindValidRequest(r, route, &Params); err != nil { // bind params
		o.Context.Respond(rw, r, route.Produces, route, err)
		return
	}

	res := o.Handler.Handle(Params) // actually handle the request

	o.Context.Respond(rw, r, route.Produces, route, res)

}
