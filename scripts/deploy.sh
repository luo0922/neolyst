#!/bin/bash

set -e

echo "========================================"
echo "🚀 Neolyst ECS 一键部署 (Next.js + Supabase)"
echo "========================================"

PROJECT_DIR="/var/www/neolyst"
REPO_URL="git@github.com:luo0922/neolyst.git"
CONTAINER_NAME="neolyst-next"
IMAGE_NAME="neolyst-next"
SSH_KEY_PATH="/root/.ssh/id_ed25519"

# 环境变量
SUPABASE_URL="https://neolyst-test.zeabur.app"
SUPABASE_ANON_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyAgCiAgICAicm9sZSI6ICJhbm9uIiwKICAgICJpc3MiOiAic3VwYWJhc2UtZGVtbyIsCiAgICAiaWF0IjogMTY0MTc2OTIwMCwKICAgICJleHAiOiAxNzk5NTM1NjAwCn0.dc_X5iR_VP_qT0zsiyj_I_OZ2T9FtRU2BBNWN8Bu4GE"
SUPABASE_SERVICE_ROLE_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyAgCiAgICAicm9sZSI6ICJzZXJ2aWNlX3JvbGUiLAogICAgImlzcyI6ICJzdXBhYmFzZS1kZW1vIiwKICAgICJpYXQiOiAxNjQxNzY5MjAwLAogICAgImV4cCI6IDE3OTk1MzU2MDAKfQ.DaYlNEoUrrEn2Ig7tqibS-PHK5vgusbcbo7X36XVt4Q"

# ---------------------------
# Step 1: 安装基础工具
# ---------------------------
echo "📦 Step 1: 安装基础工具"
dnf update -y
dnf install -y git curl wget

# ---------------------------
# Step 2: 安装 Docker
# ---------------------------
echo "🐳 Step 2: 安装 Docker"
if ! command -v docker &> /dev/null; then
    dnf install -y docker
    systemctl enable docker
    systemctl start docker
fi

# ---------------------------
# Step 3: 安装 Node.js 20
# ---------------------------
echo "📦 Step 3: 安装 Node.js 20"
if ! command -v node &> /dev/null; then
    curl -fsSL https://rpm.nodesource.com/setup_20.x | bash -
    dnf install -y nodejs
fi

# ---------------------------
# Step 4: 安装 pnpm
# ---------------------------
echo "📦 Step 4: 安装 pnpm"
if ! command -v pnpm &> /dev/null; then
    npm install -g pnpm
fi

# ---------------------------
# Step 5: 拉取或更新项目
# ---------------------------
echo "📂 Step 5: 拉取/更新项目"
if [ ! -d "$PROJECT_DIR" ]; then
    mkdir -p /var/www
    cd /var/www

    eval "$(ssh-agent -s)"
    ssh-add "$SSH_KEY_PATH" 2>/dev/null || true

    git clone "$REPO_URL" neolyst
else
    cd "$PROJECT_DIR"
    eval "$(ssh-agent -s)"
    ssh-add "$SSH_KEY_PATH" 2>/dev/null || true
    git pull origin main
fi

# ---------------------------
# Step 6: 安装 web 依赖（仅锁文件）
# ---------------------------
echo "📦 Step 6: 安装 web 依赖"
cd "$PROJECT_DIR/web"
pnpm install --frozen-lockfile

# ---------------------------
# Step 7: 清理旧容器
# ---------------------------
echo "🧹 Step 7: 清理旧容器"
docker stop "$CONTAINER_NAME" 2>/dev/null || true
docker rm -f "$CONTAINER_NAME" 2>/dev/null || true

# ---------------------------
# Step 8: 构建 Docker 镜像
# ---------------------------
echo "🐳 Step 8: 构建 Docker 镜像"
cd "$PROJECT_DIR"
docker build \
    --build-arg NEXT_PUBLIC_SUPABASE_URL="$SUPABASE_URL" \
    --build-arg NEXT_PUBLIC_SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY" \
    -t "$IMAGE_NAME" .

# ---------------------------
# Step 9: 启动容器
# ---------------------------
echo "🚀 Step 9: 启动容器"
docker run -d \
    --name "$CONTAINER_NAME" \
    -p 3000:3000 \
    -e SUPABASE_SERVICE_ROLE_KEY="$SUPABASE_SERVICE_ROLE_KEY" \
    --restart always \
    "$IMAGE_NAME"

# ---------------------------
# Step 10: 清理旧镜像
# ---------------------------
echo "🧹 Step 10: 清理旧镜像"
docker image prune -f

# ---------------------------
# 完成
# ---------------------------
echo "========================================"
echo "🎉 部署完成"
echo "访问地址: http://$(curl -s ifconfig.me):3000"
echo "========================================"
docker ps --filter "name=$CONTAINER_NAME"
