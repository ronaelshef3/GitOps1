FROM jrei/systemd-ubuntu:22.04

# התקנת כלים בסיסיים שקיימים ב-Image של AWS
RUN apt-get update && apt-get install -y \
    openssh-server sudo curl ca-certificates net-tools iproute2 \
    && rm -rf /var/lib/apt/lists/*

# יצירת משתמש ubuntu זהה ל-AWS
RUN useradd -m -s /bin/bash ubuntu && \
    echo 'ubuntu:ubuntu' | chpasswd && \
    adduser ubuntu sudo && \
    echo "ubuntu ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# הכנת תשתיות SSH
RUN mkdir -p /home/ubuntu/.ssh && chmod 700 /home/ubuntu/.ssh && chown ubuntu:ubuntu /home/ubuntu/.ssh

# הרצת המכונה עם Systemd כדי ש-K3s יוכל לרוץ כ-Service
CMD ["/lib/systemd/systemd"]