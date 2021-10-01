package main

import (
	"doclig/src/action"
	_ "embed"
	"fmt"
	"strings"
)

//go:embed VERSION.txt
var version string

func main() {
	version = strings.TrimSuffix(version, "\n")
	fmt.Printf("doclig version: %s\n", version)

	args := HandleArgs()

	if *args.Action == "pull" {
		action.PullImage(args.Image, args.User, args.Password)
	} else if *args.Action == "copy" {
		action.CopyContents(args.Image, args.SourcePaths, args.DestinationPath)
	} else if *args.Action == "check-image" {
		action.CheckImage(args.Image)
	} else if *args.Action == "prune" {
		action.PruneImages()
	}
}