# Makefile for PocketFlow
# Run `make help` to list targets. Targets documented with `## ` show up in help.

SHELL := /bin/sh

GREEN := \033[0;32m
NC := \033[0m
CHIME := $(shell command -v afplay >/dev/null 2>&1 && echo "afplay /System/Library/Sounds/Glass.aiff" || echo "true")

FLUTTER := flutter
DART := dart
PROJECT_DIR := $(shell pwd)
FLUTTER_VERSION = $(shell $(FLUTTER) --version | head -n 1 | cut -d ' ' -f2)

# ENV=dev (default) or ENV=prod
ENV ?= dev

# Extra words after the target, e.g. `make test update-goldens coverage test/foo_test.dart`
RUN_ARGS := $(wordlist 2,$(words $(MAKECMDGOALS)),$(MAKECMDGOALS))
UPDATE_GOLDENS := $(if $(filter update-goldens,$(RUN_ARGS)),--update-goldens,)
COVERAGE := $(if $(filter coverage,$(RUN_ARGS)),--coverage,)
TEST_PATH := $(filter test/%.dart,$(RUN_ARGS))

DOCKER_IMAGE := pocketflow_tests
DOCKER_ARGS := -v $(PROJECT_DIR):/project -v ~/.pub-cache:/cache -e PUB_CACHE=/cache

.DEFAULT_GOAL := help

.PHONY: help
help: ## Show this help
	@awk 'BEGIN {FS = ":.*## "} /^[a-zA-Z0-9_-]+:.*## / {printf "  $(GREEN)%-18s$(NC) %s\n", $$1, $$2}' $(MAKEFILE_LIST)
	@echo "\n  Test options: make test [update-goldens] [coverage] [test/path/to_test.dart]"

###################
# Run
###################

.PHONY: run run-prod release preview
# Debug runs pick up GROQ_API_KEY from .env (gitignored) when it exists.
DEFINE_ENV_FILE := $(if $(wildcard .env),--dart-define-from-file=.env,)

run: ## Run the app (ENV=dev); uses GROQ_API_KEY from .env if present
	@$(FLUTTER) run --dart-define=ENV=$(ENV) $(DEFINE_ENV_FILE)

run-prod: ## Run the app against production
	@$(FLUTTER) run --dart-define=ENV=prod

release: ## Run in release mode against production
	@$(FLUTTER) run --release --dart-define=ENV=prod

preview: ## Start the Flutter widget previewer (@Preview annotations)
	@$(FLUTTER) widget-preview start

###################
# Code quality & generation
###################

.PHONY: get clean buildrunner watch format analyze fix check
get: ## flutter pub get
	@$(FLUTTER) pub get

clean: ## Clean build artifacts and re-fetch packages
	@$(FLUTTER) clean
	@$(FLUTTER) widget-preview clean >/dev/null 2>&1 || true
	@$(FLUTTER) pub get

buildrunner: ## Run build_runner once (dart_mappable, etc.)
	@$(DART) run build_runner build --delete-conflicting-outputs

watch: ## Run build_runner in watch mode
	@$(DART) run build_runner watch --delete-conflicting-outputs

format: ## Format lib and test
	@$(DART) format lib test

analyze: ## Static analysis
	@$(FLUTTER) analyze

fix: ## Apply automated lint fixes
	@$(DART) fix --apply

check: ## Format check + analyze + non-golden tests (what CI runs)
	@$(DART) format --output=none --set-exit-if-changed lib test
	@$(FLUTTER) analyze
	@$(FLUTTER) test --exclude-tags=golden
	@$(CHIME)

###################
# Testing
###################

.PHONY: test test-local docker-setup update-goldens coverage
test-local: ## Run tests locally
	@echo "$(GREEN)Running tests locally$(NC)"
	@$(FLUTTER) test $(TEST_PATH) $(UPDATE_GOLDENS) $(COVERAGE)
	@$(CHIME)

test: docker-image ## Run tests in Docker (Linux, matches CI goldens)
	@echo "$(GREEN)Running tests in Docker$(NC)"
	docker run -t --rm $(DOCKER_ARGS) $(DOCKER_IMAGE) \
		/bin/sh -c "/project/test/docker/docker_test.sh --packagePath /project $(TEST_PATH) $(UPDATE_GOLDENS) $(COVERAGE)"
	@$(FLUTTER) pub get >/dev/null
	@$(CHIME)

.PHONY: docker-image
docker-image:
	@chmod +x test/docker/docker_test.sh
	@docker image inspect $(DOCKER_IMAGE) >/dev/null 2>&1 || $(MAKE) --no-print-directory docker-setup

docker-setup: ## (Re)build the Docker test image for the current Flutter version
	@echo "$(GREEN)Building Docker test image (Flutter $(FLUTTER_VERSION))$(NC)"
	docker build --build-arg flutter_version=$(FLUTTER_VERSION) -t $(DOCKER_IMAGE) test/docker/

# No-op targets so extra words after `make test` are accepted
update-goldens coverage:
	@:
test/%.dart:
	@:

###################
# Build
###################

.PHONY: build-apk build-ios build-web app-icon
build-apk: ## Build release APK (prod)
	@$(FLUTTER) build apk --release --dart-define=ENV=prod

build-ios: ## Build release IPA (prod)
	@$(FLUTTER) build ipa --release --dart-define=ENV=prod

build-web: ## Build release web bundle (prod)
	@$(FLUTTER) build web --release --dart-define=ENV=prod

app-icon: ## Generate launcher icons (requires flutter_launcher_icons config)
	@$(DART) run flutter_launcher_icons
