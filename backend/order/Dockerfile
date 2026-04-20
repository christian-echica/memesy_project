# Build context: backend/
# docker build -f order/Dockerfile .
FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PYTHONPATH=/app

WORKDIR /app

COPY order/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY shared/ ./shared/
COPY order/ .

EXPOSE 5000
HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
  CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:5000/health')"

CMD ["gunicorn", "--bind", "0.0.0.0:5000", "--workers", "2", "--timeout", "60", "app:app"]
