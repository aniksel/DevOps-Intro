package main

import (
	"fmt"
	"net/http"
	"time"

	spinhttp "github.com/spinframework/spin-go-sdk/v3/http"
)

// Moscow is UTC+3 all year round: Russia stopped changing the clocks in 2011.
// The zone is built by hand rather than with time.LoadLocation, because a WASM
// build carries no tzdata and the lookup would fail at runtime.
var moscow = time.FixedZone("MSK", 3*60*60)

func init() {
	spinhttp.Handle(func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodGet {
			w.Header().Set("Allow", "GET")
			w.WriteHeader(http.StatusMethodNotAllowed)
			return
		}

		now := time.Now().In(moscow)

		// The body is written with fmt and %q rather than encoding/json. There
		// are five fields, none of them need escaping beyond what %q does, and
		// a WASM build is better off without the reflection an encoder drags
		// in.
		w.Header().Set("Content-Type", "application/json")
		fmt.Fprintf(w,
			`{"zone":"Europe/Moscow","utc_offset":"+03:00","unix":%d,"iso":%q,"hour_minute":%q}`+"\n",
			now.Unix(),
			now.Format(time.RFC3339),
			now.Format("15:04"),
		)
	})
}

// main is required by the compiler but never runs. The host calls the handler
// registered in init.
func main() {}
