package action

import (
	"context"
	"fmt"

	"github.com/moby/moby/client"
)

// PruneImages entfernt nicht mehr referenzierte, ungetaggte Images.
func PruneImages() {
	cli, err := client.New(client.FromEnv)
	if err != nil {
		panic(err)
	}
	defer cli.Close()

	fmt.Println("Prune dangling images")
	filters := client.Filters{}.Add("dangling", "true")
	result, err := cli.ImagePrune(context.Background(), client.ImagePruneOptions{
		Filters: filters,
	})
	if err != nil {
		panic(err)
	}
	fmt.Printf("Space Reclaimed: %d bytes\n", result.Report.SpaceReclaimed)
}
