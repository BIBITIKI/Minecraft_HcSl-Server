# MODファイルをEC2にアップロードするスクリプト
# 使い方: .\upload-mods.ps1

param(
    [string]$InstanceId = "i-0b3b312b21a19f71b",
    [string]$Region = "ap-northeast-1",
    [string]$ModsFolder = "..\mods"
)

Write-Host "=== Minecraft MODアップロードスクリプト ===" -ForegroundColor Cyan
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
foreach ($mod in $modFiles) {
    Write-Host "  - $($mod.Name)" -ForegroundColor Gray
}
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

# SSM経由でMODフォルダを準備
Write-Host "EC2でMODフォルダを準備中..." -ForegroundColor Yellow

$prepareCommand = @"
cd /home/ubuntu/minecraft
sudo systemctl stop minecraft
mkdir -p mods
mkdir -p mods_backup
if [ -d mods ] && [ "\$(ls -A mods 2>/dev/null)" ]; then
    mv mods/*.jar mods_backup/ 2>/dev/null || true
fi
echo "MODフォルダを準備しました"
"@

$commandId = aws ssm send-command `
    --instance-ids $InstanceId `
    --region $Region `
    --document-name "AWS-RunShellScript" `
    --parameters "commands=$prepareCommand" `
    --query "Command.CommandId" `
    --output text

if ($LASTEXITCODE -ne 0) {
    Write-Host "エラー: SSMコマンドの送信に失敗しました" -ForegroundColor Red
    exit 1
}

Write-Host "準備コマンドを送信しました (CommandId: $commandId)" -ForegroundColor Green

# コマンド完了を待機
Start-Sleep -Seconds 5

$maxAttempts = 20
$attempt = 0
$prepareSuccess = $false

while ($attempt -lt $maxAttempts) {
    $attempt++
    
    $status = aws ssm get-command-invocation `
        --command-id $commandId `
        --instance-id $InstanceId `
        --region $Region `
        --query "Status" `
        --output text 2>$null

    if ($status -eq "Success") {
        $prepareSuccess = $true
        break
    } elseif ($status -eq "Failed" -or $status -eq "Cancelled" -or $status -eq "TimedOut") {
        Write-Host "エラー: 準備コマンドが失敗しました (Status: $status)" -ForegroundColor Red
        exit 1
    }

    Write-Host "  待機中... ($attempt/$maxAttempts)" -ForegroundColor Gray
    Start-Sleep -Seconds 2
}

if (-not $prepareSuccess) {
    Write-Host "タイムアウト: 準備コマンドが完了しませんでした" -ForegroundColor Red
    exit 1
}

Write-Host "MODフォルダの準備が完了しました" -ForegroundColor Green
Write-Host ""

# 各MODファイルをSSM経由でアップロード
Write-Host "MODファイルをアップロード中..." -ForegroundColor Yellow

$uploadedCount = 0
foreach ($mod in $modFiles) {
    Write-Host "  アップロード中: $($mod.Name)" -ForegroundColor Cyan
    
    # ファイルをBase64エンコード
    $bytes = [System.IO.File]::ReadAllBytes($mod.FullName)
    $base64 = [System.Convert]::ToBase64String($bytes)
    
    # ファイルサイズチェック
    $fileSizeMB = [Math]::Round($mod.Length / 1MB, 2)
    Write-Host "    サイズ: $fileSizeMB MB" -ForegroundColor Gray
    
    if ($mod.Length -gt 5MB) {
        Write-Host "    警告: ファイルサイズが大きいため、アップロードに時間がかかります" -ForegroundColor Yellow
    }
    
    # Base64をチャンクに分割（SSMの制限対策）
    $chunkSize = 40000
    $totalChunks = [Math]::Ceiling($base64.Length / $chunkSize)
    
    # 一時ファイルを作成してアップロード
    $uploadCommand = @"
cd /home/ubuntu/minecraft/mods
rm -f $($mod.Name).b64
"@
    
    for ($i = 0; $i -lt $totalChunks; $i++) {
        $start = $i * $chunkSize
        $length = [Math]::Min($chunkSize, $base64.Length - $start)
        $chunk = $base64.Substring($start, $length)
        
        $uploadCommand += "`necho '$chunk' >> $($mod.Name).b64"
        
        if (($i + 1) % 10 -eq 0) {
            Write-Host "    進行状況: $($i + 1)/$totalChunks チャンク" -ForegroundColor Gray
        }
    }
    
    $uploadCommand += @"

base64 -d $($mod.Name).b64 > $($mod.Name)
rm -f $($mod.Name).b64
echo "Uploaded: $($mod.Name)"
"@
    
    # SSMコマンドを送信
    $cmdId = aws ssm send-command `
        --instance-ids $InstanceId `
        --region $Region `
        --document-name "AWS-RunShellScript" `
        --parameters "commands=$uploadCommand" `
        --query "Command.CommandId" `
        --output text
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "    エラー: アップロードコマンドの送信に失敗しました" -ForegroundColor Red
        continue
    }
    
    # コマンド完了を待機
    Start-Sleep -Seconds 3
    
    $uploadAttempt = 0
    $uploadSuccess = $false
    
    while ($uploadAttempt -lt 30) {
        $uploadAttempt++
        
        $uploadStatus = aws ssm get-command-invocation `
            --command-id $cmdId `
            --instance-id $InstanceId `
            --region $Region `
            --query "Status" `
            --output text 2>$null
        
        if ($uploadStatus -eq "Success") {
            $uploadSuccess = $true
            break
        } elseif ($uploadStatus -eq "Failed" -or $uploadStatus -eq "Cancelled" -or $uploadStatus -eq "TimedOut") {
            Write-Host "    エラー: アップロードが失敗しました (Status: $uploadStatus)" -ForegroundColor Red
            
            # エラー詳細を取得
            $errorOutput = aws ssm get-command-invocation `
                --command-id $cmdId `
                --instance-id $InstanceId `
                --region $Region `
                --query "StandardErrorContent" `
                --output text 2>$null
            
            if ($errorOutput) {
                Write-Host "    エラー詳細: $errorOutput" -ForegroundColor Red
            }
            break
        }
        
        if ($uploadAttempt % 5 -eq 0) {
            Write-Host "    待機中... ($uploadAttempt/30)" -ForegroundColor Gray
        }
        Start-Sleep -Seconds 2
    }
    
    if ($uploadSuccess) {
        Write-Host "    ✓ アップロード完了" -ForegroundColor Green
        $uploadedCount++
    } else {
        Write-Host "    ✗ アップロード失敗またはタイムアウト" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "アップロード完了: $uploadedCount / $($modFiles.Count) ファイル" -ForegroundColor Cyan
Write-Host ""

# サーバーを再起動
Write-Host "Minecraftサーバーを再起動中..." -ForegroundColor Yellow

$restartCommand = @"
cd /home/ubuntu/minecraft
sudo chown -R ubuntu:ubuntu mods
sudo systemctl start minecraft
echo "Minecraftサーバーを起動しました"
"@

$restartCmdId = aws ssm send-command `
    --instance-ids $InstanceId `
    --region $Region `
    --document-name "AWS-RunShellScript" `
    --parameters "commands=$restartCommand" `
    --query "Command.CommandId" `
    --output text

if ($LASTEXITCODE -ne 0) {
    Write-Host "エラー: 再起動コマンドの送信に失敗しました" -ForegroundColor Red
    exit 1
}

Start-Sleep -Seconds 3

$restartAttempt = 0
$restartSuccess = $false

while ($restartAttempt -lt 15) {
    $restartAttempt++
    
    $restartStatus = aws ssm get-command-invocation `
        --command-id $restartCmdId `
        --instance-id $InstanceId `
        --region $Region `
        --query "Status" `
        --output text 2>$null
    
    if ($restartStatus -eq "Success") {
        $restartSuccess = $true
        break
    } elseif ($restartStatus -eq "Failed" -or $restartStatus -eq "Cancelled" -or $restartStatus -eq "TimedOut") {
        Write-Host "警告: 再起動コマンドが失敗しました (Status: $restartStatus)" -ForegroundColor Yellow
        break
    }
    
    Write-Host "  待機中... ($restartAttempt/15)" -ForegroundColor Gray
    Start-Sleep -Seconds 2
}

Write-Host ""
if ($restartSuccess) {
    Write-Host "✅ MODファイルのアップロードとサーバー再起動が完了しました！" -ForegroundColor Green
} else {
    Write-Host "⚠️ MODファイルはアップロードされましたが、サーバーの再起動を確認できませんでした" -ForegroundColor Yellow
    Write-Host "手動でサーバーの状態を確認してください" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "アップロードされたMOD:" -ForegroundColor Cyan
foreach ($mod in $modFiles) {
    Write-Host "  • $($mod.Name)" -ForegroundColor Gray
}
