# Simple update script - directly pass script content via SSM

$INSTANCE_ID = "i-0b3b312b21a19f71b"
$REGION = "ap-northeast-1"

Write-Host "=== Updating auto-shutdown script on EC2 instance ===" -ForegroundColor Cyan
Write-Host "Instance ID: $INSTANCE_ID" -ForegroundColor Yellow
Write-Host "Region: $REGION" -ForegroundColor Yellow
Write-Host ""

# Read the new auto-shutdown script
$newScript = Get-Content -Path "auto-shutdown.sh" -Raw

# Create inline update command (simpler approach)
$cmd1 = "systemctl stop minecraft-autoshutdown.service"
$cmd2 = "cp /usr/local/bin/minecraft-autoshutdown.sh /usr/local/bin/minecraft-autoshutdown.sh.backup.`$(date +%Y%m%d-%H%M%S)"
$cmd3 = "cat > /usr/local/bin/minecraft-autoshutdown.sh << 'AUTOSHUTDOWN_EOF'`n$newScript`nAUTOSHUTDOWN_EOF"
$cmd4 = "chmod +x /usr/local/bin/minecraft-autoshutdown.sh"
$cmd5 = "systemctl start minecraft-autoshutdown.service"
$cmd6 = "sleep 2"
$cmd7 = "systemctl status minecraft-autoshutdown.service --no-pager || true"
$cmd8 = "echo '=== Recent Logs ==='"
$cmd9 = "tail -n 30 /var/log/minecraft-autoshutdown.log || echo 'Log not found'"

Write-Host "Sending SSM command..." -ForegroundColor Yellow

# Send command
$result = aws ssm send-command `
    --instance-ids $INSTANCE_ID `
    --region $REGION `
    --document-name "AWS-RunShellScript" `
    --comment "Update auto-shutdown script" `
    --parameters "commands=[$cmd1,$cmd2,$cmd3,$cmd4,$cmd5,$cmd6,$cmd7,$cmd8,$cmd9]" `
    --output json

if ($LASTEXITCODE -ne 0) {
    Write-Host "Failed to send SSM command!" -ForegroundColor Red
    Write-Host "Error output:" -ForegroundColor Red
    Write-Host $result
    exit 1
}

$resultObj = $result | ConvertFrom-Json
$commandId = $resultObj.Command.CommandId

Write-Host "Command sent successfully!" -ForegroundColor Green
Write-Host "Command ID: $commandId" -ForegroundColor Cyan
Write-Host ""
Write-Host "Waiting 10 seconds for execution..." -ForegroundColor Yellow
Start-Sleep -Seconds 10

# Get output
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
Write-Host "Key improvements:" -ForegroundColor Cyan
Write-Host "  ✓ Config changes detected within 5 minutes" -ForegroundColor White
Write-Host "  ✓ No server restart needed for config updates" -ForegroundColor White
Write-Host "  ✓ Notifications to server-status channel" -ForegroundColor White
