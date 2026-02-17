# Auto-shutdown script update for Discord notification fix
# EC2インスタンスにSSM経由でスクリプトをアップロード

$INSTANCE_ID = "i-0b3b312b21a19f71b"
$REGION = "ap-northeast-1"
$SCRIPT_PATH = "./auto-shutdown.sh"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Auto-shutdown script update (Discord notification fix)" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# 1. EC2の状態を確認
Write-Host "[1/4] EC2インスタンスの状態を確認中..." -ForegroundColor Yellow
$state = aws ec2 describe-instances --instance-ids $INSTANCE_ID --region $REGION --query 'Reservations[0].Instances[0].State.Name' --output text

if ($state -ne "running") {
    Write-Host "エラー: EC2インスタンスが起動していません (状態: $state)" -ForegroundColor Red
    Write-Host "先にサーバーを起動してください: /start" -ForegroundColor Yellow
    exit 1
}

Write-Host "✓ EC2インスタンスは起動中です" -ForegroundColor Green
Write-Host ""

# 2. スクリプトファイルの存在確認
Write-Host "[2/4] スクリプトファイルの確認中..." -ForegroundColor Yellow
if (-not (Test-Path $SCRIPT_PATH)) {
    Write-Host "エラー: $SCRIPT_PATH が見つかりません" -ForegroundColor Red
    exit 1
}

Write-Host "✓ スクリプトファイルを確認しました" -ForegroundColor Green
Write-Host ""

# 3. スクリプトをEC2にアップロード
Write-Host "[3/4] スクリプトをEC2にアップロード中..." -ForegroundColor Yellow

# スクリプト内容を読み込み
$scriptContent = Get-Content $SCRIPT_PATH -Raw

# Base64エンコード（改行を保持）
$bytes = [System.Text.Encoding]::UTF8.GetBytes($scriptContent)
$base64 = [Convert]::ToBase64String($bytes)

# SSM経由でスクリプトをアップロード
$uploadCommand = @"
echo '$base64' | base64 -d > /tmp/auto-shutdown-new.sh && \
chmod +x /tmp/auto-shutdown-new.sh && \
sudo mv /tmp/auto-shutdown-new.sh /usr/local/bin/auto-shutdown.sh && \
echo 'Script uploaded successfully'
"@

$result = aws ssm send-command `
    --instance-ids $INSTANCE_ID `
    --region $REGION `
    --document-name "AWS-RunShellScript" `
    --parameters "commands=[$uploadCommand]" `
    --output json | ConvertFrom-Json

$commandId = $result.Command.CommandId

Write-Host "コマンドID: $commandId" -ForegroundColor Cyan

# コマンド実行完了を待つ
Write-Host "コマンド実行を待機中..." -ForegroundColor Yellow
Start-Sleep -Seconds 5

for ($i = 0; $i -lt 10; $i++) {
    $commandResult = aws ssm get-command-invocation `
        --command-id $commandId `
        --instance-id $INSTANCE_ID `
        --region $REGION `
        --output json 2>$null | ConvertFrom-Json
    
    if ($commandResult.Status -eq "Success") {
        Write-Host "✓ スクリプトのアップロードが完了しました" -ForegroundColor Green
        Write-Host ""
        Write-Host "出力:" -ForegroundColor Cyan
        Write-Host $commandResult.StandardOutputContent
        break
    } elseif ($commandResult.Status -eq "Failed") {
        Write-Host "エラー: スクリプトのアップロードに失敗しました" -ForegroundColor Red
        Write-Host $commandResult.StandardErrorContent
        exit 1
    }
    
    Start-Sleep -Seconds 2
}

# 4. サービスを再起動
Write-Host "[4/4] auto-shutdown サービスを再起動中..." -ForegroundColor Yellow

$restartCommand = "sudo systemctl restart minecraft-autoshutdown.service && echo 'Service restarted'"

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
    Write-Host "✓ サービスの再起動が完了しました" -ForegroundColor Green
} else {
    Write-Host "警告: サービスの再起動に失敗した可能性があります" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "✅ 更新完了！" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "自動停止通知が server-status チャンネルに送信されるようになりました" -ForegroundColor Green
