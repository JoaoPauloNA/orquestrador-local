#!/usr/bin/python3
"""Isolated loopback fixture for Orquestrador Local lifecycle tests."""

import argparse
import json
import signal
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer


parser = argparse.ArgumentParser()
parser.add_argument("--port", type=int, required=True)
parser.add_argument("--activity-file", required=True)
parser.add_argument("--ready-delay", type=float, default=0)
args = parser.parse_args()
started_at = time.monotonic()


class Handler(BaseHTTPRequestHandler):
    def log_message(self, *_):
        return

    def send_json(self, status, payload):
        body = json.dumps(payload).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        if self.path == "/health":
            if time.monotonic() - started_at < args.ready_delay:
                self.send_json(503, {"service": "orquestrador-fixture"})
            else:
                self.send_json(200, {"service": "orquestrador-fixture", "ready": True})
            return
        if self.path == "/queue":
            try:
                mode = open(args.activity_file, encoding="utf-8").read().strip()
            except OSError:
                mode = "unknown"
            if mode == "idle":
                self.send_json(200, {"queue_running": [], "queue_pending": []})
            elif mode == "busy":
                self.send_json(200, {"queue_running": [["synthetic-job"]], "queue_pending": ["synthetic-pending"]})
            elif mode == "malformed":
                self.send_json(200, {"message": "counts intentionally unavailable"})
            else:
                self.send_json(503, {"message": "activity unavailable"})
            return
        if self.path == "/":
            self.send_json(200, {"service": "orquestrador-fixture"})
            return
        self.send_json(404, {"error": "not found"})


server = ThreadingHTTPServer(("127.0.0.1", args.port), Handler)


def stop(*_):
    threading.Thread(target=server.shutdown, daemon=True).start()


signal.signal(signal.SIGTERM, stop)
signal.signal(signal.SIGINT, stop)
server.serve_forever(poll_interval=0.05)
server.server_close()
