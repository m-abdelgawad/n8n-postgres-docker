# ────────────────────────────────────────────────
# n8n custom image (optional)
# Extends the official image so you can add
# any extra OS packages or npm nodes later.
# ────────────────────────────────────────────────
FROM n8nio/n8n:latest

# Switch to root to install extra packages
USER root

# Example: install ffmpeg (uncomment if needed)
# RUN apt-get update && apt-get install -y ffmpeg && \
#     apt-get clean && rm -rf /var/lib/apt/lists/*

# Revert to default non-root user for security
USER node

