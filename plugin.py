#!/usr/bin/env python3
"""
ArgoCD ApplicationSet Plugin for fetching data from JSON endpoints.

This generic plugin fetches JSON from a URL and applies a JSONPath filter
to generate parameters for ApplicationSet.
"""

import json
import os
import sys
from http.server import BaseHTTPRequestHandler, HTTPServer
from urllib.request import urlopen
from jsonpath_ng.ext import parse

# Token from mounted secret file
try:
    with open("/var/run/argo/token") as f:
        plugin_token = f.read().strip()
except FileNotFoundError:
    plugin_token = "default-token"

# Configuration from environment variables
JSON_URL = os.getenv('JSON_URL', 'https://example.com/data.json')
JSON_PATH = os.getenv('JSON_PATH', '$[*]')  # JSONPath filter expression


class JsonPlugin(BaseHTTPRequestHandler):
    """HTTP handler for the JSON ApplicationSet plugin."""

    def args(self):
        """Parse JSON request body."""
        content_length = int(self.headers.get('Content-Length', 0))
        return json.loads(self.rfile.read(content_length))

    def reply(self, reply_data):
        """Send JSON response."""
        self.send_response(200)
        self.send_header('Content-Type', 'application/json')
        self.end_headers()
        self.wfile.write(json.dumps(reply_data).encode('UTF-8'))

    def forbidden(self):
        """Send 403 Forbidden."""
        self.send_response(403)
        self.end_headers()

    def unsupported(self):
        """Send 404 Not Found."""
        self.send_response(404)
        self.end_headers()

    def do_POST(self):
        """Handle POST requests."""
        # Authenticate
        auth_header = self.headers.get("Authorization", "")
        if auth_header != "Bearer " + plugin_token:
            self.forbidden()
            return

        # Handle getparams.execute endpoint
        if self.path == '/api/v1/getparams.execute':
            try:
                # Fetch JSON from URL
                with urlopen(JSON_URL, timeout=30) as response:
                    data = json.loads(response.read().decode('utf-8'))

                # Apply JSONPath filter
                jsonpath_expr = parse(JSON_PATH)
                matches = jsonpath_expr.find(data)
                
                # Convert matches to parameters
                parameters = []
                for match in matches:
                    # If the match value is a dict, use it directly
                    if isinstance(match.value, dict):
                        parameters.append(match.value)
                    # If it's a primitive value, wrap it in a dict with a generic key
                    else:
                        parameters.append({'value': match.value})

                self.reply({
                    'output': {
                        'parameters': parameters
                    }
                })
            except Exception as e:
                self.send_response(500)
                self.end_headers()
                self.wfile.write(json.dumps({
                    'error': f'Failed to fetch or process JSON: {str(e)}'
                }).encode('UTF-8'))
        else:
            self.unsupported()

    def log_message(self, format, *args):
        """Suppress default logging."""
        pass


if __name__ == '__main__':
    server = HTTPServer(('0.0.0.0', 4355), JsonPlugin)
    print("JSON plugin server listening on 0.0.0.0:4355", file=sys.stderr)
    server.serve_forever()
