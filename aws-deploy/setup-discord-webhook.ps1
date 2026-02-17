# Setup Discord Webhook URL in SSM Parameter Store

$INSTANCE_ID = "i-0b3b312b21a19f71b"
$REGION = "ap-northeast-1"

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "Discord Webhook URL Setup" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "Steps:" -ForegroundColor Yellow
Write-Host "1. Open 'server-status' channel in Discord"
Write-Host "2. Channel Settings -> Integrations -> Webhooks"
Write-Host "3. Click 'New Webhook'"
Write-Host "4. Change name to 'Minecraft Auto-Shutdown'"
Write-Host "5. Click 'Copy Webhook URL'"
Write-Host ""

$WEBHOOK_URL = Read-Host "Paste Webhook URL here"

if ([string]::IsNullOrWhiteSpace($WEBHOOK_URL)) {
    Write-Host "Error: Webhook URL is empty" -ForegroundColor Red
    exit 1
}

# Validate Webhook URL format
if ($WEBHOOK_URL -notmatch "^https://discord.com/api/webhooks/") {
    Write-Host "Warning: Webhook URL format may be incorrect" -ForegroundColor Yellow
    Write-Host "Correct format: https://discord.com/api/webhooks/..." -ForegroundColor Yellow
    $continue = Read-Host "Continue anyway? (y/n)"
    if ($continue -ne "y") {
        Write-Host "Cancelled" -ForegroundColor Yellow
        exit 0
    }
}

Write-Host ""
Write-Host "Saving to SSM Parameter Store..." -ForegroundColor Cyan

try {
    # Save to SSM Parameter Store
    aws ssm put-parameter `
        --name "/minecraft/$INSTANCE_ID/discord_webhook" `
        --value "$WEBHOOK_URL" `
        --type "SecureString" `
        --region $REGION `
        --overwrite
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Success: Webhook URL saved" -ForegroundColor Green
        Write-Host ""
        Write-Host "Next steps:" -ForegroundColor Yellow
        Write-Host "1. Upload auto-shutdown.sh to EC2"
        Write-Host "2. Restart the service"
        Write-Host ""
        Write-Host "Run command:" -ForegroundColor Cyan
        Write-Host "  .\update-autoshutdown-webhook.ps1" -ForegroundColor White
    } else {
        Write-Host "Error: Failed to save Webhook URL" -ForegroundColor Red
    }
} catch {
    Write-Host "Error: $_" -ForegroundColor Red
    exit 1
}
