package action

import (
	"log"
	"net/http"
	"os/exec"
	"time"
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
	start := time.Now()

	output, err := runCommand()
	if err != nil {
		w.WriteHeader(http.StatusInternalServerError)
		_, _ = w.Write([]byte("500 - Could run /force-update -> " + err.Error()))
		return
	}

	w.Write(output)
	log.Printf("- %v - %v (%s)\n", r.RemoteAddr, r.RequestURI, time.Since(start))
}

func Serve(addr *string) {
	http.HandleFunc("/force-update", funcForceUpdate)
	http.HandleFunc("/force-update/", funcForceUpdate)

	fs := http.FileServer(http.Dir("/var/www/html"))
	http.Handle("/", fs)

	log.Printf("Listening on %s...", *addr)
	err := http.ListenAndServe(*addr, nil)
	if err != nil {
		log.Fatal(err)
	}
}
