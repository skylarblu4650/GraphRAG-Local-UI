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

# Step 1: Install the UI framework and stable background dependencies
# ADDED FIX: Pin jinja2 and starlette to stop the templating crash
RUN pip install --no-cache-dir \
    gradio==4.44.1 \
    huggingface_hub==0.23.4 \
    pydantic==2.7.4 \
    jinja2==3.1.4 \
    starlette==0.38.2 \
    fastapi \
    uvicorn \
    python-dotenv \
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

# Step 2: Install GraphRAG separately to bypass the aiofiles conflict
RUN pip install --no-cache-dir \
    git+https://github.com/microsoft/graphrag.git@v0.1.1

# Copy the repository code into the container
COPY . .

# THE SURGICAL FIXES
# 1. Revert the import path in api.py to match the v0.1.1 Git tag
RUN sed -i 's/graphrag.query.llm.text_utils/graphrag.query.context_builder.entity_extraction/g' api.py

# 2. Force FastAPI and Gradio to bind to 0.0.0.0
RUN sed -i 's/127.0.0.1/0.0.0.0/g' api.py
RUN sed -i 's/127.0.0.1/0.0.0.0/g' app.py
RUN sed -i 's/127.0.0.1/0.0.0.0/g' index_app.py

# 3. Fix hardcoded Ollama hostnames
RUN sed -i 's/localhost:11434/ollama:11434/g' app.py
RUN sed -i 's/localhost:11434/ollama:11434/g' index_app.py
RUN sed -i 's/localhost:11434/ollama:11434/g' api.py

# 4. FIX: Inject an explicit boolean check at the top of the function to stop Pydantic crashes
RUN sed -i 's/def _json_schema_to_python_type(schema, defs):/def _json_schema_to_python_type(schema, defs):\n    if isinstance(schema, bool):\n        return "Any"/g' /usr/local/lib/python3.10/site-packages/gradio_client/utils.py

# Set up directories and non-root user for Podman
RUN mkdir -p ragtest/input ragtest/output ragtest/cache
RUN useradd -m appuser && chown -R appuser /app
USER appuser

# Expose the API port (8012) and UI ports (7860, 7861)
EXPOSE 8012 7860 7861

# Start the API
CMD ["python", "api.py"]