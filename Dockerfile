# ═══════════════════════════════════════════════════════════════════
# CP2 — Production-Ready Multi-Stage Dockerfile
# ═══════════════════════════════════════════════════════════════════

# Stage 1: Builder — Cài đặt dependencies
FROM python:3.11-slim AS builder

WORKDIR /build

COPY requirements.txt .
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt

# Stage 2: Runtime — Môi trường chạy tối giản, an toàn
FROM python:3.11-slim AS runtime

WORKDIR /app

# Copy các gói thư viện đã build từ stage builder
COPY --from=builder /install /usr/local

# Tạo non-root user để tăng cường bảo mật
RUN useradd --create-home --uid 10001 appuser

# Copy mã nguồn ứng dụng (đặt sau khi cài dependency để tận dụng layer cache)
COPY app ./app
COPY utils ./utils

# Chuyển quyền sở hữu thư mục app cho appuser và đổi sang user thường
RUN chown -R appuser:appuser /app
USER appuser

# Healthcheck gọi vào endpoint /health
HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8000/health').read()" || exit 1

EXPOSE 8000

# Chạy uvicorn với cổng linh hoạt đọc từ biến PORT (mặc định 8000)
CMD ["sh", "-c", "uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-8000}"]
