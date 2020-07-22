// Code generated by go-swagger; DO NOT EDIT.

package operations

// This file was generated by the swagger tool.
// Editing this file might prove futile when you re-run the swagger generate command

import (
	"context"
	"net/http"
	"time"

	"github.com/go-openapi/errors"
	"github.com/go-openapi/runtime"
	cr "github.com/go-openapi/runtime/client"
	"github.com/go-openapi/strfmt"
)

// NewFindPetsByOwnerIDParams creates a new FindPetsByOwnerIDParams object
// with the default values initialized.
func NewFindPetsByOwnerIDParams() *FindPetsByOwnerIDParams {
	var ()
	return &FindPetsByOwnerIDParams{

		timeout: cr.DefaultTimeout,
	}
}

// NewFindPetsByOwnerIDParamsWithTimeout creates a new FindPetsByOwnerIDParams object
// with the default values initialized, and the ability to set a timeout on a request
func NewFindPetsByOwnerIDParamsWithTimeout(timeout time.Duration) *FindPetsByOwnerIDParams {
	var ()
	return &FindPetsByOwnerIDParams{

		timeout: timeout,
	}
}

// NewFindPetsByOwnerIDParamsWithContext creates a new FindPetsByOwnerIDParams object
// with the default values initialized, and the ability to set a context for a request
func NewFindPetsByOwnerIDParamsWithContext(ctx context.Context) *FindPetsByOwnerIDParams {
	var ()
	return &FindPetsByOwnerIDParams{

		Context: ctx,
	}
}

// NewFindPetsByOwnerIDParamsWithHTTPClient creates a new FindPetsByOwnerIDParams object
// with the default values initialized, and the ability to set a custom HTTPClient for a request
func NewFindPetsByOwnerIDParamsWithHTTPClient(client *http.Client) *FindPetsByOwnerIDParams {
	var ()
	return &FindPetsByOwnerIDParams{
		HTTPClient: client,
	}
}

/*FindPetsByOwnerIDParams contains all the parameters to send to the API endpoint
for the find pets by owner id operation typically these are written to a http.Request
*/
type FindPetsByOwnerIDParams struct {

	/*ID
	  ID of an owner pets to fetch

	*/
	ID strfmt.UUID

	timeout    time.Duration
	Context    context.Context
	HTTPClient *http.Client
}

// WithTimeout adds the timeout to the find pets by owner id params
func (o *FindPetsByOwnerIDParams) WithTimeout(timeout time.Duration) *FindPetsByOwnerIDParams {
	o.SetTimeout(timeout)
	return o
}

// SetTimeout adds the timeout to the find pets by owner id params
func (o *FindPetsByOwnerIDParams) SetTimeout(timeout time.Duration) {
	o.timeout = timeout
}

// WithContext adds the context to the find pets by owner id params
func (o *FindPetsByOwnerIDParams) WithContext(ctx context.Context) *FindPetsByOwnerIDParams {
	o.SetContext(ctx)
	return o
}

// SetContext adds the context to the find pets by owner id params
func (o *FindPetsByOwnerIDParams) SetContext(ctx context.Context) {
	o.Context = ctx
}

// WithHTTPClient adds the HTTPClient to the find pets by owner id params
func (o *FindPetsByOwnerIDParams) WithHTTPClient(client *http.Client) *FindPetsByOwnerIDParams {
	o.SetHTTPClient(client)
	return o
}

// SetHTTPClient adds the HTTPClient to the find pets by owner id params
func (o *FindPetsByOwnerIDParams) SetHTTPClient(client *http.Client) {
	o.HTTPClient = client
}

// WithID adds the id to the find pets by owner id params
func (o *FindPetsByOwnerIDParams) WithID(id strfmt.UUID) *FindPetsByOwnerIDParams {
	o.SetID(id)
	return o
}

// SetID adds the id to the find pets by owner id params
func (o *FindPetsByOwnerIDParams) SetID(id strfmt.UUID) {
	o.ID = id
}

// WriteToRequest writes these params to a swagger request
func (o *FindPetsByOwnerIDParams) WriteToRequest(r runtime.ClientRequest, reg strfmt.Registry) error {

	if err := r.SetTimeout(o.timeout); err != nil {
		return err
	}
	var res []error

	// path param id
	if err := r.SetPathParam("id", o.ID.String()); err != nil {
		return err
	}

	if len(res) > 0 {
		return errors.CompositeValidationError(res...)
	}
	return nil
}
