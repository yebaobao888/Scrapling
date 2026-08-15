FROM python:3.12-slim-trixie

LABEL io.modelcontextprotocol.server.name="io.github.D4Vinci/Scrapling"
COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /bin/

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1

WORKDIR /app

# Copy dependency file first for better layer caching
COPY pyproject.toml ./

# Install dependencies only
RUN --mount=type=cache,id=scrapling-uv-cache,target=/root/.cache/uv \
    uv sync --no-install-project --all-extras --compile-bytecode

# Copy source code
COPY . .

# Install browsers and project in one optimized layer
RUN --mount=type=cache,id=scrapling-uv-cache,target=/root/.cache/uv \
    --mount=type=cache,id=scrapling-apt-cache,target=/var/cache/apt \
    --mount=type=cache,id=scrapling-apt-lists,target=/var/lib/apt \
    apt-get update && \
    uv run playwright install-deps chromium && \
    uv run playwright install chromium && \
    uv sync --all-extras --compile-bytecode && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Expose port for MCP server HTTP transport
EXPOSE 8000

# Railway injects PORT at runtime. Start the authenticated streamable HTTP MCP
# server directly so no Railway start-command override is required.
ENTRYPOINT ["/bin/sh", "-c"]
CMD ["exec uv run scrapling mcp --http --host 0.0.0.0 --port ${PORT:-8000}"]
