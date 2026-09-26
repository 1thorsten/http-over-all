package action

import (
	"encoding/base64"
	"encoding/json"
	"fmt"
	"io"
	"strings"

	"context"

	"github.com/moby/moby/api/types/registry"
	"github.com/moby/moby/client"
)

type PulledImage struct {
	Image    *string
	Digest   *string
	NewImage bool
}

// PullImage pull the specified image from the registry
func PullImage(imageValue *string, username *string, password *string) *PulledImage {
	cli, err := client.New(client.FromEnv)
	if err != nil {
		panic(err)
	}
	defer cli.Close()

	pullOptions := client.ImagePullOptions{}

	auth := ""
	// registry authentication
	if *username != "" {

		authConfig := registry.AuthConfig{
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
	events, err := cli.ImagePull(ctx, *imageValue, pullOptions)

	if err != nil {
		panic(err)
	}

	fmt.Printf("PulledImage%s: %s\n", auth, *imageValue)
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
				resp.Digest = new(strings.Split(event.Status, "Digest: ")[1])
				fmt.Println(event.Status)
			}
		}
	}

	// Latest event for new imageValue
	// EVENT: {Status:Status: Downloaded newer imageValue for busybox:latest Error: Progress:[==================================================>]  699.2kB/699.2kB ProgressDetail:{Current:699243 Total:699243}}
	// Latest event for up-to-date imageValue
	// EVENT: {Status:Status: Image is up-to-date for busybox:latest Error: Progress: ProgressDetail:{Current:0 Total:0}}
	if event != nil {
		if strings.Contains(event.Status, fmt.Sprintf("Downloaded newer imageValue for %s", *imageValue)) {
			fmt.Println(event.Status)
			resp.NewImage = true
			resp.Image = imageValue
		} else if strings.Contains(event.Status, fmt.Sprintf("Image is up to date for %s", *imageValue)) {
			fmt.Println(event.Status)
			resp.NewImage = false
			resp.Image = imageValue
		}
	}

	inspect, err := cli.ImageInspect(ctx, *imageValue)
	if err == nil {
		fmt.Printf("Created: %s\n", inspect.Created)
	}

	return &resp
}
