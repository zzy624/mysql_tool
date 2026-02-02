# Makefile - 数据库调试工具构建管理
# 支持全自动/手动双架构发布

# 应用配置
APP_NAME := 数据库调试工具
APP := mysql_tool
VERSION := $(shell git describe --tags --abbrev=0 2>/dev/null || echo "v0.0.1")

# Icon 配置
ICON_SRC := res/$(APP).png
ICONSET := $(APP).iconset

# Shell 设置
SHELL := /bin/bash

# 颜色定义（printf 格式，防止乱码）
BLUE := \033[0;34m
GREEN := \033[0;32m
YELLOW := \033[1;33m
RED := \033[0;31m
CYAN := \033[0;36m
NC := \033[0m

# 默认目标
.DEFAULT_GOAL := help

.PHONY: help pyui qrc builds icon clean clean-all install run status view-release info \
        setup check build-intel build-version \
        release release-auto release-smart release-manual

# ==========================================
# 帮助信息
# ==========================================
help:
	@printf "$(BLUE)🛠️  $(APP_NAME) 构建工具$(NC)\n\n"
	@printf "$(CYAN)【UI/资源构建】$(NC)\n"
	@printf "  make pyui          编译 UI 文件 (pyuic5)\n"
	@printf "  make qrc           编译资源文件 (pyrcc5)\n"
	@printf "  make icon          生成 macOS icns 图标\n"
	@printf "  make builds        本地快速构建 (不上传)\n\n"
	@printf "$(CYAN)【发布流程】$(NC)\n"
	@printf "  make release       智能发布 (推荐：自动检测是否需等待)\n"
	@printf "  make release-auto  全自动发布 (强制等待 Actions 完成)\n"
	@printf "  make release-manual手动发布 (人工确认后继续)\n"
	@printf "  make build-intel   仅构建 Intel 并上传 (当前 tag: $(VERSION))\n"
	@printf "  make build-version V=v1.0.0  指定版本构建\n\n"
	@printf "$(CYAN)【环境管理】$(NC)\n"
	@printf "  make setup         初始化环境 (安装 gh, 生成密钥)\n"
	@printf "  make check         检查环境配置\n"
	@printf "  make clean         清理构建产物\n"
	@printf "  make clean-all     深度清理 (含虚拟环境)\n\n"

# ==========================================
# 原有功能：UI/资源/图标/构建
# ==========================================

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
	@printf "$(GREEN)✅ 图标集生成完成$(NC)\n"

# ==========================================
# 环境初始化与检查
# ==========================================

setup:
	@printf "$(BLUE)🔧 初始化环境...$(NC)\n"
	@chmod +x build-intel-local.sh 2>/dev/null || true

	@if ! command -v gh >/dev/null 2>&1; then \
		printf "$(YELLOW)⚠️  未安装 GitHub CLI，正在安装...$(NC)\n"; \
		brew install gh; \
	fi

	@if ! gh auth status >/dev/null 2>&1; then \
		printf "$(YELLOW)请登录 GitHub...$(NC)\n"; \
		gh auth login; \
	else \
		printf "$(GREEN)✅ GitHub CLI 已登录$(NC)\n"; \
	fi

	@if [ ! -f ".env" ]; then \
		printf "$(BLUE)🔐 生成加密密钥...$(NC)\n"; \
		KEY=$$(openssl rand -hex 16); \
		echo "PYINSTALLER_KEY=$$KEY" > .env; \
		echo "DB_HOST=localhost" >> .env; \
		echo "DB_PORT=3306" >> .env; \
		echo "DB_USER=root" >> .env; \
		echo "DB_PASSWORD=" >> .env; \
		echo "DB_NAME=test" >> .env; \
		printf "$(GREEN)✅ 已生成 .env 文件，请编辑完善配置$(NC)\n"; \
		printf "$(YELLOW)⚠️  重要：请将 PYINSTALLER_KEY 添加到 GitHub Secrets$(NC)\n"; \
	else \
		printf "$(GREEN)✅ .env 文件已存在$(NC)\n"; \
	fi

check:
	@printf "$(BLUE)🔍 环境检查$(NC)\n"
	@printf "最新 Tag: $(GREEN)%s$(NC)\n" "$(VERSION)"

	@if command -v gh >/dev/null 2>&1; then \
		if gh auth status >/dev/null 2>&1; then \
			printf "  $(GREEN)✅$(NC) GitHub CLI (已登录)\n"; \
		else \
			printf "  $(YELLOW)⚠️$(NC) GitHub CLI (未登录)\n"; \
		fi \
	else \
		printf "  $(RED)❌$(NC) GitHub CLI (未安装)\n"; \
	fi

	@if [ -f ".env" ]; then \
		if grep -q "PYINSTALLER_KEY" .env; then \
			printf "  $(GREEN)✅$(NC) 加密密钥 (.env)\n"; \
		else \
			printf "  $(YELLOW)⚠️$(NC) 加密密钥 (未配置)\n"; \
		fi \
	else \
		printf "  $(RED)❌$(NC) .env 文件 (运行 make setup)\n"; \
	fi

	@if [ -f "build-intel-local.sh" ]; then \
		printf "  $(GREEN)✅$(NC) 构建脚本\n"; \
	else \
		printf "  $(RED)❌$(NC) 构建脚本 (build-intel-local.sh)\n"; \
	fi

# ==========================================
# 构建功能
# ==========================================

build-intel:
	@printf "$(BLUE)🚀 构建 Intel 版本...$(NC)\n"
	@printf "$(BLUE)自动检测到版本: $(GREEN)%s$(NC)\n" "$(VERSION)"

	@if [ "$(VERSION)" = "v0.0.1" ]; then \
		printf "$(YELLOW)⚠️  警告: 未检测到 git tag$(NC)\n"; \
		read -p "继续构建测试版本? (y/n): " confirm; \
		if [ "$$confirm" != "y" ]; then exit 1; fi; \
	fi

	@./build-intel-local.sh $(VERSION)

build-version:
	@if [ -z "$(V)" ]; then \
		printf "$(RED)❌ 错误: 请指定版本号$(NC)\n"; \
		printf "用法: make build-version V=v1.0.0\n"; \
		exit 1; \
	fi
	@printf "$(BLUE)🔧 构建指定版本: $(GREEN)%s$(NC)\n" "$(V)"
	@./build-intel-local.sh $(V)

# ==========================================
# 三种发布模式
# ==========================================

# 模式 1: 智能发布（默认，推荐）
# 自动检测 GitHub Actions 是否已完成，避免重复等待
release:
	@printf "$(BLUE)🚀 智能发布模式$(NC)\n"
	@printf "版本: $(GREEN)%s$(NC)\n\n" "$(VERSION)"

	@if [ "$(VERSION)" = "v0.0.1" ]; then \
		printf "$(RED)❌ 错误: 未检测到 git tag$(NC)\n"; \
		printf "请先创建并推送 tag:\n"; \
		printf "  git tag v1.0.0\n"; \
		printf "  git push origin v1.0.0\n"; \
		exit 1; \
	fi

	@printf "$(BLUE)步骤 1/2: 检查 GitHub Actions 状态...$(NC)\n"

	# 检查 Release 是否已存在且包含 ARM64 版本
	@if gh release view $(VERSION) >/dev/null 2>&1 && \
		gh release view $(VERSION) --json assets -q '.assets[].name' 2>/dev/null | grep -q "AppleSilicon"; then \
		printf "$(GREEN)✅ 检测到 ARM64 版本已存在，跳过等待$(NC)\n"; \
	else \
		printf "$(BLUE)推送 tag 触发 GitHub Actions...$(NC)\n"; \
		git push origin $(VERSION) 2>/dev/null || printf "$(YELLOW)Tag 已存在，跳过推送$(NC)\n"; \
		printf "\n$(YELLOW)⏳ 等待 ARM64 构建完成 (约 5-10 分钟)...$(NC)\n"; \
		printf "$(CYAN)提示: 可按 Ctrl+C 取消，稍后运行 make build-intel 继续$(NC)\n\n"; \
		gh run watch --tag $(VERSION) --exit-status || { \
			printf "\n$(RED)❌ GitHub Actions 构建失败或已取消$(NC)\n"; \
			exit 1; \
		}; \
		printf "\n$(GREEN)✅ ARM64 构建完成!$(NC)\n"; \
	fi

	@printf "\n$(BLUE)步骤 2/2: 本地构建 Intel 版本...$(NC)\n"
	@$(MAKE) build-intel

# 模式 2: 全自动发布（强制等待）
# 适用于首次发布或确保重新构建
release-auto:
	@printf "$(BLUE)🚀 全自动发布模式$(NC)\n"
	@printf "版本: $(GREEN)%s$(NC)\n\n" "$(VERSION)"

	@if [ "$(VERSION)" = "v0.0.1" ]; then \
		printf "$(RED)❌ 请先创建 git tag$(NC)\n"; \
		exit 1; \
	fi

	@printf "$(BLUE)步骤 1/3: 推送 tag...$(NC)\n"
	@git push origin $(VERSION) 2>/dev/null || printf "$(YELLOW)Tag 已存在$(NC)\n"

	@printf "\n$(BLUE)步骤 2/3: 等待 GitHub Actions (全自动)...$(NC)\n"
	@printf "$(YELLOW)⏳ 正在监控构建状态，请勿关闭终端...$(NC)\n\n"
	@gh run watch --tag $(VERSION) --exit-status || { \
		printf "$(RED)❌ GitHub Actions 失败$(NC)\n"; \
		exit 1; \
	}

	@printf "\n$(GREEN)✅ ARM64 构建成功!$(NC)\n"
	@printf "\n$(BLUE)步骤 3/3: 本地构建 Intel...$(NC)\n"
	@$(MAKE) build-intel

# 模式 3: 手动确认发布（旧版兼容）
# 推送后手动去网页查看，确认后再继续
release-manual:
	@printf "$(BLUE)🚀 手动发布模式$(NC)\n"
	@printf "版本: $(GREEN)%s$(NC)\n\n" "$(VERSION)"

	@if [ "$(VERSION)" = "v0.0.1" ]; then \
		printf "$(RED)❌ 请先创建 git tag$(NC)\n"; \
		exit 1; \
	fi

	@printf "$(BLUE)步骤 1/2: 推送 tag 触发 GitHub Actions...$(NC)\n"
	@git push origin $(VERSION) 2>/dev/null || printf "$(YELLOW)Tag 已存在$(NC)\n"

	@printf "\n$(GREEN)✅ 已触发 GitHub Actions$(NC)\n"
	@printf "$(CYAN)请前往查看进度:$(NC)\n"
	@printf "  https://github.com/$$(gh repo view --json nameWithOwner -q .nameWithOwner)/actions\n\n"

	@read -p "确认 Actions 完成后按回车继续 (或 Ctrl+C 取消)..." confirm
	@printf "\n$(BLUE)步骤 2/2: 本地构建 Intel...$(NC)\n"
	@$(MAKE) build-intel

# ==========================================
# 清理与辅助
# ==========================================

clean:
	@printf "$(BLUE)🧹 清理构建产物...$(NC)\n"
	rm -f *.icns
	rm -rf $(ICONSET)
	rm -rf build/ dist/ build-intel/ dist-intel/ __pycache__/
	rm -f *.spec.backup
	find . -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
	find . -type f -name "*.pyc" -delete 2>/dev/null || true
	find . -type f -name "*.pyo" -delete 2>/dev/null || true
	@printf "$(GREEN)✅ 清理完成$(NC)\n"

clean-all: clean
	@printf "$(BLUE)🧹 清理虚拟环境...$(NC)\n"
	rm -rf venv/ venv-intel/ .venv/
	@printf "$(GREEN)✅ 深度清理完成$(NC)\n"

install:
	@printf "$(BLUE)📦 安装依赖...$(NC)\n"
	pip install -r requirements.txt
	@printf "$(GREEN)✅ 完成$(NC)\n"

run:
	python main.py

status:
	@printf "$(BLUE)📊 GitHub Actions 最近运行:$(NC)\n"
	@gh run list --limit 5

view-release:
	@printf "$(BLUE)🌐 打开 Release 页面...$(NC)\n"
	@open "https://github.com/$$(gh repo view --json nameWithOwner -q .nameWithOwner)/releases/latest"

dmg:
	@if [ ! -d "dist/${APP_NAME}.app" ]; then \
		printf "$(RED)❌ 未找到 dist/${APP_NAME}.app，请先运行 make builds$(NC)\n"; \
		exit 1; \
	fi
	@printf "$(BLUE)📦 创建 DMG...$(NC)\n"
	@brew install create-dmg 2>/dev/null || true
	@cd dist && \
	create-dmg \
	  --volname "${APP_NAME}" \
	  --window-size 800 500 \
	  --icon-size 100 \
	  --app-drop-link 550 200 \
	  "${APP_NAME}.dmg" \
	  "${APP_NAME}.app"
	@printf "$(GREEN)✅ DMG 创建完成: dist/${APP_NAME}.dmg$(NC)\n"

info:
	@printf "$(BLUE)📋 项目信息$(NC)\n"
	@printf "  应用名称: $(APP_NAME)\n"
	@printf "  当前版本: $(VERSION)\n"
	@printf "  图标源:   $(ICON_SRC)\n"
	@printf "  仓库:     $$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || echo '未配置')\n"