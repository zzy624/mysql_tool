# Makefile - 数据库工具构建管理

APP_NAME_CN := 数据库工具
APP_NAME_EN := mysql_tool
APP := mysql_tool
VERSION := $(shell git describe --tags --abbrev=0 2>/dev/null || echo "v0.0.1")
ICON_SRC := res/$(APP).png
ICONSET := $(APP).iconset
SHELL := /bin/bash

BLUE := \033[0;34m
GREEN := \033[0;32m
YELLOW := \033[1;33m
RED := \033[0;31m
CYAN := \033[0;36m
NC := \033[0m

.DEFAULT_GOAL := help

.PHONY: help pyui qrc builds icon clean clean-all install run status view-release info \
        setup check build-intel build-version \
        release release-auto release-manual wait-actions

help:
	@printf "$(BLUE)🛠️  $(APP_NAME_CN) 构建工具$(NC)\n\n"
	@printf "$(CYAN)【UI/资源构建】$(NC)\n"
	@printf "  make pyui          编译 UI 文件 (pyuic5)\n"
	@printf "  make qrc           编译资源文件 (pyrcc5)\n"
	@printf "  make icon          生成 macOS icns 图标\n"
	@printf "  make builds        本地快速构建 (不上传)\n\n"
	@printf "$(CYAN)【发布流程】$(NC)\n"
	@printf "  make release       智能发布 (推荐)\n"
	@printf "  make release-auto  全自动发布\n"
	@printf "  make release-manual手动发布\n"
	@printf "  make build-intel   仅构建 Intel (当前 tag: %s)\n" "$(VERSION)"
	@printf "  make build-version V=v1.0.0  指定版本\n\n"
	@printf "$(CYAN)【环境管理】$(NC)\n"
	@printf "  make setup         初始化环境\n"
	@printf "  make check         检查环境\n"
	@printf "  make clean         清理构建产物\n\n"

pyui:
	pyuic5 -o ./ui/pyui/ui_main.py ./skin/main.ui

qrc:
	pyrcc5 -o ./ui/pyui/icon_rc.py ./res/icon.qrc

builds:
	pyinstaller --noconfirm main.spec

icon: $(ICONSET)
	iconutil -c icns $(ICONSET) -o res/$(APP).icns
	rm -rf $(ICONSET)

$(ICONSET):
	@printf "$(BLUE)📦 生成图标集...$(NC)\n"
	mkdir -p $(ICONSET)
	sips -z 16 16     $(ICON_SRC) --out $(ICONSET)/icon_16x16.png
	sips -z 32 32     $(ICON_SRC) --out $(ICONSET)/icon_16x16@2x.png
	sips -z 32 32     $(ICON_SRC) --out $(ICONSET)/icon_32x32.png
	sips -z 64 64     $(ICON_SRC) --out $(ICONSET)/icon_32x32@2x.png
	sips -z 128 128   $(ICON_SRC) --out $(ICONSET)/icon_128x128.png
	sips -z 256 256   $(ICON_SRC) --out $(ICONSET)/icon_128x128@2x.png
	sips -z 256 256   $(ICON_SRC) --out $(ICONSET)/icon_256x256.png
	sips -z 512 512   $(ICON_SRC) --out $(ICONSET)/icon_256x256@2x.png
	sips -z 512 512   $(ICON_SRC) --out $(ICONSET)/icon_512x512.png
	sips -z 1024 1024 $(ICON_SRC) --out $(ICONSET)/icon_512x512@2x.png
	@printf "$(GREEN)✅ 完成$(NC)\n"

setup:
	@printf "$(BLUE)🔧 初始化环境...$(NC)\n"
	@chmod +x build-intel-local.sh 2>/dev/null || true
	@if ! command -v gh >/dev/null 2>&1; then \
		brew install gh; \
	fi
	@if ! gh auth status >/dev/null 2>&1; then \
		gh auth login; \
	fi
	@if [ ! -f ".env" ]; then \
		echo "DB_HOST=localhost" > .env; \
		echo "DB_PORT=3306" >> .env; \
		echo "DB_USER=root" >> .env; \
		echo "DB_PASSWORD=" >> .env; \
		echo "DB_NAME=test" >> .env; \
		printf "$(GREEN)✅ 已生成 .env 文件$(NC)\n"; \
	fi

check:
	@printf "$(BLUE)🔍 环境检查$(NC)\n"
	@printf "最新 Tag: $(GREEN)%s$(NC)\n" "$(VERSION)"
	@command -v gh >/dev/null 2>&1 && printf "  ✅ GitHub CLI\n" || printf "  ❌ GitHub CLI\n"
	@[ -f ".env" ] && printf "  ✅ .env 文件\n" || printf "  ⚠️  .env 文件\n"

build-intel:
	@printf "$(BLUE)🚀 构建 Intel 版本...$(NC)\n"
	@printf "$(BLUE)版本: $(GREEN)%s$(NC)\n" "$(VERSION)"
	@if [ "$(VERSION)" = "v0.0.1" ]; then \
		printf "$(YELLOW)⚠️  未检测到 git tag$(NC)\n"; \
		read -p "继续? (y/n): " confirm; \
		[ "$$confirm" != "y" ] && exit 1; \
	fi
	@./build-intel-local.sh $(VERSION)

build-version:
	@if [ -z "$(V)" ]; then \
		printf "$(RED)❌ 请指定版本: make build-version V=v1.0.0$(NC)\n"; \
		exit 1; \
	fi
	@./build-intel-local.sh $(V)

wait-actions:
	@printf "$(YELLOW)获取最新 run-id...$(NC)\n"; \
	RUN_ID=$$(gh run list --limit 1 --json databaseId --jq '.[0].databaseId'); \
	if [ -z "$$RUN_ID" ]; then \
		printf "$(RED)❌ 未找到运行中的 workflow$(NC)\n"; \
		exit 1; \
	fi; \
	printf "$(CYAN)监控 run-id: $$RUN_ID$(NC)\n"; \
	gh run watch $$RUN_ID --exit-status

release:
	@printf "$(BLUE)🚀 智能发布模式$(NC)\n"
	@printf "版本: $(GREEN)%s$(NC)\n\n" "$(VERSION)"
	@if [ "$(VERSION)" = "v0.0.1" ]; then \
		printf "$(RED)❌ 请先创建 git tag$(NC)\n"; \
		exit 1; \
	fi
	@printf "$(BLUE)步骤 1/2: 检查 GitHub Actions 状态...$(NC)\n"
	@if gh release view $(VERSION) >/dev/null 2>&1 && \
		gh release view $(VERSION) --json assets -q '.assets[].name' 2>/dev/null | grep -q "_AppleSilicon"; then \
		printf "$(GREEN)✅ ARM64 版本已存在，跳过等待$(NC)\n"; \
	else \
		git push origin $(VERSION) 2>/dev/null || true; \
		printf "\n$(YELLOW)⏳ 等待 ARM64 构建...$(NC)\n"; \
		$(MAKE) wait-actions || exit 1; \
		printf "\n$(GREEN)✅ ARM64 完成!$(NC)\n"; \
	fi
	@printf "\n$(BLUE)步骤 2/2: 本地构建 Intel...$(NC)\n"
	@$(MAKE) build-intel

release-auto:
	@printf "$(BLUE)🚀 全自动发布模式$(NC)\n"
	@printf "版本: $(GREEN)%s$(NC)\n\n" "$(VERSION)"
	@if [ "$(VERSION)" = "v0.0.1" ]; then \
		printf "$(RED)❌ 请先创建 git tag$(NC)\n"; \
		exit 1; \
	fi
	@git push origin $(VERSION) 2>/dev/null || true
	@printf "\n$(YELLOW)⏳ 等待 GitHub Actions...$(NC)\n"
	@$(MAKE) wait-actions || exit 1
	@printf "\n$(GREEN)✅ ARM64 成功!$(NC)\n"
	@$(MAKE) build-intel

release-manual:
	@printf "$(BLUE)🚀 手动发布模式$(NC)\n"
	@git push origin $(VERSION) 2>/dev/null || true
	@printf "$(GREEN)✅ 已触发 GitHub Actions$(NC)\n"
	@read -p "Actions 完成后按回车继续..." confirm
	@$(MAKE) build-intel

clean:
	@printf "$(BLUE)🧹 清理...$(NC)\n"
	rm -rf build/ dist/ build-intel/ dist-intel/ __pycache__/ *.spec.backup
	rm -f *.icns
	rm -rf $(ICONSET)
	find . -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
	find . -name "*.pyc" -delete 2>/dev/null || true
	@printf "$(GREEN)✅ 完成$(NC)\n"

clean-all: clean
	rm -rf venv/ venv-intel/ .venv/

install:
	pip install -r requirements.txt

run:
	python main.py

status:
	gh run list --limit 5

view-release:
	open "https://github.com/$$(gh repo view --json nameWithOwner -q .nameWithOwner)/releases/latest"

info:
	@printf "$(BLUE)📋 项目信息$(NC)\n"
	@printf "  中文名: %s\n" "$(APP_NAME_CN)"
	@printf "  英文名: %s\n" "$(APP_NAME_EN)"
	@printf "  版本:   %s\n" "$(VERSION)"