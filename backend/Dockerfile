FROM python:3.12-slim AS base
ENV PYTHONUNBUFFERED=1 UV_COMPILE_BYTECODE=1
# Native libraries the media pipeline needs at runtime: libmagic (python-magic), libvips (pyvips), ffmpeg (voice/audio).
RUN apt-get update \
    && (apt-get install -y --no-install-recommends libmagic1t64 libvips42t64 ffmpeg \
        || apt-get install -y --no-install-recommends libmagic1 libvips42 ffmpeg) \
    && rm -rf /var/lib/apt/lists/*
RUN pip install --no-cache-dir uv==0.11.32
WORKDIR /app
COPY pyproject.toml uv.lock ./
RUN uv sync --frozen --no-dev --no-install-project
COPY . .
RUN useradd -r app && chown -R app /app
USER app
ENV DJANGO_SETTINGS_MODULE=config.settings.prod PATH="/app/.venv/bin:$PATH"
# api: gunicorn config.asgi:application -k uvicorn.workers.UvicornWorker
# ws:  daphne config.asgi:application   worker: celery -A config worker -Q default,media,billing,notify
CMD ["gunicorn", "config.asgi:application", "-k", "uvicorn.workers.UvicornWorker", "-b", "0.0.0.0:8000"]
