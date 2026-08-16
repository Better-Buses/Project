# Dockerfile to build a custom image for the telegraf deployment. The image is already published on DockerHub, so no need to re-build it unless updates in the image.

FROM telegraf:1.30
USER root
RUN apt-get update && apt-get install -y python3 && \
    apt-get clean && rm -rf /var/lib/apt/lists/*
USER telegraf
