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
from jsonpath_ng import parse

# Token from mounted secret file
try:
    with open("/var/run/argo/token") as f:
        plugin_token = f.read().strip()
except FileNotFoundError:
    plugin_token = "default-token"

# Configuration from environment variables
JSON_URL = os.getenv('JSON_URL', 'https://example.com/data.json')
JSON_PATH = os.getenv('JSON_PATH', '$[*]')  # JSONPath expression
JSON_PATH_KEY_FIELD = os.getenv('JSON_PATH_KEY_FIELD', 'name')  # Field name for extracted keys
JSON_PATH_KEYS_ONLY = os.getenv('JSON_PATH_KEYS_ONLY', 'false').lower() == 'true'  # Return only {name: key}
JSON_PATH_EXCLUDE_IF_EXISTS = os.getenv('JSON_PATH_EXCLUDE_IF_EXISTS', '')  # Exclude if field exists


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
                    json_data = response.read().decode('utf-8')

                # Parse JSON
                data = json.loads(json_data)

                # Apply JSONPath filter
                jsonpath_expr = parse(JSON_PATH)
                matches = jsonpath_expr.find(data)

                # Process matches with optional key extraction and filtering
                parameters = []
                for match in matches:
                    value = match.value

                    # Skip if filtering is enabled and field exists
                    if JSON_PATH_EXCLUDE_IF_EXISTS and isinstance(value, dict):
                        if JSON_PATH_EXCLUDE_IF_EXISTS in value:
                            continue

                    # Extract key name from path if available
                    key_name = None
                    if hasattr(match.path, 'fields') and match.path.fields:
                        # For Fields path like $.foo or $.*
                        fields = match.path.fields
                        if isinstance(fields, (list, tuple)):
                            key_name = fields[0]
                        else:
                            key_name = fields
                    elif hasattr(match.path, 'right') and hasattr(match.path.right, 'fields'):
                        # For chained paths like $[*].foo
                        fields = match.path.right.fields
                        if isinstance(fields, (list, tuple)):
                            key_name = fields[0]
                        else:
                            key_name = fields

                    # Build result based on options
                    if JSON_PATH_KEYS_ONLY and key_name:
                        # Return only {name: "keyname"}
                        parameters.append({JSON_PATH_KEY_FIELD: key_name})
                    elif key_name and isinstance(value, dict):
                        # Add key to existing object
                        result = {JSON_PATH_KEY_FIELD: key_name}
                        result.update(value)
                        parameters.append(result)
                    else:
                        # Return value as-is
                        parameters.append(value)

                # If no matches, return original data
                if not parameters:
                    parameters = [data]

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


def validate_json_source():
    """Validate that JSON_URL is reachable and contains valid JSON."""
    try:
        print(f"Validating JSON source at {JSON_URL}", file=sys.stderr)
        with urlopen(JSON_URL, timeout=30) as response:
            json_data = response.read().decode('utf-8')

        # Try to parse JSON
        data = json.loads(json_data)

        # Try to apply JSONPath filter
        jsonpath_expr = parse(JSON_PATH)
        matches = jsonpath_expr.find(data)

        # Count matches after filtering
        filtered_count = 0
        for match in matches:
            if JSON_PATH_EXCLUDE_IF_EXISTS and isinstance(match.value, dict):
                if JSON_PATH_EXCLUDE_IF_EXISTS not in match.value:
                    filtered_count += 1
            else:
                filtered_count += 1

        print(f"JSON source validated successfully", file=sys.stderr)
        print(f"  - URL: {JSON_URL}", file=sys.stderr)
        print(f"  - JSONPath: {JSON_PATH}", file=sys.stderr)
        print(f"  - Matches found: {len(matches)}", file=sys.stderr)
        if JSON_PATH_EXCLUDE_IF_EXISTS:
            print(f"  - After filtering (exclude if '{JSON_PATH_EXCLUDE_IF_EXISTS}' exists): {filtered_count}", file=sys.stderr)
        if JSON_PATH_KEYS_ONLY:
            print(f"  - Keys only mode: enabled (field: {JSON_PATH_KEY_FIELD})", file=sys.stderr)

    except Exception as e:
        print(f"ERROR: Failed to validate JSON source: {str(e)}", file=sys.stderr)
        sys.exit(1)


if __name__ == '__main__':
    # Fail-fast validation at startup
    validate_json_source()

    server = HTTPServer(('0.0.0.0', 4355), JsonPlugin)
    print("JSON plugin server listening on 0.0.0.0:4355", file=sys.stderr)
    server.serve_forever()
