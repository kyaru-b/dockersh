#!/bin/bash
set -e

# Внешний интерфейс
EXT_IFACE=$(ip route get 8.8.8.8 | awk '{print $5; exit}')
WG_SUBNET="10.42.42.0/24"

# Настройка NAT через iptables (IPv4)
sudo iptables -t nat -C POSTROUTING -s $WG_SUBNET -o $EXT_IFACE -j MASQUERADE 2>/dev/null || \
sudo iptables -t nat -A POSTROUTING -s $WG_SUBNET -o $EXT_IFACE -j MASQUERADE

# Настройка NAT через ip6tables (IPv6)
sudo ip6tables -t nat -C POSTROUTING -s fdcc:ad94:bacf:61a3::/64 -o $EXT_IFACE -j MASQUERADE 2>/dev/null || \
sudo ip6tables -t nat -A POSTROUTING -s fdcc:ad94:bacf:61a3::/64 -o $EXT_IFACE -j MASQUERADE

# Запуск контейнера wg-easy
docker run -d \
  --net wg \
  -e INSECURE=true \
  --name wg-easy \
  --ip6 fdcc:ad94:bacf:61a3::2a \
  --ip 10.42.42.42 \
  -v ~/.wg-easy:/etc/wireguard \
  -v /lib/modules:/lib/modules:ro \
  -p 51820:51820/udp \
  -p 51821:51821/tcp \
  --cap-add NET_ADMIN \
  --cap-add SYS_MODULE \
  --sysctl net.ipv4.ip_forward=1 \
  --sysctl net.ipv6.conf.all.forwarding=1 \
  --restart unless-stopped \
  ghcr.io/wg-easy/wg-easy:15

echo "✅ wg-easy запущен!"
