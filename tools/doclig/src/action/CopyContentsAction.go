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
		if strings.Contains(target, "..") {
			fmt.Printf("!ignore %s\n", target)
			continue
		}
		// the following switch could also be done using fi.Mode(), not sure if there
		// is a benefit of using one vs. the other.
		// fi := header.FileInfo()

		// check the file type
		switch header.Typeflag {

		// if it's a directory, and it doesn't exist create it
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
			if err := f.Close(); err != nil {
				return err
			}
			timeTrack(start, "file: "+target+" ("+strconv.FormatInt(header.Size/1024, 10)+"kb)", 100*time.Millisecond)
		}
	}
}

// copyTar save the tar from the io.Reader as file
func copyTar(dst string, path string, r io.Reader) (*string, error) {
	outFileName := strings.ReplaceAll(path, "/", "_")
	if outFileName[0] == '_' {
		outFileName = strings.Replace(outFileName, "_", "", 1)
	}
	target := filepath.Join(dst, outFileName+".tar")
	fmt.Printf("Out-File: %s\n", target)
	f, err := os.Create(target)
	if err != nil {
		fmt.Printf("ignore %s -> %s\n", target, err)
		return nil, err
	} else {
		if _, err := io.Copy(f, r); err != nil {
			fmt.Printf("error writing %s -> %s\n", target, err)
		}
		if err := f.Close(); err != nil {
			return nil, err
		}
	}
	return &target, nil
}

// CopyContents copy the specified content (paths) from image to a specified destination
func CopyContents(image *string, srcPaths []string, dst *string, outFormat *string) {
	cli, err := client.NewClientWithOpts(client.FromEnv, client.WithAPIVersionNegotiation())
	if err != nil {
		panic(err)
	}

	ctx := context.Background()
	resp, err := cli.ContainerCreate(ctx, &container.Config{
		Image: *image,
	}, nil, nil, nil, fmt.Sprintf("copy-contents-%s", randSeq(10)))
	if err != nil {
		panic(err)
	}

	if err := cli.ContainerStart(ctx, resp.ID, types.ContainerStartOptions{}); err != nil {
		panic(err)
	}

	if err := cli.ContainerPause(ctx, resp.ID); err != nil {
		fmt.Printf("Warn: could not pause container for image: %s\n", *image)
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
		if *outFormat != "tar" {
			err := untar(*dst, reader)
			if err != nil {
				fmt.Println(err.Error())
				break
			}
			timeTrack(start, fmt.Sprintf("Untar [%s]", trimmedPath), time.Microsecond)
		} else {
			if target, _ := copyTar(*dst, trimmedPath, reader); target != nil {
				timeTrack(start, fmt.Sprintf("Copy [%s] to %s", trimmedPath, *target), time.Microsecond)
			} else {
				fmt.Printf("Error copying [%s]\n", trimmedPath)
			}
		}
	}

	defer timeTrack(time.Now(), "Stop container", time.Millisecond)
	timeoutInSeconds := 2
	if err := cli.ContainerStop(ctx, resp.ID, container.StopOptions{Timeout: &timeoutInSeconds}); err == nil {
		err := cli.ContainerRemove(ctx, resp.ID, types.ContainerRemoveOptions{})
		if err != nil {
			return
		}
	}
}
