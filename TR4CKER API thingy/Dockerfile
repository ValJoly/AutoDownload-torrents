FROM python:3.11-slim

WORKDIR /app

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    TR4CKER_API_DUAL_STACK=true \
    TR4CKER_API_IPV6_HOST=:: \
    TR4CKER_API_IPV4_HOST=0.0.0.0 \
    TR4CKER_API_PORT=8384 \
    TR4CKER_API_RELOAD=false

COPY requirements.txt ./requirements.txt
RUN python -m pip install --upgrade pip && \
    python -m pip install --no-cache-dir -r requirements.txt

COPY . .

EXPOSE 8384

CMD ["python", "main.py"]
