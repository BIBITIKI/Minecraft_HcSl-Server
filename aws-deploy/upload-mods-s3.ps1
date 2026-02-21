# MODファイルをS3経由でEC2にアップロードするスクリプト
# 使い方: .\upload-mods-s3.ps1

param(
    [string]$InstanceId = "i-0b3b312b21a19f71b",
    [string]$Region = "ap-northeast-1",
    [string]$ModsFolder = "..\mods",
    [string]$S3Bucket = "minecraft-mods-temp-$(Get-Random)"
)

Write-Host "=== Minecraft MODアップロードスクリプト (S3経由) ===" -ForegroundColor Cyan
Write-Host ""

# MODフォルダの存在確認
if (-not (Test-Path $ModsFolder)) {
    Write-Host "エラー: MODフォルダが見つかりません: $ModsFolder" -ForegroundColor Red
    exit 1
}

# MODファイル一覧を取得
$modFiles = Get-ChildItem -Path $ModsFolder -Filter "*.jar"

if ($modFiles.Count -eq 0) {
    Write-Host "エラー: MODファイル(.jar)が見つかりません" -ForegroundColor Red
    exit 1
}

Write-Host "アップロード対象のMODファイル: $($modFiles.Count)個" -ForegroundColor Green
$totalSize = 0
foreach ($mod in $modFiles) {
    $sizeMB = [Math]::Round($mod.Length / 1MB, 2)
    $totalSize += $sizeMB
    Write-Host "  - $($mod.Name) (${sizeMB} MB)" -ForegroundColor Gray
}
Write-Host "合計サイズ: $totalSize MB" -ForegroundColor Cyan
Write-Host ""

# EC2インスタンスの状態確認
Write-Host "EC2インスタンスの状態を確認中..." -ForegroundColor Yellow
$instanceState = aws ec2 describe-instances --instance-ids $InstanceId --region $Region --query "Reservations[0].Instances[0].State.Name" --output text

if ($instanceState -ne "running") {
    Write-Host "エラー: EC2インスタンスが起動していません (状態: $instanceState)" -ForegroundColor Red
    Write-Host "先にサーバーを起動してください" -ForegroundColor Yellow
    exit 1
}

Write-Host "EC2インスタンスは起動中です" -ForegroundColor Green
Write-Host ""

# S3バケットを作成
Write-Host "一時的なS3バケットを作成中: $S3Bucket" -ForegroundColor Yellow
aws s3 mb s3://$S3Bucket --region $Region 2>$null

if ($LASTEXITCODE -ne 0) {
    Write-Host "エラー: S3バケットの作成に失敗しました" -ForegroundColor Red
    Write-Host "別のバケット名を試すか、既存のバケットを指定してください" -ForegroundColor Yellow
    exit 1
}

Write-Host "S3バケットを作成しました" -ForegroundColor Green
Write-Host ""

try {
    # MODファイルをS3にアップロード
    Write-Host "MODファイルをS3にアップロード中..." -ForegroundColor Yellow
    aws s3 sync $ModsFolder s3://$S3Bucket/mods/ --region $Region --exclude "*" --include "*.jar"
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "エラー: S3へのアップロードに失敗しました" -ForegroundColor Red
        exit 1
    }
    
    Write-Host "S3へのアップロード完了" -ForegroundColor Green
    Write-Host ""

    # EC2でMinecraftサーバーを停止
    Write-Host "Minecraftサーバーを停止中..." -ForegroundColor Yellow
    $stopCommand = "sudo systemctl stop minecraft"
    
    $stopCmdId = aws ssm send-command `
        --instance-ids $InstanceId `
        --region $Region `
        --document-name "AWS-RunShellScript" `
        --parameters commands="$stopCommand" `
        --query "Command.CommandId" `
        --output text
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "エラー: 停止コマンドの送信に失敗しました" -ForegroundColor Red
        exit 1
    }
    
    Start-Sleep -Seconds 5
    Write-Host "サーバーを停止しました" -ForegroundColor Green
    Write-Host ""

    # EC2でS3からMODファイルをダウンロード
    Write-Host "EC2でMODファイルをダウンロード中..." -ForegroundColor Yellow
    
    $downloadCommand = @"
cd /home/ubuntu/minecraft
mkdir -p mods_backup
if [ -d mods ] && [ `"`$(ls -A mods 2>/dev/null)`" ]; then
    mv mods/*.jar mods_backup/ 2>/dev/null || true
fi
aws s3 sync s3://$S3Bucket/mods/ mods/ --region $Region
sudo chown -R ubuntu:ubuntu mods
echo 'MOD download completed'
"@
    
    $downloadCmdId = aws ssm send-command `
        --instance-ids $InstanceId `
        --region $Region `
        --document-name "AWS-RunShellScript" `
        --parameters commands="$downloadCommand" `
        --query "Command.CommandId" `
        --output text
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "エラー: ダウンロードコマンドの送信に失敗しました" -ForegroundColor Red
        exit 1
    }
    
    # コマンド完了を待機
    Write-Host "ダウンロード完了を待機中..." -ForegroundColor Gray
    $maxAttempts = 30
    $attempt = 0
    $downloadSuccess = $false
    
    while ($attempt -lt $maxAttempts) {
        $attempt++
        Start-Sleep -Seconds 2
        
        $status = aws ssm get-command-invocation `
            --command-id $downloadCmdId `
            --instance-id $InstanceId `
            --region $Region `
            --query "Status" `
            --output text 2>$null
        
        if ($status -eq "Success") {
            $downloadSuccess = $true
            break
        } elseif ($status -eq "Failed" -or $status -eq "Cancelled" -or $status -eq "TimedOut") {
            Write-Host "エラー: ダウンロードが失敗しました (Status: $status)" -ForegroundColor Red
            
            $errorOutput = aws ssm get-command-invocation `
                --command-id $downloadCmdId `
                --instance-id $InstanceId `
                --region $Region `
                --query "StandardErrorContent" `
                --output text 2>$null
            
            if ($errorOutput) {
                Write-Host "エラー詳細: $errorOutput" -ForegroundColor Red
            }
            exit 1
        }
        
        if ($attempt % 5 -eq 0) {
            Write-Host "  待機中... ($attempt/$maxAttempts)" -ForegroundColor Gray
        }
    }
    
    if (-not $downloadSuccess) {
        Write-Host "タイムアウト: ダウンロードが完了しませんでした" -ForegroundColor Red
        exit 1
    }
    
    Write-Host "MODファイルのダウンロード完了" -ForegroundColor Green
    Write-Host ""

    # Minecraftサーバーを起動
    Write-Host "Minecraftサーバーを起動中..." -ForegroundColor Yellow
    $startCommand = "sudo systemctl start minecraft"
    
    $startCmdId = aws ssm send-command `
        --instance-ids $InstanceId `
        --region $Region `
        --document-name "AWS-RunShellScript" `
        --parameters commands="$startCommand" `
        --query "Command.CommandId" `
        --output text
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "エラー: 起動コマンドの送信に失敗しました" -ForegroundColor Red
        exit 1
    }
    
    Start-Sleep -Seconds 3
    Write-Host "サーバーを起動しました" -ForegroundColor Green
    Write-Host ""

    Write-Host "✅ MODファイルのアップロードが完了しました！" -ForegroundColor Green
    Write-Host ""
    Write-Host "アップロードされたMOD:" -ForegroundColor Cyan
    foreach ($mod in $modFiles) {
        Write-Host "  ✓ $($mod.Name)" -ForegroundColor Green
    }
    Write-Host ""
    Write-Host "サーバーは起動中です。接続まで2-3分お待ちください。" -ForegroundColor Yellow

} finally {
    # S3バケットを削除
    Write-Host ""
    Write-Host "一時的なS3バケットを削除中..." -ForegroundColor Yellow
    aws s3 rb s3://$S3Bucket --force --region $Region 2>$null
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "S3バケットを削除しました" -ForegroundColor Green
    } else {
        Write-Host "警告: S3バケットの削除に失敗しました" -ForegroundColor Yellow
        Write-Host "手動で削除してください: aws s3 rb s3://$S3Bucket --force" -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "処理が完了しました" -ForegroundColor Cyan
