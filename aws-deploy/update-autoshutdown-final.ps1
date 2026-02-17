# Auto-shutdown script update - Final version with SSM config support
# EC2インスタンスにSSM経由でスクリプトをアップロード

$INSTANCE_ID = "i-0b3b312b21a19f71b"
$REGION = "ap-northeast-1"
$SCRIPT_PATH = "./auto-shutdown.sh"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Auto-shutdown script update (Final)" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# 1. EC2の状態を確認
Write-Host "[1/5] Checking EC2 instance state..." -ForegroundColor Yellow
$state = aws ec2 describe-instances --instance-ids $INSTANCE_ID --region $REGION --query 'Reservations[0].Instances[0].State.Name' --output text

if ($state -ne "running") {
    Write-Host "Error: EC2 instance is not running (state: $state)" -ForegroundColor Red
    Write-Host "Please start the server first: /start" -ForegroundColor Yellow
    exit 1
}

Write-Host "OK: EC2 instance is running" -ForegroundColor Green
Write-Host ""

# 2. SSM Parameter Storeの値を確認
Write-Host "[2/5] Checking SSM Parameter Store..." -ForegroundColor Yellow
$idleTime = aws ssm get-parameter --name "/minecraft/$INSTANCE_ID/idle_time" --region $REGION --query 'Parameter.Value' --output text 2>$null

if ($idleTime) {
    $minutes = [math]::Floor($idleTime / 60)
    Write-Host "OK: Current setting: $minutes minutes ($idleTime seconds)" -ForegroundColor Green
} else {
    Write-Host "Warning: No setting found in SSM Parameter Store (default: 15 minutes)" -ForegroundColor Yellow
}
Write-Host ""

# 3. スクリプトファイルの存在確認
Write-Host "[3/5] Checking script file..." -ForegroundColor Yellow
if (-not (Test-Path $SCRIPT_PATH)) {
    Write-Host "Error: $SCRIPT_PATH not found" -ForegroundColor Red
    exit 1
}

Write-Host "OK: Script file found" -ForegroundColor Green
Write-Host ""

# 4. スクリプトをEC2にアップロード
Write-Host "[4/5] Uploading script to EC2..." -ForegroundColor Yellow

# スクリプト内容を読み込み
$scriptContent = Get-Content $SCRIPT_PATH -Raw

# Base64エンコード（改行を保持）
$bytes = [System.Text.Encoding]::UTF8.GetBytes($scriptContent)
$base64 = [Convert]::ToBase64String($bytes)

# SSM経由でスクリプトをアップロード
$uploadCommand = @"
echo '$base64' | base64 -d > /tmp/auto-shutdown-new.sh && \
chmod +x /tmp/auto-shutdown-new.sh && \
sudo cp /tmp/auto-shutdown-new.sh /usr/local/bin/auto-shutdown.sh && \
sudo cp /tmp/auto-shutdown-new.sh /usr/local/bin/minecraft-autoshutdown.sh && \
echo 'Script uploaded successfully'
"@

$result = aws ssm send-command `
    --instance-ids $INSTANCE_ID `
    --region $REGION `
    --document-name "AWS-RunShellScript" `
    --parameters "commands=[$uploadCommand]" `
    --output json | ConvertFrom-Json

$commandId = $result.Command.CommandId

Write-Host "Command ID: $commandId" -ForegroundColor Cyan

# コマンド実行完了を待つ
Write-Host "Waiting for command execution..." -ForegroundColor Yellow
Start-Sleep -Seconds 5

for ($i = 0; $i -lt 10; $i++) {
    $commandResult = aws ssm get-command-invocation `
        --command-id $commandId `
        --instance-id $INSTANCE_ID `
        --region $REGION `
        --output json 2>$null | ConvertFrom-Json
    
    if ($commandResult.Status -eq "Success") {
        Write-Host "OK: Script upload completed" -ForegroundColor Green
        Write-Host ""
        Write-Host "Output:" -ForegroundColor Cyan
        Write-Host $commandResult.StandardOutputContent
        break
    } elseif ($commandResult.Status -eq "Failed") {
        Write-Host "Error: Script upload failed" -ForegroundColor Red
        Write-Host $commandResult.StandardErrorContent
        exit 1
    }
    
    Start-Sleep -Seconds 2
}

# 5. サービスを再起動
Write-Host "[5/5] Restarting auto-shutdown service..." -ForegroundColor Yellow

$restartCommand = "sudo systemctl restart minecraft-autoshutdown.service && echo 'Service restarted' && sudo systemctl status minecraft-autoshutdown.service --no-pager"

$result2 = aws ssm send-command `
    --instance-ids $INSTANCE_ID `
    --region $REGION `
    --document-name "AWS-RunShellScript" `
    --parameters "commands=[$restartCommand]" `
    --output json | ConvertFrom-Json

$commandId2 = $result2.Command.CommandId

Start-Sleep -Seconds 3

$commandResult2 = aws ssm get-command-invocation `
    --command-id $commandId2 `
    --instance-id $INSTANCE_ID `
    --region $REGION `
    --output json 2>$null | ConvertFrom-Json

if ($commandResult2.Status -eq "Success") {
    Write-Host "OK: Service restart completed" -ForegroundColor Green
    Write-Host ""
    Write-Host "Service status:" -ForegroundColor Cyan
    Write-Host $commandResult2.StandardOutputContent
} else {
    Write-Host "Warning: Service restart may have failed" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Update completed!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

if ($idleTime) {
    $minutes = [math]::Floor($idleTime / 60)
    Write-Host "Current auto-shutdown setting: $minutes minutes" -ForegroundColor Green
    Write-Host "Setting will be applied within 1 minute" -ForegroundColor Green
} else {
    Write-Host "To change auto-shutdown setting: /config idle_time:<minutes>" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Check logs: sudo tail -f /var/log/minecraft-autoshutdown.log" -ForegroundColor Cyan
