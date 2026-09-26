package action

import (
	"archive/tar"
	"context"
	"errors"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"time"
	"uuid"

	"github.com/moby/moby/api/types/container"
	"github.com/moby/moby/client"
)

func timeTrack(start time.Time, name string, min time.Duration) {
	elapsed := time.Since(start)
	if elapsed > min {
		fmt.Printf("%s took %s\n", name, elapsed)
	}
}

// untar extrahiert einen tar-Stream sicher in dst.
// Es nutzt os.Root (Go 1.24+), das Pfad-Traversal auch über
// Symlinks hinweg verhindert - eine echte Härtung gegenüber
// filepath.Join + IsLocal allein.
func untar(dst string, r io.Reader) error {
	root, err := os.OpenRoot(dst)
	if err != nil {
		return err
	}
	defer root.Close()

	tr := tar.NewReader(r)

	for {
		header, err := tr.Next()
		switch {
		case err == io.EOF:
			return nil
		case err != nil:
			return err
		case header == nil:
			continue
		}

		name := filepath.Clean(header.Name)
		if !filepath.IsLocal(name) {
			return fmt.Errorf("unsafe path in tar archive: %q", header.Name)
		}

		switch header.Typeflag {
		case tar.TypeDir:
			if err := root.MkdirAll(name, 0755); err != nil {
				return err
			}
			if err := root.Chtimes(name, header.AccessTime, header.ModTime); err != nil {
				fmt.Printf("Warn: change access and modification times failed: %s\n", name)
			}

		case tar.TypeReg:
			// tar.TypeRegA ist deprecated und wird vom Reader
			// bereits automatisch zu TypeReg/TypeDir normalisiert.
			start := time.Now()

			if dir := filepath.Dir(name); dir != "." {
				if err := root.MkdirAll(dir, 0755); err != nil {
					return err
				}
			}

			f, err := root.OpenFile(
				name,
				os.O_CREATE|os.O_WRONLY|os.O_TRUNC,
				os.FileMode(header.Mode),
			)
			if err != nil {
				return err
			}

			_, copyErr := io.Copy(f, tr)
			closeErr := f.Close()
			if err := errors.Join(copyErr, closeErr); err != nil {
				return err
			}

			if err := root.Chtimes(name, header.AccessTime, header.ModTime); err != nil {
				fmt.Printf("Warn: change access and modification times failed: %s\n", name)
			}

			timeTrack(
				start,
				"file: "+name+" ("+strconv.FormatInt(header.Size/1024, 10)+"kb)",
				100*time.Millisecond,
			)
		}
	}
}

func copyTar(dst string, path string, r io.Reader) (string, error) {
	outFileName := strings.TrimPrefix(strings.ReplaceAll(path, "/", "_"), "_")
	if outFileName == "" {
		return "", fmt.Errorf("empty source path")
	}

	target := filepath.Join(dst, outFileName+".tar")
	fmt.Printf("Out-File: %s\n", target)

	f, err := os.Create(target)
	if err != nil {
		return "", err
	}

	_, copyErr := io.Copy(f, r)
	closeErr := f.Close()
	if err := errors.Join(copyErr, closeErr); err != nil {
		return "", err
	}

	return target, nil
}

// CopyContents kopiert die angegebenen Pfade aus einem Image zum Ziel.
func CopyContents(image *string, srcPaths []string, dst *string, outFormat *string) {
	cli, err := client.New(client.FromEnv)
	if err != nil {
		panic(err)
	}
	defer cli.Close()

	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Minute)
	defer cancel()

	resp, err := cli.ContainerCreate(ctx, client.ContainerCreateOptions{
		Image: *image,
		Name:  "copy-contents-" + uuid.NewV7().String(),
		Config: &container.Config{
			Labels: map[string]string{
				"docon.v1": `{"control":"false","console":"false","show":"false"}`,
			},
		},
	})
	if err != nil {
		panic(err)
	}

	defer func() {
		start := time.Now()
		if _, err := cli.ContainerRemove(
			ctx,
			resp.ID,
			client.ContainerRemoveOptions{Force: true},
		); err != nil {
			fmt.Printf("Warn: could not remove container %s: %v\n", resp.ID, err)
		}
		timeTrack(start, "Remove container", time.Millisecond)
	}()

	if _, err := cli.ContainerStart(
		ctx,
		resp.ID,
		client.ContainerStartOptions{},
	); err != nil {
		panic(err)
	}

	if _, err := cli.ContainerPause(
		ctx,
		resp.ID,
		client.ContainerPauseOptions{},
	); err != nil {
		fmt.Printf("Warn: could not pause container for image: %s: %v\n", *image, err)
	}

	fmt.Printf("CopyContents: %v -> %s\n", srcPaths, *dst)

	for _, srcPath := range srcPaths {
		trimmedPath := strings.TrimSpace(srcPath)

		result, err := cli.CopyFromContainer(
			ctx,
			resp.ID,
			client.CopyFromContainerOptions{SourcePath: trimmedPath},
		)
		if err != nil {
			fmt.Println(err)
			break
		}

		start := time.Now()

		if *outFormat == "tar" {
			target, copyErr := copyTar(*dst, trimmedPath, result.Content)
			closeErr := result.Content.Close()

			if err := errors.Join(copyErr, closeErr); err != nil {
				fmt.Println(err)
				break
			}

			timeTrack(
				start,
				fmt.Sprintf("Copy [%s] to %s", trimmedPath, target),
				time.Microsecond,
			)
			continue
		}

		extractErr := untar(*dst, result.Content)
		closeErr := result.Content.Close()

		if err := errors.Join(extractErr, closeErr); err != nil {
			fmt.Println(err)
			break
		}

		timeTrack(
			start,
			fmt.Sprintf("Untar [%s]", trimmedPath),
			time.Microsecond,
		)
	}
}
