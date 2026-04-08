# I added 7 Apr 2026
# Use a stable Python base image
FROM python:3.10-slim

# Set environment variables for container stability
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    DEBIAN_FRONTEND=noninteractive \
    PIP_DEFAULT_TIMEOUT=1000 \
    PIP_RETRIES=10

WORKDIR /app

# Install system dependencies required for the Git install
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    curl \
    git \
    && rm -rf /var/lib/apt/lists/*

# Upgrade pip to ensure the resolver works correctly
RUN pip install --no-cache-dir --upgrade pip

# HARDCODE THE MATRIX: Bypass requirements.txt entirely.
# This pulls GraphRAG v0.1.1 directly from GitHub and satisfies all LangChain constraints.
RUN pip install --no-cache-dir \
    git+https://github.com/microsoft/graphrag.git@v0.1.1 \
    gradio \
    fastapi \
    uvicorn \
    python-dotenv \
    pydantic \
    pandas \
    tiktoken \
    langchain==0.2.16 \
    langchain-community==0.2.16 \
    langchain-core==0.2.38 \
    aiohttp \
    pyyaml \
    requests \
    duckduckgo-search \
    ollama \
    plotly

# Copy the repository code into the container
COPY . .

# THE SURGICAL FIXES
# 1. Revert the import path in api.py to match the v0.1.1 Git tag
RUN sed -i 's/graphrag.query.llm.text_utils/graphrag.query.context_builder.entity_extraction/g' api.py

# 2. Force FastAPI and Gradio to bind to 0.0.0.0 instead of 127.0.0.1
# This allows Podman to route traffic from your host machine into the container
RUN sed -i 's/127.0.0.1/0.0.0.0/g' api.py
RUN sed -i 's/127.0.0.1/0.0.0.0/g' app.py
RUN sed -i 's/127.0.0.1/0.0.0.0/g' index_app.py

# Set up directories and non-root user for Podman
RUN mkdir -p ragtest/input ragtest/output ragtest/cache
RUN useradd -m appuser && chown -R appuser /app
USER appuser

# Expose the API port (8012 based on your logs) and UI ports (7860, 7861)
EXPOSE 8012 7860 7861

# Start the API
CMD ["python", "api.py"]