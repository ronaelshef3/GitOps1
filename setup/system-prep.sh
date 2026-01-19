#!/bin/bash
set -e

echo "--- 🚀 Starting System Prep (Terraform-Integrated) ---"

# 1. ניהול Swap - חיוני ב-AWS כדי שה-K3s לא יקרוס מחוסר זיכרון
if [ -f /.dockerenv ]; then
    echo "✔ Running in Docker - Skipping Swap"
else
    echo "☁ Running in AWS - Creating 2GB Swap file..."
    if [ ! -f /swapfile ]; then
        sudo fallocate -l 2G /swapfile
        sudo chmod 600 /swapfile
        sudo mkswap /swapfile
        sudo swapon /swapfile
        echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
        echo "✔ Swap created successfully"
    else
        echo "✔ Swap already exists"
    fi
fi

# 2. וידוא התקנת K3s (שבוצעה ע"י הטרפורם)
echo "🔍 Checking K3s status..."
if command -v k3s &> /dev/null; then
    echo "✔ K3s is already installed (via Terraform User Data)"
else
    echo "⚠️ K3s not found! Installing now as fallback..."
    curl -sfL https://get.k3s.io | sh -s - server \
        --write-kubeconfig-mode 644 \
        --disable traefik
fi

# 3. הגדרת הרשאות ל-Kubeconfig
# זה קריטי כדי שתוכל להריץ kubectl בלי sudo בהמשך הסקריפטים
mkdir -p $HOME/.kube
sudo cp /etc/rancher/k3s/k3s.yaml $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
export KUBECONFIG=$HOME/.kube/config

# 4. וידוא שהקלאסטר "באמת" למעלה (Ready)
echo "⏳ Waiting for K3s nodes to be Ready..."
for i in {1..20}; do
    if kubectl get nodes | grep -q "Ready"; then
        echo "✅ K3s is Ready!"
        break
    fi
    echo "Still waiting... ($i/20)"
    sleep 5
done

# 5. הכנת תיקיות לאחסון (PVC לעתיד)
sudo mkdir -p /mnt/data
sudo chmod 777 /mnt/data

echo "--- ✨ System Prep Completed Successfully! ---"