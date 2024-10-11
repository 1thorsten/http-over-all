package action

import (
	"fmt"
	"log"
	"net/http"
	"os"
	"os/exec"
	"strconv"
	"time"
)

var (
	forceUpdateLock int64 = 16
	lastUpdate      time.Time
	updateIsRunning = false
)

func runCommand() ([]byte, error) {
	out, err := exec.Command("/bin/sh", "-c", "sudo /scripts/force-update.sh").CombinedOutput()

	if err != nil {
		log.Printf("cmd.Run() failed with %s\n", err)
		return nil, err
	}

	return out, nil
}

func funcForceUpdate(w http.ResponseWriter, r *http.Request) {
	// Monitor connection cancellation using the request context
	ctx := r.Context()

	// If an update is already running, wait for it to finish
	if updateIsRunning {
		log.Printf("- %v - %v - An update is already running, waiting for completion...\n", r.RemoteAddr, r.RequestURI)

		// Wait until updateIsRunning is set to false
		for updateIsRunning {
			select {
			case <-ctx.Done(): // If the client cancels the request while waiting
				log.Printf("- %v - %v - Client canceled the connection\n", r.RemoteAddr, r.RequestURI)
				http.Error(w, "Client canceled the connection", http.StatusRequestTimeout)
				return
			default:
				// Sleep for 200 milliseconds to avoid busy-waiting
				time.Sleep(200 * time.Millisecond)
			}
		}

		// Once the update finishes, respond with success
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write([]byte("force-update completed"))
		return
	}
	updateIsRunning = true
	start := time.Now()
	if !lastUpdate.IsZero() {
		diffInSeconds := int64(start.Sub(lastUpdate).Seconds())
		// 16 - 11 = 4
		if forceUpdateLock-diffInSeconds >= 0 {
			w.WriteHeader(http.StatusOK)
			msg := fmt.Sprintf("avoid executing force-update.sh (previous call was %d second(s) ago; lock_sec: %d)",
				diffInSeconds, forceUpdateLock)
			log.Println(msg)
			_, _ = w.Write([]byte(msg))
			updateIsRunning = false
			return
		}
	}

	// Start the process asynchronously and monitor for client cancellation
	outputChan := make(chan []byte)
	errChan := make(chan error)

	go func() {
		// Execute the command and send the result to channels
		output, err := runCommand()
		lastUpdate = time.Now()
		if err != nil {
			errChan <- err
		} else {
			outputChan <- output
		}
	}()

	select {
	case <-ctx.Done(): // If the client cancels the connection
		updateIsRunning = false
		log.Printf("- %v - %v (%s) Client canceled the connection after.\n", r.RemoteAddr, r.RequestURI, time.Since(start))
		http.Error(w, "Client canceled the connection", http.StatusRequestTimeout)
	case output := <-outputChan: // If the command completes successfully
		updateIsRunning = false
		if _, err := w.Write(output); err != nil {
			log.Println("Error writing response: ", err)
			return
		}
		log.Printf("- %v - %v (%s)\n", r.RemoteAddr, r.RequestURI, time.Since(start))
	case err := <-errChan: // If there is an error running the command
		updateIsRunning = false
		w.WriteHeader(http.StatusInternalServerError)
		_, _ = w.Write([]byte("500 - Could not run /force-update -> " + err.Error()))
	}
}

func Serve(addr *string) {
	envVar, ok := os.LookupEnv("FORCE_UPDATE_LOCK")
	if ok {
		parsedNum, err := strconv.ParseInt(envVar, 10, 64)
		if err != nil {
			log.Printf("could not convert FORCE_UPDATE_LOCK (val: %s), so take default -> %d", envVar, forceUpdateLock)
		} else {
			forceUpdateLock = parsedNum
		}
	}
	http.HandleFunc("/force-update", funcForceUpdate)
	http.HandleFunc("/force-update/", funcForceUpdate)

	fs := http.FileServer(http.Dir("/var/www/html"))
	http.Handle("/", fs)

	log.Printf("doclig is listening on %s for http-requests", *addr)
	err := http.ListenAndServe(*addr, nil)
	if err != nil {
		log.Fatal(err)
	}
}
