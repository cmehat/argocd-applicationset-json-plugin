FROM python:3.11-slim

WORKDIR /app
COPY plugin.py .

RUN pip install --no-cache-dir jsonpath-ng

EXPOSE 4355
CMD ["python3", "plugin.py"]
