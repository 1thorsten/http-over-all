package action

import (
	"context"
	"fmt"

	"github.com/moby/moby/client"
)

// CheckImage check whether the specified image exists or not
func CheckImage(image *string) {
	cli, err := client.New(client.FromEnv)
	if err != nil {
		panic(err)
	}
	defer cli.Close()
	ctx := context.Background()
	inspect, err := cli.ImageInspect(ctx, *image)
	if err != nil {
		panic(err)
	}

	fmt.Printf("Check-Image: '%s' exists.\nId: %s\nDigest: %s\n", inspect.RepoTags[0], inspect.ID, inspect.RepoDigests[0])
}
