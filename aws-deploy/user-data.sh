#!/bin/bash
set -e

# Log output
exec > >(tee /var/log/user-data.log)
exec 2>&1

echo "=== Minecraft Server Setup Started ==="

# System update
dnf update -y

# Install Java 21 (for Minecraft 1.20.1)
dnf install -y java-21-amazon-corretto

# Install AWS CLI (already included in AL2023)
dnf install -y aws-cli

# Create Minecraft directory
mkdir -p /minecraft/server
cd /minecraft/server

# Create launch script
cat > /minecraft/launch.sh << 'EOF'
#!/bin/bash
cd /minecraft/server
java -Xmx$${minecraft_memory}M -Xms$${minecraft_memory}M -jar server.jar nogui
EOF

chmod +x /minecraft/launch.sh

# Create systemd service (for auto-start)
cat > /etc/systemd/system/minecraft.service << 'EOF'
[Unit]
Description=Minecraft Server
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/minecraft/server
ExecStart=/minecraft/launch.sh
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Create auto-shutdown script (copy from external file with webhook support)
cat > /usr/local/bin/minecraft-autoshutdown.sh << 'AUTOSHUTDOWN'
${auto_shutdown_script}
AUTOSHUTDOWN

chmod +x /usr/local/bin/minecraft-autoshutdown.sh

# Create auto-shutdown service with Discord webhook
cat > /etc/systemd/system/minecraft-autoshutdown.service << 'EOF'
[Unit]
Description=Minecraft Auto Shutdown Monitor
After=minecraft.service

[Service]
Type=simple
Environment="DISCORD_WEBHOOK_URL=${discord_webhook_url}"
ExecStart=/usr/local/bin/minecraft-autoshutdown.sh
Restart=always

[Install]
WantedBy=multi-user.target
EOF

# Enable services
systemctl daemon-reload
systemctl enable minecraft.service
systemctl enable minecraft-autoshutdown.service

echo "=== Minecraft Server Setup Completed ==="
