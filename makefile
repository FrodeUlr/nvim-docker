PROJECT_NAME := nvim-docker

.PHONY: all build create clean connect

all: create connect

build: clean
	@echo "Building Docker image..."
	@docker build $(if $(nocache),--no-cache) -t $(PROJECT_NAME) .

create: build
	@echo "Creating Docker container..."
	@docker create --name $(PROJECT_NAME) -e DISPLAY=$$DISPLAY -v /tmp/.X11-unix:/tmp/.X11-unix -v nvim-home:/home/ubuntu -it $(PROJECT_NAME)

connect:
	@docker start $(PROJECT_NAME)
	@docker exec -it $(PROJECT_NAME) zsh

clean:
	@echo "Cleaning up..."
	@docker stop $(PROJECT_NAME) || true
	@docker rm $(PROJECT_NAME) || true
	@docker rmi $(PROJECT_NAME) || true
	@docker volume rm nvim-home || true
	@echo "Cleanup complete."
