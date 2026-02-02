#!/bin/bash
# build-intel-local.sh - 本地构建 Intel x86_64 版本（PyInstaller 6.x 兼容版）

set -e

APP_NAME="数据库调试工具"
SPEC_FILE="main.spec"
VERSION=${1:-$(git describe --tags --abbrev=0)}

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${BLUE}🚀 开始本地 Intel 构建流程${NC}"
echo -e "版本: ${GREEN}$VERSION${NC}"
echo ""

# 检查 gh CLI
if ! command -v gh &> /dev/null; then
    echo -e "${RED}❌ 错误: 未安装 GitHub CLI (gh)${NC}"
    echo "安装: brew install gh"
    exit 1
fi

if ! gh auth status &> /dev/null; then
    echo -e "${YELLOW}⚠️  需要登录 GitHub${NC}"
    gh auth login
fi

REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner)
echo "仓库: $REPO"

# 检查 Release
echo "🔍 检查 GitHub Release $VERSION..."
if ! gh release view "$VERSION" &> /dev/null; then
    echo -e "${RED}❌ Release $VERSION 不存在${NC}"
    echo "请先推送 tag: git push origin $VERSION"
    exit 1
fi

# 检查是否已存在 Intel 版本
if gh release view "$VERSION" --json assets -q '.assets[].name' | grep -q "Intel"; then
    echo -e "${YELLOW}⚠️  Intel 版本已存在${NC}"
    read -p "覆盖? (y/n): " confirm
    [[ $confirm != "y" ]] && exit 0
fi

# 清理
echo "🧹 清理旧构建..."
rm -rf build dist build-intel dist-intel venv-intel
mkdir -p dist-intel

# 检测架构
CURRENT_ARCH=$(uname -m)
USE_ROSETTA=false
if [ "$CURRENT_ARCH" == "arm64" ]; then
    echo -e "${YELLOW}⚠️  Apple Silicon 检测，将使用 Rosetta 2${NC}"
    USE_ROSETTA=true
    if ! /usr/bin/pgrep oahd &> /dev/null; then
        echo "安装 Rosetta 2..."
        softwareupdate --install-rosetta --agree-to-license
    fi
else
    echo -e "${GREEN}✅ Intel Mac 检测${NC}"
fi

# 创建虚拟环境
echo "🐍 创建虚拟环境..."
if [ "$USE_ROSETTA" == "true" ]; then
    arch -x86_64 /usr/bin/python3 -m venv venv-intel
else
    python3 -m venv venv-intel
fi

source venv-intel/bin/activate

# 安装依赖
echo "📦 安装依赖 (PyQt5==5.15.11, PyInstaller==6.11.0)..."
if [ "$USE_ROSETTA" == "true" ]; then
    arch -x86_64 pip install --upgrade pip setuptools wheel
    arch -x86_64 pip install -r requirements.txt
else
    pip install --upgrade pip setuptools wheel
    pip install -r requirements.txt
fi

# 验证（修复后的导入方式）
echo "🔍 验证安装..."
python -c "from PyQt5 import QtCore; print(f'✓ PyQt5 {QtCore.PYQT_VERSION_STR}')"
python -c "import mysql.connector; print(f'✓ mysql-connector {mysql.connector.__version__}')"
python -c "import PyInstaller; print(f'✓ PyInstaller {PyInstaller.__version__}')"

# 注入配置
echo "⚙️  注入配置..."
if [ -f ".env.local" ]; then
    export $(grep -v '^#' .env.local | xargs)
elif [ -f ".env" ]; then
    export $(grep -v '^#' .env | xargs)
fi

if [ -f "config/config.ini.template" ]; then
    cp config/config.ini.template config/config.ini
    sed -i '' "s/{{DB_HOST}}/${DB_HOST:-localhost}/g" config/config.ini
    sed -i '' "s/{{DB_PORT}}/${DB_PORT:-3306}/g" config/config.ini
    sed -i '' "s/{{DB_USER}}/${DB_USER:-root}/g" config/config.ini
    sed -i '' "s/{{DB_PASSWORD}}/${DB_PASSWORD:-}/g" config/config.ini
    sed -i '' "s/{{DB_NAME}}/${DB_NAME:-test}/g" config/config.ini
fi

# 修改 spec
echo "📝 配置 spec (x86_64)..."
cp "$SPEC_FILE" "${SPEC_FILE}.backup"
sed -i '' "s/target_arch=None/target_arch='x86_64'/" "$SPEC_FILE"
sed -i '' "s|entitlements_file=None|entitlements_file='entitlements.plist'|" "$SPEC_FILE"

# 构建
echo -e "${BLUE}🔨 开始构建 (约 5-10 分钟)...${NC}"
START_TIME=$(date +%s)

if [ "$USE_ROSETTA" == "true" ]; then
    arch -x86_64 pyinstaller --noconfirm --distpath dist-intel "$SPEC_FILE"
else
    pyinstaller --noconfirm --distpath dist-intel "$SPEC_FILE"
fi

END_TIME=$(date +%s)
echo "构建耗时: $((END_TIME - START_TIME)) 秒"

# 验证架构
BINARY="dist-intel/${APP_NAME}.app/Contents/MacOS/main"
echo "🔍 验证架构..."
file "$BINARY"
if ! file "$BINARY" | grep -q "x86_64"; then
    echo -e "${RED}❌ 架构验证失败!${NC}"
    mv "${SPEC_FILE}.backup" "$SPEC_FILE"
    exit 1
fi
echo -e "${GREEN}✅ x86_64 验证通过${NC}"

# ==========================================
# 创建 DMG 安装包
# ==========================================
echo "📦 创建 DMG 安装包..."

cd dist-intel
mv "${APP_NAME}.app" "${APP_NAME}_Intel.app"

# 检查并安装 create-dmg
if ! command -v create-dmg &> /dev/null; then
    echo "安装 create-dmg..."
    brew install create-dmg
fi

DMG_NAME="${APP_NAME}_Intel.dmg"
VOL_NAME="${APP_NAME} Intel"

echo "正在生成 DMG..."

if create-dmg \
  --volname "$VOL_NAME" \
  --window-pos 200 120 \
  --window-size 800 500 \
  --icon-size 100 \
  --app-drop-link 550 200 \
  --hide-extension "${APP_NAME}_Intel.app" \
  --background-color 0x2d2d2d \
  --format UDZO \
  "$DMG_NAME" \
  "${APP_NAME}_Intel.app" 2>/dev/null; then

    echo -e "${GREEN}✅ DMG 创建成功${NC}"
    mv "$DMG_NAME" "../$DMG_NAME"
    cd ..
    FILE_PATH="$DMG_NAME"
    FILE_SIZE=$(du -h "$FILE_PATH" | cut -f1)
    FILE_TYPE="DMG"

else
    echo -e "${YELLOW}⚠️  DMG 创建失败，回退到 ZIP...${NC}"
    ZIP_NAME="${APP_NAME}_Intel.zip"
    ditto -c -k --keepParent "${APP_NAME}_Intel.app" "../$ZIP_NAME"
    cd ..
    FILE_PATH="$ZIP_NAME"
    FILE_SIZE=$(du -h "$FILE_PATH" | cut -f1)
    FILE_TYPE="ZIP"
fi

echo -e "${GREEN}✅ 打包完成: $FILE_PATH ($FILE_SIZE) [$FILE_TYPE]${NC}"

# 上传到 GitHub
echo -e "${BLUE}📤 上传到 GitHub Release...${NC}"
gh release upload "$VERSION" "$FILE_PATH" --clobber --repo "$REPO"
echo -e "${GREEN}✅ 上传完成${NC}"

# 恢复 spec
mv "${SPEC_FILE}.backup" "$SPEC_FILE"

# 更新 Release 描述
BODY=$(gh release view "$VERSION" --json body -q .body)
if echo "$BODY" | grep -q "等待本地构建"; then
    NEW_BODY=$(echo "$BODY" | sed 's/⏳ Intel (x86_64): 等待本地构建.../✅ Intel (x86_64): 已完成 ('"$FILE_SIZE"')/')
    echo "$NEW_BODY" > /tmp/release_body.txt
    gh release edit "$VERSION" --notes-file /tmp/release_body.txt --repo "$REPO"
fi

# 检查是否发布正式版
ASSETS=$(gh release view "$VERSION" --json assets -q '.assets[].name')
if echo "$ASSETS" | grep -q "AppleSilicon" && echo "$ASSETS" | grep -q "Intel"; then
    echo ""
    echo -e "${GREEN}🎉 双架构完成！${NC}"
    read -p "发布正式版? (y/n): " publish
    if [[ $publish == "y" ]]; then
        gh release edit "$VERSION" --draft=false --repo "$REPO"
        echo -e "${GREEN}✅ 已发布正式版！${NC}"
    fi
fi

# 清理
deactivate
rm -rf venv-intel

echo ""
echo -e "${GREEN}🎉 本地 Intel 构建流程完成！${NC}"
echo -e "🔗 ${CYAN}https://github.com/$REPO/releases/tag/$VERSION${NC}"
open "https://github.com/$REPO/releases/tag/$VERSION"