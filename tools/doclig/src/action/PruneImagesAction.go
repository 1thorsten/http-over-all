package action

import (
	"fmt"
	"github.com/docker/distribution/context"
	"github.com/docker/docker/api/types/filters"
	"github.com/docker/docker/client"
)

// PruneImages prune dangling images (image which are not referenced anymore)
func PruneImages() {
	cli, err := client.NewClientWithOpts(client.FromEnv, client.WithAPIVersionNegotiation())
	if err != nil {
		panic(err)
	}

	fmt.Println("Prune dangling images")
	pruneFilters := filters.NewArgs()
	pruneFilters.Add("dangling", "true")
	ctx := context.Background()
	pruneReport, _ := cli.ImagesPrune(ctx, pruneFilters)
	fmt.Printf("Space Reclaimed: %d bytes", pruneReport.SpaceReclaimed)
}
