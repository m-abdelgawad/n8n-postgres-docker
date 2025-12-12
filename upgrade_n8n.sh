# 1. Pull the latest n8n image
docker compose pull

# 2. Stop and remove the old containers
docker compose down

# 3. Start the new containers in detached mode
docker compose up -d

# 4. Follow the logs to ensure it starts correctly
docker compose logs -f n8n
