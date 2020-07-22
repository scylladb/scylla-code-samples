package model

type Pet struct {
	OwnerID UUID
	PetID   UUID
	Age     int
	Weight  float32
	Address string
	Name    string
}
