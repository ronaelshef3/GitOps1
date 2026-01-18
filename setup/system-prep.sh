#!/bin/bash
set -e

echo "--- Starting System Prep (Docker-Aware) ---"

# 1. ניהול Swap - רק ב-AWS (כי בדוקר אין הרשאות Kernel)
if [ -f /.dockerenv ]; then
    echo "✔ Running in Docker - Using Host RAM (8GB reserved)"
else
    echo "☁ Running in AWS - Creating 2GB Swap file..."
    if [ ! -f /swapfile ]; then
        sudo fallocate -l 2G /swapfile
        sudo chmod 600 /swapfile
        sudo mkswap /swapfile
        sudo swapon /swapfile
        echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
    fi
fi

# 2. התקנת K3s - תואם ל-User Data בטרהפורם שלך
echo "Installing K3s (No Traefik)..."
curl -sfL https://get.k3s.io | sh -s - server \
    --write-kubeconfig-mode 644 \
    --disable traefik

# 3. וידוא שירות K3s למעלה
echo "Waiting for K3s to initialize..."
for i in {1..12}; do
    if sudo kubectl get nodes | grep -q "Ready"; then
        echo "✔ K3s is Ready!"
        break
    fi
    echo "Still waiting... ($i/12)"
    sleep 10
done