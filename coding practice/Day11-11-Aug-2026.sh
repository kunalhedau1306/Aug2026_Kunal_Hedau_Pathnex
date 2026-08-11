#!/bin/bash

export PS4='[ec2-user@ip-172-31-1-189 ~]$ '

set -x

echo "========================================================"
echo "Docker Practice - Day 11"
echo "Date: 11-Aug-2026"
echo "Environment: Amazon EC2 - Linux"
echo "========================================================"

echo
echo "=============================="
echo "Topic: Docker Version & Info"
echo "=============================="

docker --version
docker version
docker info

echo
echo "=============================="
echo "Topic: Docker Service"
echo "=============================="

sudo systemctl status docker --no-pager

echo
echo "=============================="
echo "Topic: Docker Images"
echo "=============================="

docker images
docker pull nginx
docker images

echo
echo "=============================="
echo "Topic: Run Docker Container"
echo "=============================="

docker run nginx

echo
echo "=============================="
echo "Topic: Run Container in Background"
echo "=============================="

docker run -d --name web1 nginx
docker ps

echo
echo "=============================="
echo "Topic: List All Containers"
echo "=============================="

docker ps
docker ps -a

echo
echo "=============================="
echo "Topic: Container Logs"
echo "=============================="

docker logs web1

echo
echo "=============================="
echo "Topic: Container Inspect"
echo "=============================="

docker inspect web1

echo
echo "=============================="
echo "Topic: Container Port"
echo "=============================="

docker port web1

echo
echo "=============================="
echo "Topic: Execute Command in Container"
echo "=============================="

docker exec web1 nginx -v
docker exec web1 ls -l /usr/share/nginx/html

echo
echo "=============================="
echo "Topic: Container Lifecycle"
echo "=============================="

docker stop web1
docker ps -a

docker start web1
docker ps

docker restart web1
docker ps

echo
echo "=============================="
echo "Topic: Docker Stats"
echo "=============================="

docker stats --no-stream web1

echo
echo "=============================="
echo "Topic: Docker Processes"
echo "=============================="

docker top web1

echo
echo "=============================="
echo "Topic: Port Mapping"
echo "=============================="

docker rm -f web1

docker run -d --name web2 -p 8080:80 nginx
docker ps
docker port web2

echo
echo "=============================="
echo "Topic: Test Web Server"
echo "=============================="

curl http://localhost:8080

echo
echo "=============================="
echo "Topic: Docker Network"
echo "=============================="

docker network ls
docker network create appnet
docker network inspect appnet

echo
echo "=============================="
echo "Topic: Containers on User Bridge"
echo "=============================="

docker run -d --name app1 --network appnet nginx
docker network inspect appnet

docker run --rm --network appnet busybox ping -c 3 app1

echo
echo "=============================="
echo "Topic: Connect Existing Container"
echo "=============================="

docker network connect appnet web2
docker network inspect appnet

docker network disconnect appnet web2
docker network inspect appnet

echo
echo "=============================="
echo "Topic: Docker Volume"
echo "=============================="

docker volume ls
docker volume create appdata
docker volume inspect appdata

echo
echo "=============================="
echo "Topic: Persistent Volume Data"
echo "=============================="

docker run --rm --name storage-test -v appdata:/data alpine \
  sh -c 'echo "Docker persistent data" > /data/test.txt && cat /data/test.txt'

docker run --rm -v appdata:/data alpine cat /data/test.txt

echo
echo "=============================="
echo "Topic: Bind Mount"
echo "=============================="

mkdir -p ~/docker-bind-test
echo "Hello from EC2 host" > ~/docker-bind-test/index.txt

docker run --rm -v ~/docker-bind-test:/data alpine cat /data/index.txt

echo
echo "=============================="
echo "Topic: tmpfs Mount"
echo "=============================="

docker run --rm --tmpfs /tmp alpine \
  sh -c 'echo "Temporary data" > /tmp/test.txt && cat /tmp/test.txt'

echo
echo "=============================="
echo "Topic: Dockerfile"
echo "=============================="

mkdir -p ~/docker-day11
cd ~/docker-day11

cat > Dockerfile <<'EOF'
FROM nginx:latest

COPY index.html /usr/share/nginx/html/index.html

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
EOF

cat > index.html <<'EOF'
<html>
<head>
<title>Docker Day 11</title>
</head>
<body>
<h1>Hello from Docker Day 11!</h1>
<p>This webpage is running inside a Docker container.</p>
</body>
</html>
EOF

cat Dockerfile
cat index.html

echo
echo "=============================="
echo "Topic: Docker Build"
echo "=============================="

docker build -t day11-web:v1 .
docker images

echo
echo "=============================="
echo "Topic: Run Custom Image"
echo "=============================="

docker run -d --name day11-web -p 8081:80 day11-web:v1
docker ps

echo
echo "=============================="
echo "Topic: Test Custom Docker Image"
echo "=============================="

curl http://localhost:8081

echo
echo "=============================="
echo "Topic: Image History"
echo "=============================="

docker history day11-web:v1

echo
echo "=============================="
echo "Topic: Image Tag"
echo "=============================="

docker tag day11-web:v1 day11-web:latest
docker images

echo
echo "=============================="
echo "Topic: Docker Rename"
echo "=============================="

docker rename day11-web day11-web-final
docker ps

echo
echo "=============================="
echo "Topic: Docker Copy"
echo "=============================="

echo "File copied from host" > host-file.txt

docker cp host-file.txt day11-web-final:/tmp/host-file.txt
docker exec day11-web-final cat /tmp/host-file.txt

docker cp day11-web-final:/etc/nginx/nginx.conf ./nginx.conf
ls -l nginx.conf

echo
echo "=============================="
echo "Topic: Environment Variable"
echo "=============================="

docker run --rm -e APP_ENV=practice alpine \
  sh -c 'echo "APP_ENV=$APP_ENV"'

echo
echo "=============================="
echo "Topic: Restart Policy"
echo "=============================="

docker run -d --name restart-test --restart unless-stopped nginx

docker inspect restart-test \
  --format '{{.HostConfig.RestartPolicy.Name}}'

echo
echo "=============================="
echo "Topic: Resource Usage"
echo "=============================="

docker stats --no-stream

echo
echo "=============================="
echo "Topic: Docker System Disk Usage"
echo "=============================="

docker system df

echo
echo "=============================="
echo "Topic: Docker Compose"
echo "=============================="

docker compose version

echo
echo "=============================="
echo "Topic: Cleanup Containers"
echo "=============================="

docker stop restart-test 2>/dev/null || true
docker rm restart-test 2>/dev/null || true
docker rm -f day11-web-final 2>/dev/null || true
docker rm -f app1 2>/dev/null || true
docker rm -f web2 2>/dev/null || true

echo
echo "=============================="
echo "Topic: Cleanup Network"
echo "=============================="

docker network rm appnet 2>/dev/null || true
docker network ls

echo
echo "=============================="
echo "Topic: Cleanup Volume"
echo "=============================="

docker volume rm appdata 2>/dev/null || true
docker volume ls

echo
echo "=============================="
echo "Topic: Review Previous Commands"
echo "=============================="

echo "docker version"
echo "docker info"
echo "docker pull"
echo "docker images"
echo "docker run"
echo "docker ps"
echo "docker ps -a"
echo "docker stop"
echo "docker start"
echo "docker restart"
echo "docker rm"
echo "docker logs"
echo "docker exec"
echo "docker inspect"
echo "docker build"
echo "docker network"
echo "docker volume"
echo "docker stats"
echo "docker top"
echo "docker cp"
echo "docker system df"

echo
echo "========================================================"
echo "Docker Practice - Day 11 Completed"
echo "========================================================"

cd ~

