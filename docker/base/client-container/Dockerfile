FROM python:3.9-slim

# Set work directory
WORKDIR /app

# Copy the client code
COPY client.py .

# Set default command
CMD ["sh", "-c", "sleep 30 && python client.py"]
