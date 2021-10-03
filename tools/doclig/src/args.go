package main

import (
	"flag"
	"strings"
)

type Args struct {
	Action          *string
	Image           *string
	User            *string
	Password        *string
	SourcePaths     []string
	DestinationPath *string
}

func HandleArgs() *Args {
	var args Args

	args.Action = flag.String("action", "", "check-image, copy, prune, pull")
	args.Image = flag.String("image", "", "full image name (action: check-image, copy, pull)")
	args.User = flag.String("user", "", "username for docker registry (action: pull)")
	args.Password = flag.String("password", "", "password for docker registry (action: pull)")
	var sourceDirs string
	flag.StringVar(&sourceDirs, "srcPaths", "", "comma separated source directories (action: copy)")
	args.DestinationPath = flag.String("dst", "", "destination dir (action: copy)")
	flag.Parse()

	args.SourcePaths = strings.Split(sourceDirs, ",")

	return &args
}