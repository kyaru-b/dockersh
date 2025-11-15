#!/bin/bash
set -euo pipefail

echo "Запуск wg-easy (WireGuard + Web UI)..."

# === 1. Определяем внешний интерфейс ===
EXT_IFACE=$(ip route get 8.8.8.8 | awk 'NR==1 {print $5}' | head -n1)
if [[ -z "$EXT_IFACE" ]]; then
  echo "Ошибка: Не удалось определить внешний интерфейс!"
  exit 1
fi
echo "Внешний интерфейс: $EXT_IFACE"

# === 2. Подсети ===
WG_SUBNET_V4="10.42.42.0/24"
WG_SUBNET_V6="fdcc:ad94:bacf:61a3::/64"

# === 3. Включаем IP forwarding (на всякий случай) ===
echo "Включаем IP forwarding..."
sudo sysctl -w net.ipv4.ip_forward=1 > /dev/null
sudo sysctl -w net.ipv6.conf.all.forwarding=1 > /dev/null

# === 4. Настройка NAT (IPv4) ===
echo "Настройка NAT (IPv4)..."
sudo iptables -t nat -C POSTROUTING -s $WG_SUBNET_V4 -o "$EXT_IFACE" -j MASQUERADE 2>/dev/null || \
sudo iptables -t nat -A POSTROUTING -s $WG_SUBNET_V4 -o "$EXT_IFACE" -j MASQUERADE

# === 5. Настройка NAT (IPv6) ===
echo "Настройка NAT (IPv6)..."
sudo ip6tables -t nat -C POSTROUTING -s $WG_SUBNET_V6 -o "$EXT_IFACE" -j MASQUERADE 2>/dev/null || \
sudo ip6tables -t nat -A POSTROUTING -s $WG_SUBNET_V6 -o "$EXT_IFACE" -j MASQUERADE

# === 6. Создаём Docker-сеть, если её нет ===
echo "Создаём Docker-сеть 'wg'..."
docker network create wg 2>/dev/null || true

# === 7. Удаляем старый контейнер (если есть) ===
echo "Удаляем старый контейнер 'wg-easy'..."
docker rm -f wg-easy 2>/dev/null || true

# === 8. Запускаем wg-easy ===
echo "Запускаем контейнер wg-easy..."

docker run -d \
  --name wg-easy \
  --network wg \
  --ip 10.42.42.42 \
  --ip6 fdcc:ad94:bacf:61a3::2a \
  -e LANG=ru_RU.UTF-8 \
  -e WG_HOST=$(curl -s ifconfig.co) \
  -e PASSWORD=admin123 \
  -e INSECURE=true \
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

# === 9. Готово! ===
echo ""
echo "wg-easy успешно запущен!"
echo ""
echo "Web UI: http://$(curl -s ifconfig.co):51821"
echo "Логин: admin"
echo "Пароль: admin123 (смените после входа!)"
echo ""
echo "Клиент: скачайте конфиг в веб-интерфейсе"
echo ""
echo "Примечание: Если IPv6 не работает — проверьте, включён ли он на хосте."