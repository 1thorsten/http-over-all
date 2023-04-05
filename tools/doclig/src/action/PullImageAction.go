package action

import (
	"encoding/base64"
	"encoding/json"
	"fmt"
	"github.com/docker/distribution/context"
	"github.com/docker/docker/api/types"
	"github.com/docker/docker/client"
	"io"
	"strings"
)

type PulledImage struct {
	Image    *string
	Digest   *string
	NewImage bool
}

// PullImage pull the specified image from the registry
func PullImage(image *string, username *string, password *string) *PulledImage {
	cli, err := client.NewClientWithOpts(client.FromEnv, client.WithAPIVersionNegotiation())
	if err != nil {
		panic(err)
	}

	pullOptions := types.ImagePullOptions{}

	auth := ""
	// registry authentication
	if *username != "" {
		authConfig := types.AuthConfig{
			Username: *username,
			Password: *password,
		}
		encodedJSON, err := json.Marshal(authConfig)
		if err != nil {
			panic(err)
		}
		authStr := base64.URLEncoding.EncodeToString(encodedJSON)
		pullOptions.RegistryAuth = authStr
		auth = fmt.Sprintf("(User:%s)", *username)
	}

	ctx := context.Background()
	events, err := cli.ImagePull(ctx, *image, types.ImagePullOptions{})

	if err != nil {
		panic(err)
	}

	fmt.Printf("PulledImage%s: %s\n", auth, *image)
	defer func(events io.ReadCloser) {
		_ = events.Close()
	}(events)

	d := json.NewDecoder(events)
	type Event struct {
		Status         string `json:"status"`
		Error          string `json:"error"`
		Progress       string `json:"progress"`
		ProgressDetail struct {
			Current int `json:"current"`
			Total   int `json:"total"`
		} `json:"progressDetail"`
	}

	var resp PulledImage
	var event *Event
	for {
		if err := d.Decode(&event); err != nil {
			if err == io.EOF {
				break
			}
			panic(err)
		}

		// fmt.Printf("EVENT: %+v\n", event)
		if event != nil {
			if strings.HasPrefix(event.Status, "Digest: ") {
				digest := strings.Split(event.Status, "Digest: ")[1]
				resp.Digest = &digest
				fmt.Println(event.Status)
			}
		}
	}

	// Latest event for new image
	// EVENT: {Status:Status: Downloaded newer image for busybox:latest Error: Progress:[==================================================>]  699.2kB/699.2kB ProgressDetail:{Current:699243 Total:699243}}
	// Latest event for up-to-date image
	// EVENT: {Status:Status: Image is up to date for busybox:latest Error: Progress: ProgressDetail:{Current:0 Total:0}}
	if event != nil {
		if strings.Contains(event.Status, fmt.Sprintf("Downloaded newer image for %s", *image)) {
			fmt.Println(event.Status)
			resp.NewImage = true
			resp.Image = image
		} else if strings.Contains(event.Status, fmt.Sprintf("Image is up to date for %s", *image)) {
			fmt.Println(event.Status)
			resp.NewImage = false
			resp.Image = image
		}
	}

	inspect, _, err := cli.ImageInspectWithRaw(ctx, *image)
	if err == nil {
		fmt.Printf("Created: %s\n", inspect.Created)
		fmt.Printf("Docker-Version: %s\n", inspect.DockerVersion)
	}

	return &resp
}
