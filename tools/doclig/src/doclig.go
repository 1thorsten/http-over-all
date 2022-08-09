package main

import (
	"doclig/src/action"
	_ "embed"
	"fmt"
	"runtime"
	"strings"
)

//go:embed VERSION.txt
var version string

func main() {
	version = strings.TrimSuffix(version, "\n")
	fmt.Printf("doclig version: %s (%s)\n", version, runtime.Version())

	args := HandleArgs()

	if *args.Action == "pull" {
		action.PullImage(args.Image, args.User, args.Password)
	} else if *args.Action == "copy" {
		action.CopyContents(args.Image, args.SourcePaths, args.DestinationPath)
	} else if *args.Action == "check-image" {
		action.CheckImage(args.Image)
	} else if *args.Action == "prune" {
		action.PruneImages()
	} else if *args.Action == "serve" {
		action.Serve(args.ListenAddr)
	}
}
