package main

import (
	"net/http"
	"net/http/httptest"
	"testing"
)

// The headers have to be on every response, so the targets cover a JSON
// handler, the plain text metrics handler, and a path with no route at all,
// which never reaches a handler.
//
// The test goes through Routes(), so removing the middleware from the router
// makes it fail.
func TestSecurityHeaders_OnEveryRoute(t *testing.T) {
	want := map[string]string{
		"X-Content-Type-Options":       "nosniff",
		"Cache-Control":                "no-store",
		"Content-Security-Policy":      "default-src 'none'; frame-ancestors 'none'; base-uri 'none'",
		"X-Frame-Options":              "DENY",
		"Referrer-Policy":              "no-referrer",
		"Cross-Origin-Resource-Policy": "same-origin",
		"Cross-Origin-Opener-Policy":   "same-origin",
		"Cross-Origin-Embedder-Policy": "require-corp",
	}

	srv := newTestServer(t)
	for _, target := range []string{"/health", "/metrics", "/notes", "/no-such-path"} {
		t.Run(target, func(t *testing.T) {
			req := httptest.NewRequest(http.MethodGet, target, nil)
			rec := httptest.NewRecorder()
			srv.Routes().ServeHTTP(rec, req)
			for name, value := range want {
				if got := rec.Header().Get(name); got != value {
					t.Errorf("%s: got %q, want %q", name, got, value)
				}
			}
		})
	}
}
