IMAGE_NAME := plano-railway
CONTAINER_NAME := plano-railway
PLANO_VERSION ?= 0.4.8

.PHONY: build run test logs shell stop clean

build:
	docker build -t $(IMAGE_NAME) --build-arg PLANO_VERSION=$(PLANO_VERSION) .

run: build
	@if [ -f .env ]; then \
		docker run -d --name $(CONTAINER_NAME) \
			--env-file .env \
			-e PORT=12000 \
			-p 12000:12000 \
			-p 10000:10000 \
			$(IMAGE_NAME); \
	else \
		echo "No .env file found. Copy .env.example to .env and add your API keys."; \
		exit 1; \
	fi
	@echo ""
	@echo "Plano is starting..."
	@echo "  LLM Gateway: http://localhost:12000"
	@echo "  Health:       http://localhost:12000/healthz"
	@echo ""
	@echo "Test with:"
	@echo '  curl http://localhost:12000/v1/chat/completions -H "Content-Type: application/json" -d '"'"'{"model":"openai/gpt-4o","messages":[{"role":"user","content":"Hello"}]}'"'"''

test: build
	@echo "Starting Plano container..."
	@docker run -d --name $(CONTAINER_NAME)-test \
		-e PORT=12000 \
		-e OPENAI_API_KEY=sk-test-not-real \
		-p 12001:12000 \
		$(IMAGE_NAME)
	@echo "Waiting for startup..."
	@sleep 10
	@echo "Testing health endpoint..."
	@curl -sf http://localhost:12001/healthz && echo " OK" || echo " FAILED"
	@echo "Cleaning up..."
	@docker rm -f $(CONTAINER_NAME)-test 2>/dev/null || true

logs:
	docker logs -f $(CONTAINER_NAME)

shell:
	docker exec -it $(CONTAINER_NAME) /bin/bash

stop:
	docker stop $(CONTAINER_NAME) 2>/dev/null || true

clean: stop
	docker rm -f $(CONTAINER_NAME) 2>/dev/null || true
	docker rmi $(IMAGE_NAME) 2>/dev/null || true
