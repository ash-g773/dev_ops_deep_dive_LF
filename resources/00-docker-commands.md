# Docker Commands

This document is to serve as a guide to common Docker commands to assist the running / creation and sharing of Docker Images.

## Running Docker Images

- `docker pull lfacademy/hello-world-nodejs:0.0.1.RELEASE`
If the image is not local, `docker pull` will pull the image to the local machine running the command

- `docker run -d -p 5000:5000 lfacademy/hello-world-nodejs:0.0.1.RELEASE`
Loads a container based of the specific image and tag value
  - `-d` to run in detatched mode
  - `-p 5000:5000` to link the containers export port (right) to run on the host machines port (left)

## Images

### Viewing Images

- `docker images`
Returns the images on the local machine

### Removing Images

- `docker image rm <image-id>`
Removes an image based on its id

### Other Image Commands

- `docker image history <imagine-id>`
Shows the layers behind image construction

- `docker image insepct <image-id>`
Shows detail

## Containers

### Viewing Containers

- `docker container ls`
Shows the running containers on the local machine

- `docker container ls -a`
Shows both running and stopped containers on the local machine

### Interacting with containers

- `docker logs -f <container-id>`
Outputs to logs from a specific container
  - `-f` to follow the logs continuously 

- `docker container stop <container-id>`
Stops a running container

- `docker container kill <container-id>`
Kills a running container 

- `docker container inspect <container-id>`
Shos details about the container

## System & Stats

- `docker system` 
Run this command with options:
  - `df`: shows docker disk usage
  - `events`: get real time events from the server
  - `info`: display system-wide information
  - `prune`: removed unused data

- `docker stats`
Displays the container information, the CPU and memory usage

- `docker run -d -m 512m --cpu-quota=50000 -p 5000:5000 lfacademy/hello-world-nodejs:0.0.1.RELEASE`
Runs an instance of the image limited its resources to 512mb of memory of 50% of CPU usage

## Building Docker Images

- `docker build -t <your-username>/hello-world-nodejs:0.0.1.RELEASE .`
Builds an image based on a **Dockerfile** in the same location as the command is being executed with a specific name and tag.

### Building Docker Images for specific Platform
You can find your host architecture by running: `uname -m` via the CLI or Git Bash
- `docker build --platform linux/amd64 -t <your-username>/hello-world-nodejs:0.0.1.RELEASE .`
- `docker build --platform linux/arm64 -t <your-username>/hello-world-nodejs:0.0.1.RELEASE .`

## Dockerfile

```Dockerfile
# Base image
FROM node:8.16.1-alpine
# Working directory of the image
WORKDIR /app
# Copy code from current location into '/app/
COPY . /app
# Run this command // Install dependencies in package.json
RUN npm install
# Expose container port 5000
EXPOSE 5000
# Execute command 'node index.js` once the container's been created
CMD ["node", "index.js"]
```
