// Code generated by go-swagger; DO NOT EDIT.

package operations

// This file was generated by the swagger tool.
// Editing this file might prove futile when you re-run the generate command

import (
	"net/http"

	"github.com/go-openapi/runtime/middleware"
)

// FindSensorsByPetIDHandlerFunc turns a function with the right signature into a find sensors by pet id handler
type FindSensorsByPetIDHandlerFunc func(FindSensorsByPetIDParams) middleware.Responder

// Handle executing the request and returning a response
func (fn FindSensorsByPetIDHandlerFunc) Handle(params FindSensorsByPetIDParams) middleware.Responder {
	return fn(params)
}

// FindSensorsByPetIDHandler interface for that can handle valid find sensors by pet id params
type FindSensorsByPetIDHandler interface {
	Handle(FindSensorsByPetIDParams) middleware.Responder
}

// NewFindSensorsByPetID creates a new http.Handler for the find sensors by pet id operation
func NewFindSensorsByPetID(ctx *middleware.Context, handler FindSensorsByPetIDHandler) *FindSensorsByPetID {
	return &FindSensorsByPetID{Context: ctx, Handler: handler}
}

/*FindSensorsByPetID swagger:route GET /pet/{id}/sensors findSensorsByPetId

Find the Pet sensors

*/
type FindSensorsByPetID struct {
	Context *middleware.Context
	Handler FindSensorsByPetIDHandler
}

func (o *FindSensorsByPetID) ServeHTTP(rw http.ResponseWriter, r *http.Request) {
	route, rCtx, _ := o.Context.RouteInfo(r)
	if rCtx != nil {
		r = rCtx
	}
	var Params = NewFindSensorsByPetIDParams()

	if err := o.Context.BindValidRequest(r, route, &Params); err != nil { // bind params
		o.Context.Respond(rw, r, route.Produces, route, err)
		return
	}

	res := o.Handler.Handle(Params) // actually handle the request

	o.Context.Respond(rw, r, route.Produces, route, res)

}
