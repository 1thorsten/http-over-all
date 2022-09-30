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
	ListenAddr      *string
	SourcePaths     []string
	DestinationPath *string
	OutFormat       *string
}

func HandleArgs() *Args {
	var args Args

	args.Action = flag.String("action", "", "check-image, copy, prune, pull, serve")
	args.Image = flag.String("image", "", "full image name (action: check-image, copy, pull)")
	args.User = flag.String("user", "", "username for docker registry (action: pull)")
	args.Password = flag.String("password", "", "password for docker registry (action: pull)")
	args.ListenAddr = flag.String("listen-addr", ":80", "TCP address for the server to listen on (action: serve)")
	var sourceDirs string
	flag.StringVar(&sourceDirs, "srcPaths", "", "comma separated source directories (action: copy)")
	args.DestinationPath = flag.String("dst", "", "destination dir (action: copy)")
	args.OutFormat = flag.String("out-fmt", "files", "out-format [files, tar] (action: copy)")
	flag.Parse()

	if len(sourceDirs) > 0 {
		if strings.Contains(sourceDirs, ",") {
			args.SourcePaths = strings.Split(sourceDirs, ",")
		} else if strings.Contains(sourceDirs, " ") {
			args.SourcePaths = strings.Split(sourceDirs, " ")
		} else {
			args.SourcePaths = []string{sourceDirs}
		}
	}
	return &args
}
