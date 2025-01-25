#!/bin/bash

echo "Stopping all running containers..."
docker stop $(docker ps -q)

echo "Stopping all containers again to ensure no running instances..."
docker ps -q | xargs -r docker stop

echo "Removing all containers..."
docker ps -aq | xargs -r docker rm -f

echo "Removing all images..."
docker images -aq | xargs -r docker rmi -f

echo "Removing all unused volumes..."
docker volume ls -q | xargs -r docker volume rm

echo "Removing all custom networks..."
docker network ls | grep -v "bridge\|host\|none" | awk '{if(NR>1) print $2}' | xargs -r docker network rm

echo "Performing Docker system prune to clean unused data..."
docker system prune -af --volumes

echo "Cleanup completed. Space and memory freed!"

