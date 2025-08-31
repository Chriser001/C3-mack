#!/bin/bash

# 定义颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 检查是否为 root 用户
if [ "$(id -u)" -ne 0 ]; then
    echo -e "${YELLOW}[警告] 建议使用 root 用户运行此脚本，否则部分依赖可能安装失败。${NC}"
    sleep 2
fi

# 检测系统类型
OS=""
if [ -f /etc/alpine-release ]; then
    OS="alpine"
elif [ -f /etc/debian_version ]; then
    OS="debian"
elif [ "$(uname)" == "Darwin" ]; then
    OS="macos"
else
    echo -e "${RED}[错误] 不支持的操作系统！${NC}"
    exit 1
fi

echo -e "${GREEN}[信息] 检测到系统: ${OS}${NC}"

# 安装依赖
install_deps() {
    case "$OS" in
        alpine)
            echo -e "${GREEN}[信息] 安装 Alpine 依赖...${NC}"
            apk add --no-cache git cmake make g++ libuv-dev openssl-dev hwloc-dev linux-headers
            ;;
        debian)
            echo -e "${GREEN}[信息] 安装 Debian/Ubuntu 依赖...${NC}"
            apt-get update
            apt-get install -y git cmake make g++ libuv1-dev libssl-dev libhwloc-dev
            ;;
        macos)
            echo -e "${GREEN}[信息] 安装 macOS 依赖...${NC}"
            if ! command -v brew &> /dev/null; then
                echo -e "${RED}[错误] 请先安装 Homebrew: https://brew.sh/${NC}"
                exit 1
            fi
            brew install git cmake make libuv openssl hwloc
            ;;
        *)
            echo -e "${RED}[错误] 未知系统！${NC}"
            exit 1
            ;;
    esac
}

# 克隆仓库
clone_repo() {
    if [ -d "xmrig-C3" ]; then
        echo -e "${YELLOW}[警告] xmrig-C3 目录已存在，跳过克隆...${NC}"
    else
        echo -e "${GREEN}[信息] 克隆 xmrig-C3 仓库...${NC}"
        git clone https://github.com/C3Pool/xmrig-C3.git
    fi
}

# 配置编译选项
configure_build() {
    local cmake_flags="-DCMAKE_BUILD_TYPE=Release"
    
    # 针对 ARM 优化（Apple M 系列/Alpine ARM64）
    if [ "$(uname -m)" == "arm64" ] || [ "$(uname -m)" == "aarch64" ]; then
        cmake_flags="$cmake_flags -DCMAKE_C_FLAGS=\"-O3 -march=native\" -DCMAKE_CXX_FLAGS=\"-O3 -march=native\""
    fi

    # macOS 需要指定 OpenSSL 路径
    if [ "$OS" == "macos" ]; then
        openssl_path=$(brew --prefix openssl)
        cmake_flags="$cmake_flags -DOPENSSL_ROOT_DIR=$openssl_path"
    fi

    echo -e "${GREEN}[信息] 配置编译选项: ${cmake_flags}${NC}"
    cd xmrig-C3 && mkdir -p build && cd build
    cmake $cmake_flags ..
}

# 编译
compile() {
    echo -e "${GREEN}[信息] 开始编译...${NC}"
    make -j$(nproc)
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}[成功] 编译完成！二进制文件位于: xmrig-C3/build/xmrig${NC}"
    else
        echo -e "${RED}[错误] 编译失败！${NC}"
        exit 1
    fi
}

# 主流程
install_deps
clone_repo
configure_build
compile
