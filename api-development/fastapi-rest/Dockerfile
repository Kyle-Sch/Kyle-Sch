###############################################################################
# Dockerfile — Package Registry API
# Multi-stage build: builder compiles C extensions, final image is minimal.
#
# Why gunicorn + UvicornWorker instead of uvicorn --workers:
#   gunicorn handles SIGTERM/SIGINT, worker recycling, and pre-fork properly.
#   uvicorn's --workers flag lacks robust process supervision in containers.
###############################################################################

# ---- Build stage -----------------------------------------------------------
FROM python:3.12-slim AS builder

WORKDIR /build

# gcc + libffi needed to compile uvloop, httptools (uvicorn[standard] extras)
RUN apt-get update \
    && apt-get install -y --no-install-recommends gcc libffi-dev \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --upgrade pip \
    && pip install --no-cache-dir --prefix=/install -r requirements.txt

# ---- Final stage -----------------------------------------------------------
FROM python:3.12-slim

# curl for Docker / K8s healthchecks; libffi-dev runtime for compiled extensions
RUN apt-get update \
    && apt-get install -y --no-install-recommends curl libffi8 \
    && rm -rf /var/lib/apt/lists/*

# Security: run as non-root
RUN groupadd -r appuser && useradd -r -g appuser appuser

WORKDIR /app

# Copy compiled packages from builder (includes uvloop, httptools .so files)
COPY --from=builder /install /usr/local

# Copy application source
COPY app/ ./app/

RUN chown -R appuser:appuser /app
USER appuser

EXPOSE 8080

ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    # Number of gunicorn workers — override at runtime if needed
    # Rule of thumb: (2 x CPU cores) + 1
    WEB_CONCURRENCY=2 \
    # Passed through to uvicorn workers
    UVICORN_LOG_LEVEL=info

HEALTHCHECK --interval=15s --timeout=5s --start-period=10s --retries=3 \
    CMD curl -f http://localhost:8080/healthz/live || exit 1

# gunicorn manages worker processes; UvicornWorker gives each worker
# the full async uvicorn event loop (uvloop + httptools when available).
CMD ["sh", "-c", \
     "gunicorn app.main:app \
      --worker-class uvicorn.workers.UvicornWorker \
      --workers ${WEB_CONCURRENCY} \
      --bind 0.0.0.0:8080 \
      --timeout 120 \
      --keep-alive 5 \
      --log-level ${UVICORN_LOG_LEVEL} \
      --access-logfile - \
      --error-logfile -"]
