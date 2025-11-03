# Makefile for Network Connection Checker

SHELL := /bin/bash

# 프로젝트 설정
APP_NAME := ncc
SCRIPT := check.sh

# 버전 정보 (VERSION 파일에서 읽기)
VERSION := $(shell cat VERSION 2>/dev/null || echo "dev")
GIT_COMMIT := $(shell git rev-parse --short HEAD 2>/dev/null || echo "unknown")
BUILD_DATE := $(shell date -u +"%Y-%m-%dT%H:%M:%SZ")

# Docker 설정
DOCKER_REGISTRY ?= docker.io
DOCKER_USERNAME := sanghaklee
DOCKER_IMAGE := $(APP_NAME)
DOCKER_TAG ?= $(VERSION)
DOCKER_FULL_IMAGE := $(DOCKER_USERNAME)/$(DOCKER_IMAGE):$(DOCKER_TAG)
DOCKER_LATEST := $(DOCKER_USERNAME)/$(DOCKER_IMAGE):latest


# 테스트 파일
TEST_FILE ?= .env.sample

# 색상 코드
CYAN := \033[0;36m
GREEN := \033[0;32m
YELLOW := \033[1;33m
RED := \033[0;31m
NC := \033[0m

# PHONY 타겟 정의 (카테고리별)
.PHONY: help version status
.PHONY: test test-verbose
.PHONY: docker-login docker-build docker-run docker-push docker-all docker-info docker-clean
.PHONY: bump-patch bump-minor bump-major
.PHONY: release-patch release-minor release-major
.PHONY: clean clean-all

# 기본 타겟
help:
	@echo -e "$(CYAN)========================================$(NC)"
	@echo -e "$(CYAN)🔍 Connection Checker - Makefile$(NC)"
	@echo -e "$(CYAN)========================================$(NC)"
	@echo ""
	@echo -e "$(GREEN)📦 현재 버전:$(NC) $(VERSION)"
	@echo -e "$(GREEN)🔖 Git Commit:$(NC) $(GIT_COMMIT)"
	@echo ""
	@echo -e "$(GREEN)사용 가능한 명령어:$(NC)"
	@echo ""
	@echo -e "  $(CYAN)로컬 테스트:$(NC)"
	@echo "    make test              - 호스트에서 .env 테스트"
	@echo "    make test-verbose      - 상세 모드로 테스트"
	@echo ""
	@echo -e "  $(CYAN)Docker 관련:$(NC)"
	@echo "    make docker-build      - Docker 이미지 빌드"
	@echo "    make docker-run        - Docker로 테스트 실행"
	@echo "    make docker-push       - Docker Hub에 푸시"
	@echo "    make docker-all        - 빌드 + 푸시 한번에"
	@echo ""
	@echo -e "  $(CYAN)버전 관리:$(NC)"
	@echo "    make version           - 현재 버전 확인"
	@echo "    make bump-patch        - 패치 버전 증가 (x.x.1)"
	@echo "    make bump-minor        - 마이너 버전 증가 (x.1.0)"
	@echo "    make bump-major        - 메이저 버전 증가 (1.0.0)"
	@echo ""
	@echo -e "  $(CYAN)기타:$(NC)"
	@echo "    make clean             - 캐시 정리"
	@echo "    make docker-login      - Docker Hub 로그인"
	@echo ""

# ========================================
# 로컬 테스트
# ========================================

test:
	@echo -e "$(GREEN)🔍 호스트에서 테스트 실행...$(NC)"
	@./$(SCRIPT) -e $(TEST_FILE)

test-verbose:
	@echo -e "$(GREEN)🔍 상세 모드로 테스트 실행...$(NC)"
	@./$(SCRIPT) -e $(TEST_FILE) -v

# ========================================
# Docker 관련
# ========================================

docker-login:
	@echo -e "$(CYAN)🔐 Docker Hub 로그인...$(NC)"
	@docker login $(DOCKER_REGISTRY)

docker-build:
	@echo -e "$(CYAN)🐳 Docker 이미지 빌드 중...$(NC)"
	@echo "  • 이미지: $(DOCKER_FULL_IMAGE)"
	@echo "  • 버전: $(VERSION)"
	@echo "  • Commit: $(GIT_COMMIT)"
	@docker build \
		--build-arg VERSION=$(VERSION) \
		--build-arg GIT_COMMIT=$(GIT_COMMIT) \
		--build-arg BUILD_DATE=$(BUILD_DATE) \
		--tag $(DOCKER_FULL_IMAGE) \
		--tag $(DOCKER_LATEST) \
		.
	@echo -e "$(GREEN)✅ 빌드 완료!$(NC)"
	@echo "  • $(DOCKER_FULL_IMAGE)"
	@echo "  • $(DOCKER_LATEST)"

docker-run:
	@echo -e "$(CYAN)🚀 Docker로 테스트 실행...$(NC)"
	@docker run --rm \
		-v $(PWD):/workspace \
		$(DOCKER_LATEST) \
		-e $(TEST_FILE)

docker-push:
	@echo -e "$(CYAN)📤 Docker Hub에 푸시 중...$(NC)"
	@echo "  • Registry: $(DOCKER_REGISTRY)"
	@echo "  • 이미지: $(DOCKER_USERNAME)/$(DOCKER_IMAGE)"
	@echo ""
	@echo -e "$(YELLOW)푸시할 태그:$(NC)"
	@echo "  • $(DOCKER_FULL_IMAGE)"
	@echo "  • $(DOCKER_LATEST)"
	@echo ""
	@docker push $(DOCKER_FULL_IMAGE)
	@docker push $(DOCKER_LATEST)
	@echo ""
	@echo -e "$(GREEN)✅ 푸시 완료!$(NC)"
	@echo ""
	@echo -e "$(GREEN)이미지 사용 방법:$(NC)"
	@echo "  docker pull $(DOCKER_LATEST)"
	@echo "  docker pull $(DOCKER_FULL_IMAGE)"

docker-all: docker-build docker-push
	@echo -e "$(GREEN)✨ 모든 Docker 작업 완료!$(NC)"

# Docker 이미지 정보 확인
docker-info:
	@echo -e "$(CYAN)📊 Docker 이미지 정보$(NC)"
	@docker images $(DOCKER_USERNAME)/$(DOCKER_IMAGE)
	@echo ""
	@echo -e "$(CYAN)🏷️  로컬 태그:$(NC)"
	@docker images $(DOCKER_USERNAME)/$(DOCKER_IMAGE) --format "table {{.Repository}}:{{.Tag}}\t{{.Size}}\t{{.CreatedSince}}"

# Docker 이미지 삭제
docker-clean:
	@echo -e "$(YELLOW)🧹 Docker 이미지 삭제 중...$(NC)"
	@docker rmi $(DOCKER_FULL_IMAGE) 2>/dev/null || true
	@docker rmi $(DOCKER_LATEST) 2>/dev/null || true
	@echo -e "$(GREEN)✅ Docker 이미지 정리 완료$(NC)"

# ========================================
# 버전 관리
# ========================================

version:
	@echo "현재 버전: $(VERSION)"

bump-patch:
	@echo -e "$(CYAN)📌 패치 버전 증가...$(NC)"
	@VERSION=$$(echo $(VERSION) | awk -F. '{$$NF = $$NF + 1;} 1' OFS=.) && \
		echo "$$VERSION" > VERSION && \
		echo -e "$(GREEN)✅ 버전 업데이트: $(VERSION) → $$VERSION$(NC)"

bump-minor:
	@echo -e "$(CYAN)📌 마이너 버전 증가...$(NC)"
	@VERSION=$$(echo $(VERSION) | awk -F. '{$$2 = $$2 + 1; $$3 = 0;} 1' OFS=.) && \
		echo "$$VERSION" > VERSION && \
		echo -e "$(GREEN)✅ 버전 업데이트: $(VERSION) → $$VERSION$(NC)"

bump-major:
	@echo -e "$(CYAN)📌 메이저 버전 증가...$(NC)"
	@VERSION=$$(echo $(VERSION) | awk -F. '{$$1 = $$1 + 1; $$2 = 0; $$3 = 0;} 1' OFS=.) && \
		echo "$$VERSION" > VERSION && \
		echo -e "$(GREEN)✅ 버전 업데이트: $(VERSION) → $$VERSION$(NC)"

# ========================================
# 릴리즈 워크플로우
# ========================================

release-patch: bump-patch
	@$(MAKE) docker-all
	@echo -e "$(GREEN)🎉 패치 릴리즈 완료!$(NC)"
	@git add VERSION
	@git commit -m "chore: bump version to $$(cat VERSION)"
	@git tag -a "v$$(cat VERSION)" -m "Release v$$(cat VERSION)"
	@echo -e "$(YELLOW)Git 태그를 푸시하려면:$(NC)"
	@echo "  git push origin main"
	@echo "  git push origin v$$(cat VERSION)"

release-minor: bump-minor
	@$(MAKE) docker-all
	@echo -e "$(GREEN)🎉 마이너 릴리즈 완료!$(NC)"
	@git add VERSION
	@git commit -m "chore: bump version to $$(cat VERSION)"
	@git tag -a "v$$(cat VERSION)" -m "Release v$$(cat VERSION)"
	@echo -e "$(YELLOW)Git 태그를 푸시하려면:$(NC)"
	@echo "  git push origin main"
	@echo "  git push origin v$$(cat VERSION)"

release-major: bump-major
	@$(MAKE) docker-all
	@echo -e "$(GREEN)🎉 메이저 릴리즈 완료!$(NC)"
	@git add VERSION
	@git commit -m "chore: bump version to $$(cat VERSION)"
	@git tag -a "v$$(cat VERSION)" -m "Release v$$(cat VERSION)"
	@echo -e "$(YELLOW)Git 태그를 푸시하려면:$(NC)"
	@echo "  git push origin main"
	@echo "  git push origin v$$(cat VERSION)"

# ========================================
# 기타
# ========================================

clean:
	@echo -e "$(YELLOW)🧹 정리 중...$(NC)"
	@rm -f *.log
	@rm -f .*.swp
	@echo -e "$(GREEN)✅ 정리 완료$(NC)"

# 전체 정리 (Docker 포함)
clean-all: clean docker-clean
	@echo -e "$(GREEN)✨ 모든 정리 완료!$(NC)"

# 상태 확인
status:
	@echo -e "$(CYAN)========================================$(NC)"
	@echo -e "$(CYAN)📊 프로젝트 상태$(NC)"
	@echo -e "$(CYAN)========================================$(NC)"
	@echo ""
	@echo -e "$(GREEN)버전:$(NC) $(VERSION)"
	@echo -e "$(GREEN)Git:$(NC) $(GIT_COMMIT)"
	@echo -e "$(GREEN)날짜:$(NC) $(BUILD_DATE)"
