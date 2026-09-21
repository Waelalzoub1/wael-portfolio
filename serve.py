#!/usr/bin/env python3
"""Tiny static server for the Wael Alzoubi portfolio.

Origin behind the shared Cloudflare Tunnel (pi-tunnel). Cloudflare's edge caches
whatever Cache-Control we send, so once warm almost nothing reaches this process.
Serves this directory only; directory listings are disabled.
"""
import http.server
import os
import socketserver

PORT = int(os.environ.get("PORT", "8092"))
DIRECTORY = os.path.dirname(os.path.abspath(__file__))


class Handler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=DIRECTORY, **kwargs)

    def end_headers(self):
        # HTML: revalidate so edits go live fast. Static assets: cache hard.
        path = self.path.split("?", 1)[0]
        if path.endswith((".png", ".jpg", ".svg", ".ico", ".woff2", ".css", ".js")):
            self.send_header("Cache-Control", "public, max-age=604800, immutable")
        else:
            self.send_header("Cache-Control", "public, max-age=0, must-revalidate")
        self.send_header("X-Content-Type-Options", "nosniff")
        super().end_headers()

    def list_directory(self, path):  # no directory listings
        self.send_error(404, "Not Found")
        return None

    def log_message(self, fmt, *args):  # quiet; pm2 captures stdout if needed
        pass


class Server(socketserver.ThreadingTCPServer):
    allow_reuse_address = True
    daemon_threads = True


if __name__ == "__main__":
    os.chdir(DIRECTORY)
    with Server(("127.0.0.1", PORT), Handler) as httpd:
        print(f"portfolio serving {DIRECTORY} on http://127.0.0.1:{PORT}")
        httpd.serve_forever()
