#!/usr/bin/env python3
"""
ArgoCD ApplicationSet Plugin with dual jq/JSONPath support.

This plugin supports both jq (powerful transformations) and JSONPath (efficient queries).
It auto-detects which to use or can be explicitly configured.
"""

import json
import os
import sys
import subprocess
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
JSON_FILTER = os.getenv('JSON_FILTER', '')  # jq filter expression
JSON_PATH = os.getenv('JSON_PATH', '')  # JSONPath expression
JSON_FILTER_TYPE = os.getenv('JSON_FILTER_TYPE', 'auto')  # auto, jq, or jsonpath

# JSONPath-specific options
JSON_PATH_KEY_FIELD = os.getenv('JSON_PATH_KEY_FIELD', 'name')
JSON_PATH_KEYS_ONLY = os.getenv('JSON_PATH_KEYS_ONLY', 'false').lower() == 'true'
JSON_PATH_EXCLUDE_IF_EXISTS = os.getenv('JSON_PATH_EXCLUDE_IF_EXISTS', '')

# Determine filter mode
def get_filter_mode():
    """Determine which filter type to use."""
    if JSON_FILTER_TYPE in ['jq', 'jsonpath']:
        return JSON_FILTER_TYPE

    # Auto-detect based on which variable is set
    if JSON_FILTER and not JSON_PATH:
        return 'jq'
    elif JSON_PATH and not JSON_FILTER:
        return 'jsonpath'
    elif JSON_FILTER:
        # If both set, prefer jq
        return 'jq'
    else:
        # Default to JSONPath
        return 'jsonpath'

FILTER_MODE = get_filter_mode()
FILTER_EXPRESSION = JSON_FILTER if FILTER_MODE == 'jq' else (JSON_PATH or '$[*]')


def apply_jq_filter(data_str):
    """Apply jq filter to JSON string."""
    try:
        result = subprocess.run(
            ['jq', JSON_FILTER],
            input=data_str.encode('utf-8'),
            capture_output=True,
            timeout=10,
            check=True
        )
        parameters = json.loads(result.stdout.decode('utf-8'))

        # Ensure parameters is a list
        if not isinstance(parameters, list):
            parameters = [parameters]

        return parameters
    except subprocess.CalledProcessError as e:
        raise Exception(f'jq filter error: {e.stderr.decode("utf-8")}')
    except FileNotFoundError:
        raise Exception('jq is not installed. Please install jq or use JSONPath mode.')


def apply_jsonpath_filter(data):
    """Apply JSONPath filter with optional key extraction."""
    jsonpath_expr = parse(FILTER_EXPRESSION)
    matches = jsonpath_expr.find(data)

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
            fields = match.path.fields
            if isinstance(fields, (list, tuple)):
                key_name = fields[0]
            else:
                key_name = fields
        elif hasattr(match.path, 'right') and hasattr(match.path.right, 'fields'):
            fields = match.path.right.fields
            if isinstance(fields, (list, tuple)):
                key_name = fields[0]
            else:
                key_name = fields

        # Build result based on options
        if JSON_PATH_KEYS_ONLY and key_name:
            parameters.append({JSON_PATH_KEY_FIELD: key_name})
        elif key_name and isinstance(value, dict):
            result = {JSON_PATH_KEY_FIELD: key_name}
            result.update(value)
            parameters.append(result)
        else:
            parameters.append(value)

    # If no matches, return original data
    if not parameters:
        parameters = [data]

    return parameters


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

                # Apply filter based on mode
                if FILTER_MODE == 'jq':
                    parameters = apply_jq_filter(json_data)
                else:
                    data = json.loads(json_data)
                    parameters = apply_jsonpath_filter(data)

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
    """Validate that JSON_URL is reachable and filter is valid."""
    try:
        print(f"Validating JSON source at {JSON_URL}", file=sys.stderr)
        with urlopen(JSON_URL, timeout=30) as response:
            json_data = response.read().decode('utf-8')

        print(f"JSON source validated successfully", file=sys.stderr)
        print(f"  - URL: {JSON_URL}", file=sys.stderr)
        print(f"  - Filter mode: {FILTER_MODE}", file=sys.stderr)
        print(f"  - Filter expression: {FILTER_EXPRESSION}", file=sys.stderr)

        # Test the filter
        if FILTER_MODE == 'jq':
            parameters = apply_jq_filter(json_data)
            print(f"  - jq results: {len(parameters)} items", file=sys.stderr)
        else:
            data = json.loads(json_data)
            jsonpath_expr = parse(FILTER_EXPRESSION)
            matches = jsonpath_expr.find(data)

            # Count after filtering
            filtered_count = 0
            for match in matches:
                if JSON_PATH_EXCLUDE_IF_EXISTS and isinstance(match.value, dict):
                    if JSON_PATH_EXCLUDE_IF_EXISTS not in match.value:
                        filtered_count += 1
                else:
                    filtered_count += 1

            print(f"  - JSONPath matches: {len(matches)}", file=sys.stderr)
            if JSON_PATH_EXCLUDE_IF_EXISTS:
                print(f"  - After filtering: {filtered_count}", file=sys.stderr)
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
    print(f"Filter mode: {FILTER_MODE}", file=sys.stderr)
    server.serve_forever()
