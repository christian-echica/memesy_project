# Build context: backend/
# docker build -f listing/Dockerfile .
FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PYTHONPATH=/app

WORKDIR /app

# Install deps before copying source (layer cache)
COPY listing/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Shared library used by all services
COPY shared/ ./shared/

# DB migration + seed scripts (used by one-off ECS run-task)
COPY db/ ./db/

# Service source
COPY listing/ .

EXPOSE 5000
HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
  CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:5000/health')"

CMD ["gunicorn", "--bind", "0.0.0.0:5000", "--workers", "2", "--timeout", "60", "app:app"]
