# Use Python 3.11 slim image with ARM64 support
FROM python:3.11-slim

# Set working directory
WORKDIR /app

# Install system dependencies for Oracle client and other requirements
RUN apt-get update && apt-get install -y \
    curl \
    unzip \
    libaio1 \
    wget \
    gcc \
    g++ \
    && rm -rf /var/lib/apt/lists/*

# Install Oracle Instant Client for ARM64
# Note: Oracle provides ARM64 instant client for Linux
RUN mkdir -p /opt/oracle && \
    cd /opt/oracle && \
    wget https://download.oracle.com/otn_software/linux/instantclient/1923000/instantclient-basic-linux.arm64-19.23.0.0.0dbru.zip && \
    unzip instantclient-basic-linux.arm64-19.23.0.0.0dbru.zip && \
    rm instantclient-basic-linux.arm64-19.23.0.0.0dbru.zip && \
    echo /opt/oracle/instantclient_19_23 > /etc/ld.so.conf.d/oracle-instantclient.conf && \
    ldconfig

# Set Oracle environment variables
ENV LD_LIBRARY_PATH=/opt/oracle/instantclient_19_23
ENV PATH=/opt/oracle/instantclient_19_23:$PATH

# Copy requirements first for better caching
COPY requirements.txt .

# Install Python dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Copy web build directories first (less frequently changed)
COPY web-tenant/ ./web-tenant/
COPY web-admin/ ./web-admin/

# Copy Python API files (more frequently changed - each in separate layers for optimal caching)
COPY residents_db/ ./residents_db/
COPY storage/ ./storage/
COPY tenants/ ./tenants/
COPY modules/ ./modules/
COPY *.py .
COPY *.html .

# Create a non-root user for security
RUN groupadd -r appuser && useradd -r -g appuser appuser
RUN chown -R appuser:appuser /app
USER appuser

# Expose the port
EXPOSE 8000

# Health check
HEALTHCHECK --interval=30s --timeout=30s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8000/api/health || exit 1

# Run the application
CMD ["python", "-m", "uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]