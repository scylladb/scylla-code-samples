package main

import (
	"log"
	"syscall"
)

func SetNoFile(val uint64) {
	var rLimit syscall.Rlimit
	rLimit.Max = val
	rLimit.Cur = val

	if err := syscall.Setrlimit(syscall.RLIMIT_NOFILE, &rLimit); err != nil {
		log.Fatalln("setrlimit[rlimit_nofile]:", err)
	}
}
