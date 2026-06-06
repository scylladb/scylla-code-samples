FROM python:3.9-slim
        
WORKDIR /app
        
# Install system dependencies including cqlsh
RUN apt-get update && apt-get install -y \
    gcc \
    g++ \
    python3-pip \
    bash \
    && pip3 install cqlsh \
    && rm -rf /var/lib/apt/lists/*
        
# Copy requirements and install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
        
# Copy application code
COPY . .
        
# Make startup script executable
RUN chmod +x /app/app_startup.sh
        
# Create necessary directories
RUN mkdir -p feature_repo/data
        
EXPOSE 8501

CMD ["/bin/bash", "/app/app_startup.sh"]
