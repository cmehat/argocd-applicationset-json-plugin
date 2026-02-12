FROM python:3.11-slim

# Create directories
WORKDIR /app
RUN mkdir -p /var/run/argo

# Install dependencies
RUN pip install --no-cache-dir jsonpath-ng

# Copy plugin (JSONPath-only version)
COPY plugin.py .
RUN chmod +x plugin.py

# For dual jq/JSONPath support, uncomment the following:
# RUN apt-get update && apt-get install -y jq && rm -rf /var/lib/apt/lists/*
# COPY plugin_dual.py plugin.py

EXPOSE 4355
CMD ["python3", "plugin.py"]
