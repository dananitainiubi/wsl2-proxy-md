#!/bin/bash
# WSL2 代理连接诊断脚本

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

print_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[✓]${NC} $1"; }
print_error() { echo -e "${RED}[✗]${NC} $1"; }

echo -e "${GREEN}"
echo "=========================================="
echo "   WSL2 代理连接诊断工具"
echo "=========================================="
echo -e "${NC}"

# 1. 检查网络配置
print_info "1. 检查 WSL2 网络配置..."
WSL2_IP=$(ip addr show eth0 | grep "inet " | awk '{print $2}' | cut -d/ -f1)
WSL2_GATEWAY=$(ip route show | grep default | awk '{print $3}')

echo "  WSL2 IP:       ${WSL2_IP}"
echo "  WSL2 网关：    ${WSL2_GATEWAY}"

# 2. 测试网关连接
echo ""
print_info "2. 测试 WSL2 网关连接..."
if timeout 2 bash -c "echo > /dev/tcp/${WSL2_GATEWAY}/41857" 2>/dev/null; then
    print_success "网关 41857 端口可达"
else
    print_error "网关 41857 端口不可达"
    print_info "   可能原因：Clash Verge 未监听 WSL 虚拟网卡"
fi

# 3. 测试物理网卡连接
echo ""
print_info "3. 测试宿主机物理网卡连接..."
HOST_PHYSICAL_IP="192.168.0.56"

if timeout 2 bash -c "echo > /dev/tcp/${HOST_PHYSICAL_IP}/41857" 2>/dev/null; then
    print_success "物理网卡 41857 端口可达"
else
    print_error "物理网卡 41857 端口不可达"
    print_info "   可能原因：Windows 防火墙拦截"
fi

# 4. 检查当前代理环境变量
echo ""
print_info "4. 检查当前代理配置..."
if [ -n "$http_proxy" ]; then
    print_success "http_proxy: $http_proxy"
else
    print_error "http_proxy 未设置"
fi

if [ -n "$https_proxy" ]; then
    print_success "https_proxy: $https_proxy"
else
    print_error "https_proxy 未设置"
fi

# 5. 检查 netcat 版本
echo ""
print_info "5. 检查 netcat 版本..."
if command -v nc &> /dev/null; then
    NC_VERSION=$(nc -h 2>&1 | head -1)
    if echo "$NC_VERSION" | grep -i "openbsd" > /dev/null; then
        print_success "netcat-openbsd: $NC_VERSION"
    else
        print_error "netcat 版本可能不支持 -X 参数：$NC_VERSION"
        print_info "   建议：sudo apt install netcat-openbsd"
    fi
else
    print_error "未安装 netcat"
fi

# 6. 检查 SSH 配置
echo ""
print_info "6. 检查 SSH 配置..."
if [ -f ~/.ssh/config ]; then
    if grep -q "ProxyCommand" ~/.ssh/config; then
        print_success "SSH ProxyCommand 已配置"
        echo "   配置内容："
        grep -A1 "Host github.com" ~/.ssh/config | grep ProxyCommand | sed 's/^/     /'
    else
        print_error "SSH 配置中未找到 ProxyCommand"
    fi
else
    print_error "~/.ssh/config 不存在"
fi

# 7. 测试实际代理连接
echo ""
print_info "7. 测试实际代理连接（使用网关 IP）..."
if timeout 5 curl -s --connect-timeout 3 -x ${WSL2_GATEWAY}:41857 http://www.google.com >/dev/null 2>&1; then
    print_success "通过网关代理访问 Google 成功"
else
    print_error "通过网关代理访问 Google 失败"
fi

echo ""
print_info "8. 测试实际代理连接（使用物理 IP）..."
if timeout 5 curl -s --connect-timeout 3 -x ${HOST_PHYSICAL_IP}:41857 http://www.google.com >/dev/null 2>&1; then
    print_success "通过物理 IP 代理访问 Google 成功"
else
    print_error "通过物理 IP 代理访问 Google 失败"
fi

echo ""
echo -e "${GREEN}=========================================="
echo "   诊断完成"
echo "==========================================${NC}"
echo ""
print_info "建议操作："
echo "  1. 确认 Clash Verge 已开启 Allow LAN"
echo "  2. 检查 Windows 防火墙是否允许 Clash Verge"
echo "  3. 在 Windows 上运行：netstat -ano | findstr 41857"
echo "     查看 41857 端口绑定的 IP 地址"
echo "  4. 如果绑定的是 127.0.0.1，需要改为 0.0.0.0"
