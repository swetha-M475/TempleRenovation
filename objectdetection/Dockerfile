# ============================================================
# Temple Heritage Monitor — Production Docker Image
# Compatible with Render (root context + backend folder)
# ============================================================

# ── Stage 1: Builder ────────────────────────────────────────
FROM python:3.11-slim AS builder

WORKDIR /build

# Install build dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    cmake \
    libglib2.0-0 \
    libgl1 \
    libsm6 \
    libxext6 \
    libxrender1 \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Copy requirements from backend
COPY backend/requirements.txt .

# Create virtual environment
RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# Install dependencies
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt && \
    pip install --no-cache-dir gunicorn


# ── Stage 2: Runtime ────────────────────────────────────────
FROM python:3.11-slim AS runtime

LABEL maintainer="Temple Heritage Monitor"
LABEL description="Flask REST API with YOLOv8"

# Runtime dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    libglib2.0-0 \
    libgl1 \
    libsm6 \
    libxext6 \
    libxrender1 \
    libgomp1 \
    curl \
    && apt-get clean && rm -rf /var/lib/apt/lists/*
# Copy virtual environment
COPY --from=builder /opt/venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# Python settings
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    OMP_NUM_THREADS=4

# Create app user
RUN groupadd -r appuser && useradd -r -g appuser -d /app -s /sbin/nologin appuser

WORKDIR /app

# ✅ COPY FROM BACKEND FOLDER (IMPORTANT FIX)
COPY backend/requirements.txt .
COPY backend/export_model.py .
COPY backend/database.py .
COPY backend/engine/ ./engine/
COPY backend/models/ ./models/
COPY backend/app.py .

# Create data directory
RUN mkdir -p /app/data && chown -R appuser:appuser /app

# Switch user
USER appuser

# Initialize DB
RUN python -c "import database; database.init_db()"

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:5000/api/health || exit 1

# Expose port
EXPOSE 5000

# Run server
CMD ["gunicorn", \
     "--bind", "0.0.0.0:5000", \
     "--workers", "2", \
     "--threads", "4", \
     "--timeout", "120", \
     "--preload", \
     "app:app"]