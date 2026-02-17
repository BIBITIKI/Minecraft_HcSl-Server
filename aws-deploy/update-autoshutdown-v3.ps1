# Update auto-shutdown script on running EC2 instance via SSM
# Simplified version using JSON file

$INSTANCE_ID = "i-0b3b312b21a19f71b"
$REGION = "ap-northeast-1"

Write-Host "=== Updating auto-shutdown script on EC2 instance ===" -ForegroundColor Cyan
Write-Host "Instance ID: $INSTANCE_ID" -ForegroundColor Yellow
Write-Host "Region: $REGION" -ForegroundColor Yellow
Write-Host ""

# Read the new auto-shutdown script
$newScript = Get-Content -Path "auto-shutdown.sh" -Raw

# Create a temporary bash script that will update the auto-shutdown script
$updateScript = @"
#!/bin/bash
set -e

echo '=== Updating auto-shutdown script ==='

# Stop the service
echo 'Stopping minecraft-autoshutdown service...'
systemctl stop minecraft-autoshutdown.service

# Backup old script
echo 'Backing up old script...'
BACKUP_FILE="/usr/local/bin/minecraft-autoshutdown.sh.backup.`$(date +%Y%m%d-%H%M%S)"
cp /usr/local/bin/minecraft-autoshutdown.sh "`$BACKUP_FILE"
echo "Backup saved to: `$BACKUP_FILE"

# Write new script
echo 'Writing new script...'
cat > /usr/local/bin/minecraft-autoshutdown.sh << 'AUTOSHUTDOWN_SCRIPT_EOF'
$newScript
AUTOSHUTDOWN_SCRIPT_EOF

# Set permissions
echo 'Setting permissions...'
chmod +x /usr/local/bin/minecraft-autoshutdown.sh

# Restart service
echo 'Restarting minecraft-autoshutdown service...'
systemctl start minecraft-autoshutdown.service

# Wait a moment for service to start
sleep 2

# Check status
echo ''
echo '=== Service Status ==='
systemctl status minecraft-autoshutdown.service --no-pager || true

# Show recent logs
echo ''
echo '=== Recent Logs (last 30 lines) ==='
tail -n 30 /var/log/minecraft-autoshutdown.log || echo 'Log file not found yet'

echo ''
echo '=== Update Complete ==='
echo 'New features:'
echo '  - Reads IDLE_TIME from SSM Parameter Store'
echo '  - Checks for config changes every 5 minutes'
echo '  - Sends notifications to server-status channel via Discord Bot'
echo '  - Improved logging with instance ID and region'
"@

# Save to JSON file for AWS CLI (correct AWS SSM format)
$commandJson = @{
    InstanceIds = @($INSTANCE_ID)
    DocumentName = "AWS-RunShellScript"
    Comment = "Update auto-shutdown script with SSM config reload support"
    Parameters = @{
        commands = @($updateScript)
    }
} | ConvertTo-Json -Depth 10

# Write without BOM
[System.IO.File]::WriteAllText("$PWD\ssm-command.json", $commandJson, (New-Object System.Text.UTF8Encoding $false))

Write-Host "Sending SSM command..." -ForegroundColor Yellow

# Send command via AWS CLI using JSON file
$result = aws ssm send-command `
    --region $REGION `
    --cli-input-json "file://ssm-command.json" `
    --output json | ConvertFrom-Json

if ($LASTEXITCODE -ne 0) {
    Write-Host "Failed to send SSM command!" -ForegroundColor Red
    exit 1
}

$commandId = $result.Command.CommandId

Write-Host "Command sent successfully!" -ForegroundColor Green
Write-Host "Command ID: $commandId" -ForegroundColor Cyan
Write-Host ""
Write-Host "Waiting 10 seconds for command to execute..." -ForegroundColor Yellow
Start-Sleep -Seconds 10

# Get command output
Write-Host ""
Write-Host "=== Command Output ===" -ForegroundColor Cyan
$output = aws ssm get-command-invocation `
    --command-id $commandId `
    --instance-id $INSTANCE_ID `
    --region $REGION `
    --output json | ConvertFrom-Json

Write-Host $output.StandardOutputContent -ForegroundColor White

if ($output.StandardErrorContent) {
    Write-Host ""
    Write-Host "=== Errors ===" -ForegroundColor Red
    Write-Host $output.StandardErrorContent -ForegroundColor Red
}

Write-Host ""
Write-Host "=== Update Complete ===" -ForegroundColor Green
Write-Host "The auto-shutdown script has been updated on the EC2 instance." -ForegroundColor Green
Write-Host ""
Write-Host "Key improvements:" -ForegroundColor Cyan
Write-Host "  ✓ Config changes detected within 5 minutes" -ForegroundColor White
Write-Host "  ✓ No need to restart server for config updates" -ForegroundColor White
Write-Host "  ✓ Notifications sent to server-status channel" -ForegroundColor White
Write-Host "  ✓ Better logging with instance metadata" -ForegroundColor White

# Clean up
Remove-Item "ssm-command.json" -ErrorAction SilentlyContinue
