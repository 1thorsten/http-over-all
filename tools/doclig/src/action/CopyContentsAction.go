package action

import (
	"archive/tar"
	"fmt"
	"github.com/docker/distribution/context"
	"github.com/docker/docker/api/types"
	"github.com/docker/docker/api/types/container"
	"github.com/docker/docker/client"
	"io"
	"math/rand"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"time"
)

var letters = []rune("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ")

func randSeq(n int) string {
	b := make([]rune, n)
	for i := range b {
		b[i] = letters[rand.Intn(len(letters))]
	}
	return string(b)
}

func timeTrack(start time.Time, name string, min time.Duration) {
	elapsed := time.Since(start)
	if elapsed > min {
		fmt.Printf("%s took %s\n", name, elapsed)
	}
}

// untar takes a destination path and a reader; a tar reader loops over the tarfile
// creating the file structure at 'dst' along the way, and writing any files
func untar(dst string, r io.Reader) error {
	tr := tar.NewReader(r)

	for {
		header, err := tr.Next()

		switch {

		// if no more files are found return
		case err == io.EOF:
			return nil

		// return any other error
		case err != nil:
			return err

		// if the header is nil, just skip it (not sure how this happens)
		case header == nil:
			continue
		}

		// the target location where the dir/file should be created
		target := filepath.Join(dst, header.Name)

		// the following switch could also be done using fi.Mode(), not sure if there
		// a benefit of using one vs. the other.
		// fi := header.FileInfo()

		// check the file type
		switch header.Typeflag {

		// if its a dir and it doesn't exist create it
		case tar.TypeDir:
			if _, err := os.Stat(target); err != nil {
				if err := os.MkdirAll(target, 0755); err != nil {
					return err
				}
			}

		// if it's a file create it
		case tar.TypeReg:
			start := time.Now()
			f, err := os.OpenFile(target, os.O_CREATE|os.O_RDWR, os.FileMode(header.Mode))
			if err != nil {
				return err
			}

			// copy over contents
			if _, err := io.Copy(f, tr); err != nil {
				return err
			}

			// manually close here after each file operation; defering would cause each file close
			// to wait until all operations have completed.
			f.Close()
			timeTrack(start, "file: "+target+" ("+strconv.FormatInt(header.Size/1024, 10)+"kb)", 100*time.Millisecond)
		}
	}
}

// CopyContents copy the specified content (paths) from image to a specified destination
func CopyContents(image *string, srcPaths []string, dst *string) {
	ctx := context.Background()
	cli, err := client.NewClientWithOpts(client.FromEnv, client.WithAPIVersionNegotiation())
	if err != nil {
		panic(err)
	}

	rand.Seed(time.Now().UnixNano())
	resp, err := cli.ContainerCreate(ctx, &container.Config{
		Image: *image,
	}, nil, nil, nil, fmt.Sprintf("copy-contents-%s", randSeq(10)))
	if err != nil {
		panic(err)
	}

	if err := cli.ContainerStart(ctx, resp.ID, types.ContainerStartOptions{}); err != nil {
		panic(err)
	}

	fmt.Printf("CopyContents: %s -> %s\n", srcPaths, *dst)
	for _, srcPath := range srcPaths {
		trimmedPath := strings.TrimSpace(srcPath)
		reader, _, err := cli.CopyFromContainer(ctx, resp.ID, trimmedPath)
		if err != nil {
			fmt.Println(err.Error())
			break
		}

		start := time.Now()
		untar(*dst, reader)
		timeTrack(start, fmt.Sprintf("Untar %s", trimmedPath), time.Microsecond)
	}

	defer timeTrack(time.Now(), "Stop container", time.Millisecond)
	timeout := 2 * time.Second
	if err := cli.ContainerStop(ctx, resp.ID, &timeout); err == nil {
		err := cli.ContainerRemove(ctx, resp.ID, types.ContainerRemoveOptions{})
		if err != nil {
			return
		}
	}
}
