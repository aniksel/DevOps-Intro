package main

import "net/http"

// securityHeaders sets the response headers the ZAP baseline scan asks for.
//
// It wraps the whole router instead of touching each handler, so every route
// is covered and a new handler cannot forget to add them. The values suit a
// JSON API that serves no HTML, no scripts and no cookies.
func securityHeaders(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		h := w.Header()

		// A browser must not guess a content type other than the one sent.
		// Guessing is how a JSON body ends up being run as a script.
		h.Set("X-Content-Type-Options", "nosniff")

		// Notes are user data. Nothing here may sit in a shared cache.
		h.Set("Cache-Control", "no-store")

		// The API returns no HTML. Nothing may be loaded from it, it may not
		// be framed, and it has no base URL to rewrite.
		h.Set("Content-Security-Policy", "default-src 'none'; frame-ancestors 'none'; base-uri 'none'")
		h.Set("X-Frame-Options", "DENY")
		h.Set("Referrer-Policy", "no-referrer")

		// Site isolation: keep the response out of another origin's process.
		h.Set("Cross-Origin-Resource-Policy", "same-origin")
		h.Set("Cross-Origin-Opener-Policy", "same-origin")
		h.Set("Cross-Origin-Embedder-Policy", "require-corp")

		next.ServeHTTP(w, r)
	})
}
