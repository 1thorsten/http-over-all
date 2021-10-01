package action

import (
	"fmt"
	"github.com/docker/distribution/context"
	"github.com/docker/docker/client"
)

// CheckImage check whether the specified image exists or not
func CheckImage(image *string) {
	ctx := context.Background()
	cli, err := client.NewClientWithOpts(client.FromEnv, client.WithAPIVersionNegotiation())
	if err != nil {
		panic(err)
	}

	inspect, _, err := cli.ImageInspectWithRaw(ctx, *image)
	if err != nil {
		panic(err)
	}
	fmt.Printf("Check-Image: '%s' exists.\nId: %s\nDigest: %s\n", inspect.RepoTags[0], inspect.ID, inspect.RepoDigests[0])
}
