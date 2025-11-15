#!/bin/bash
set -euo pipefail

echo "🚀 Запуск wg-easy v15 (NL, IPv6 ULA)..."

# ------------------------------
# 1. Удаляем старый контейнер
# ------------------------------
docker rm -f wg-easy 2>/dev/null || true

# ------------------------------
# 2. Удаляем старую сеть wg
# ------------------------------
docker network rm wg 2>/dev/null || true

# ------------------------------
# 3. Создаём сеть Docker с IPv6
# ------------------------------
docker network create \
  -d bridge \
  --ipv6 \
  --opt com.docker.network.bridge.name=wg \
  wg || true

# ------------------------------
# 4. Миграция старых конфигов
# ------------------------------
rm -f ~/.wg-easy/wg*.conf 2>/dev/null || true

# ------------------------------
# 5. NAT + forwarding
# ------------------------------
EXT_IFACE=$(ip route get 8.8.8.8 | awk 'NR==1 {print $5}')
WG_SUBNET="10.42.42.0/24"
WG_SUBNET6="fdcc:ad94:bacf:61a3::/64"

# IPv4 NAT
sudo iptables -t nat -C POSTROUTING -s $WG_SUBNET -o "$EXT_IFACE" -j MASQUERADE 2>/dev/null || \
sudo iptables -t nat -A POSTROUTING -s $WG_SUBNET -o "$EXT_IFACE" -j MASQUERADE

# IPv6 NAT
sudo ip6tables -t nat -C POSTROUTING -s $WG_SUBNET6 -o "$EXT_IFACE" -j MASQUERADE 2>/dev/null || \
sudo ip6tables -t nat -A POSTROUTING -s $WG_SUBNET6 -o "$EXT_IFACE" -j MASQUERADE

# Включаем форвардинг
sudo sysctl -w net.ipv4.ip_forward=1
sudo sysctl -w net.ipv6.conf.all.forwarding=1

# ------------------------------
# 6. Запуск контейнера wg-easy
# ------------------------------
WG_HOST=$(curl -s ifconfig.co)

docker run -d \
  --name wg-easy \
  --net wg \
  --ip 10.42.42.42 \
  --ip6 fdcc:ad94:bacf:61a3::2a \
  -e INSECURE=true \
  -e LANG=ru_RU.UTF-8 \
  -e WG_HOST=$WG_HOST \
  -e PASSWORD=admin123 \
  -v ~/.wg-easy:/etc/wireguard \
  -v /lib/modules:/lib/modules:ro \
  -p 51820:51820/udp \
  -p 51821:51821/tcp \
  --cap-add NET_ADMIN \
  --cap-add SYS_MODULE \
  --sysctl net.ipv4.ip_forward=1 \
  --sysctl net.ipv4.conf.all.src_valid_mark=1 \
  --sysctl net.ipv6.conf.all.disable_ipv6=0 \
  --sysctl net.ipv6.conf.all.forwarding=1 \
  --sysctl net.ipv6.conf.default.forwarding=1 \
  --restart unless-stopped \
  ghcr.io/wg-easy/wg-easy:15

# ------------------------------
# 7. Вывод информации
# ------------------------------
echo "✅ wg-easy успешно запущен!"
echo "Web UI: http://$WG_HOST:51821"
echo "Логин: admin | Пароль: admin123"
