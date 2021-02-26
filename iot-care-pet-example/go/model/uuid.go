package model

import (
	"math/rand"

	"github.com/gocql/gocql"
)

type UUID = gocql.UUID

func RandomUUID() UUID {
	id, err := gocql.RandomUUID()
	if err != nil {
		panic(err)
	}

	return id
}

func RandomString(n int) string {
	var s = make([]byte, n)
	for i := 0; i < n; i++ {
		s[i] = 'a' + byte(rand.Intn('z'-'a'))
	}
	return string(s)
}
