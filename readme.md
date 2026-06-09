# WSL2 代理配置指南

> **适用环境**：Windows 10/11 + WSL2 (NAT 模式) + Clash Verge 等代理客户端  
> **配置方式**：推荐使用自动化脚本

---

## 快速开始

### 方式一：自动配置（推荐）

```bash
cd ~/projects/wsl2-proxy-md
bash setup-wsl2-proxy.sh
```

脚本会自动完成：
- ✅ 检测宿主机 IP
- ✅ 配置代理端口
- ✅ 写入 `.bashrc` 和 `.ssh/config`
- ✅ 安装必要工具

配置完成后执行：
```bash
source ~/.bashrc
proxy_on
```

### 方式二：手动配置

详见：[完整配置步骤](#完整配置步骤)

---

## 前置要求

1. **WSL2 环境**：`wsl -l -v` 显示版本为 2
2. **代理软件**：Clash Verge、v2rayN 等，已开启 **Allow LAN**
3. **Windows 防火墙**：允许代理软件入站连接

---

## 常用命令

```bash
proxy_on        # 开启代理
proxy_off       # 关闭代理
proxy_status    # 查看代理状态（带连通性测试）
```

---

## 验证测试

```bash
# HTTP 代理测试
curl -I https://www.google.com

# SSH 连接测试
ssh -T git@github.com
# 预期输出：Permission denied (publickey) 表示网络畅通

# 查看代理 IP
curl ip.sb
```

---

## 故障排查

### 连接超时 / Connection refused

1. 检查代理软件是否开启 **Allow LAN**
2. 检查 Windows 防火墙是否拦截
3. 运行诊断工具：
   ```bash
   bash ~/projects/wsl2-proxy-md/check-proxy.sh
   ```

### SSH 报错 `nc: invalid option -- 'X'`

```bash
sudo apt remove netcat-traditional -y
sudo apt install netcat-openbsd -y
```

### 其他问题

详见：[详细故障排查](#故障排查-1)

---

## 完整配置步骤

<details>
<summary>点击展开手动配置详情</summary>

### 步骤 1：配置 Shell 代理脚本

编辑 `~/.bashrc`，在末尾添加：

```bash
# 宿主机 IP（替换为实际 IP）
export WSL2_HOSTIP=172.19.160.1
export WSL2_PROXY_PORT=41857

proxy_on() {
    export http_proxy="http://${WSL2_HOSTIP}:${WSL2_PROXY_PORT}"
    export https_proxy="http://${WSL2_HOSTIP}:${WSL2_PROXY_PORT}"
    export ALL_PROXY="socks5://${WSL2_HOSTIP}:${WSL2_PROXY_PORT}"
    git config --global http.proxy "http://${WSL2_HOSTIP}:${WSL2_PROXY_PORT}"
    git config --global https.proxy "http://${WSL2_HOSTIP}:${WSL2_PROXY_PORT}"
    echo "✓ Proxy enabled"
}

proxy_off() {
    unset http_proxy https_proxy ALL_PROXY
    git config --global --unset http.proxy 2>/dev/null
    git config --global --unset https.proxy 2>/dev/null
    echo "✗ Proxy disabled"
}

proxy_status() {
    if [ -n "$http_proxy" ]; then
        echo "✓ Proxy: $http_proxy"
        curl -s --connect-timeout 3 -I https://www.google.com >/dev/null 2>&1 && echo "  Google: ✓" || echo "  Google: ✗"
    else
        echo "✗ No proxy"
    fi
}
```

### 步骤 2：配置 SSH 代理转发

```bash
sudo apt install netcat-openbsd -y
nano ~/.ssh/config
```

添加配置：

```ssh-config
Host github.com
    User git
    ProxyCommand nc -X 5 -x 172.19.160.1:41857 %h %p
```

### 步骤 3：使配置生效

```bash
source ~/.bashrc
proxy_on
```

</details>

---

## 故障排查

### 1. 端口连接测试

```bash
# 测试宿主机代理端口
timeout 2 bash -c 'echo > /dev/tcp/172.19.160.1/41857' && echo "可达" || echo "不可达"
```

### 2. 检查 Windows 防火墙

在 Windows PowerShell（管理员）执行：

```powershell
# 临时关闭防火墙测试
Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled False

# 或添加允许规则
New-NetFirewallRule -DisplayName "Allow Proxy" -Direction Inbound -LocalPort 41857 -Protocol TCP -Action Allow
```

### 3. 查看代理监听状态

在 Windows 执行：

```powershell
netstat -ano | findstr 41857
```

应看到 `0.0.0.0:41857` 或 `:::41857`，而不是仅 `127.0.0.1:41857`

---

## 卸载恢复

```bash
# 删除 .bashrc 中的代理配置
nano ~/.bashrc
# 删除 WSL2_HOSTIP、proxy_on、proxy_off、proxy_status 相关行

# 删除 SSH 代理配置
nano ~/.ssh/config
# 删除 ProxyCommand 相关行

# 清除环境变量
unset http_proxy https_proxy ALL_PROXY

# 清除 Git 代理
git config --global --unset http.proxy
git config --global --unset https.proxy
```

---

## 工具脚本

| 脚本 | 用途 |
|------|------|
| `setup-wsl2-proxy.sh` | 自动化配置代理环境 |
| `check-proxy.sh` | 诊断网络连接问题 |

---

**备注**：代理排除规则请在宿主机的代理软件（如 Clash Verge）中配置，无需在 WSL2 中设置。
