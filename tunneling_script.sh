#!/bin/bash

# Warna
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# Periksa izin IP sebelum instalasi
echo -e "${GREEN}Memeriksa izin IP...${NC}"
ALLOWED_IPS=("123.456.789.000" "111.222.333.444")  # Tambahkan IP yang diizinkan di sini
CURRENT_IP=$(curl -s https://api.ipify.org)

if [[ " ${ALLOWED_IPS[@]} " =~ " ${CURRENT_IP} " ]]; then
    echo -e "${GREEN}IP diizinkan: ${CURRENT_IP}${NC}"
else
    echo -e "${RED}IP ${CURRENT_IP} tidak diizinkan. Instalasi dibatalkan.${NC}"
    exit 1
fi

# Memperbarui sistem
echo -e "${GREEN}Memperbarui sistem...${NC}"
apt update && apt upgrade -y

# Instalasi SSH, SSL, dan WebSocket
echo -e "${GREEN}Menginstal SSH, SSL, dan WebSocket...${NC}"
apt install -y openssh-server stunnel4
systemctl enable ssh
systemctl start ssh

# Konfigurasi Stunnel (SSL)
cat > /etc/stunnel/stunnel.conf <<EOF
cert = /etc/stunnel/stunnel.pem
key = /etc/stunnel/stunnel.pem
client = no
[ssh]
accept = 443
connect = 22
EOF

# Membuat sertifikat SSL
openssl req -new -x509 -days 365 -nodes -out /etc/stunnel/stunnel.pem -keyout /etc/stunnel/stunnel.pem

systemctl enable stunnel4
systemctl restart stunnel4

# Konfigurasi WebSocket
apt install -y socat
cat > /etc/systemd/system/ws-ssh.service <<EOF
[Unit]
Description=SSH over WebSocket
After=network.target

[Service]
ExecStart=/usr/bin/socat TCP-LISTEN:8880,reuseaddr,fork TCP:127.0.0.1:22
Restart=always

[Install]
WantedBy=multi-user.target
EOF

systemctl enable ws-ssh
systemctl start ws-ssh

# Instalasi Xray/V2Ray untuk VMess, VLESS, Trojan (TLS, Non-TLS, gRPC)
echo -e "${GREEN}Menginstal Xray/V2Ray untuk VMess, VLESS, Trojan...${NC}"
bash <(curl -L https://raw.githubusercontent.com/XTLS/Xray-install/main/install-release.sh) install

# Konfigurasi VMess, VLESS, Trojan (TLS/Non-TLS/gRPC)
cat > /usr/local/etc/xray/config.json <<EOF
{
  "inbounds": [
    {
      "port": 443,
      "protocol": "vmess",
      "settings": {
        "clients": [
          {
            "id": "UUID-VMESS",
            "alterId": 0
          }
        ]
      },
      "streamSettings": {
        "network": "ws",
        "wsSettings": {
          "path": "/vmess"
        },
        "security": "tls",
        "tlsSettings": {
          "certificates": [
            {
              "certificateFile": "/path/to/fullchain.pem",
              "keyFile": "/path/to/privkey.pem"
            }
          ]
        }
      }
    },
    {
      "port": 80,
      "protocol": "vmess",
      "settings": {
        "clients": [
          {
            "id": "UUID-VMESS",
            "alterId": 0
          }
        ]
      },
      "streamSettings": {
        "network": "ws",
        "wsSettings": {
          "path": "/vmess"
        }
      }
    },
    {
      "port": 443,
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "UUID-VLESS",
            "flow": "xtls-rprx-direct"
          }
        ]
      },
      "streamSettings": {
        "network": "grpc",
        "grpcSettings": {
          "serviceName": "vless-grpc"
        },
        "security": "tls",
        "tlsSettings": {
          "certificates": [
            {
              "certificateFile": "/path/to/fullchain.pem",
              "keyFile": "/path/to/privkey.pem"
            }
          ]
        }
      }
    },
    {
      "port": 80,
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "UUID-VLESS"
          }
        ]
      },
      "streamSettings": {
        "network": "grpc",
        "grpcSettings": {
          "serviceName": "vless-grpc"
        }
      }
    },
    {
      "port": 443,
      "protocol": "trojan",
      "settings": {
        "clients": [
          {
            "password": "PASSWORD-TROJAN"
          }
        ]
      },
      "streamSettings": {
        "network": "grpc",
        "grpcSettings": {
          "serviceName": "trojan-grpc"
        },
        "security": "tls",
        "tlsSettings": {
          "certificates": [
            {
              "certificateFile": "/path/to/fullchain.pem",
              "keyFile": "/path/to/privkey.pem"
            }
          ]
        }
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom",
      "settings": {}
    }
  ]
}
EOF

# Restart Xray service
systemctl restart xray

echo -e "${GREEN}Sistem siap digunakan!${NC}"

# Tambahkan bagian untuk push ke GitHub
echo -e "${GREEN}Mengupload skrip ke GitHub...${NC}"

# Instal git jika belum ada
if ! [ -x "$(command -v git)" ]; then
  echo "Menginstal git..."
  apt install -y git
fi

# Clone repository Anda
git clone https://github.com/kiryusekei/Jay.git /opt/jay

# Salin skrip ke repository
cp $0 /opt/jay/install-script.sh

# Masuk ke direktori repository
cd /opt/jay

# Tambahkan perubahan, commit, dan push
git add install-script.sh
git commit -m "Menambahkan skrip instalasi tunneling"
git push origin main

echo -e "${GREEN}Skrip berhasil diupload ke GitHub Anda.${NC}"
