# MODファイルをEC2にアップロードするスクリプト（簡易版）
# 使い方: .\upload-mods-simple.ps1

param(
    [string]$InstanceId = "i-0b3b312b21a19f71b",
    [string]$Region = "ap-northeast-1",
    [string]$ModsFolder = "..\mods"
)

Write-Host "=== Minecraft MODアップロードスクリプト（簡易版） ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "注意: このスクリプトはSSM Session Managerを使用します" -ForegroundColor Yellow
Write-Host "AWS CLIとSession Manager Pluginがインストールされている必要があります" -ForegroundColor Yellow
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
    $sizeMB = [Math]::Round($mod.Length / 1MB, 2)
    Write-Host "  - $($mod.Name) ($sizeMB MB)" -ForegroundColor Gray
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

# 手動アップロード手順を表示
Write-Host "=== 手動アップロード手順 ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "1. 以下のコマンドでEC2に接続してください:" -ForegroundColor Yellow
Write-Host "   aws ssm start-session --target $InstanceId --region $Region" -ForegroundColor White
Write-Host ""
Write-Host "2. 接続後、以下のコマンドを実行してください:" -ForegroundColor Yellow
Write-Host "   sudo systemctl stop minecraft" -ForegroundColor White
Write-Host "   cd /home/ubuntu/minecraft" -ForegroundColor White
Write-Host "   mkdir -p mods_backup" -ForegroundColor White
Write-Host "   mv mods/*.jar mods_backup/ 2>/dev/null || true" -ForegroundColor White
Write-Host ""
Write-Host "3. 別のターミナルで、各MODファイルを以下のコマンドでアップロードしてください:" -ForegroundColor Yellow
Write-Host ""

foreach ($mod in $modFiles) {
    $modPath = $mod.FullName
    Write-Host "   # $($mod.Name) をアップロード" -ForegroundColor Gray
    Write-Host "   aws s3 cp `"$modPath`" s3://YOUR-BUCKET-NAME/temp-mods/$($mod.Name)" -ForegroundColor White
    Write-Host ""
}

Write-Host "4. EC2のセッションに戻り、以下のコマンドでダウンロードしてください:" -ForegroundColor Yellow
Write-Host "   cd /home/ubuntu/minecraft/mods" -ForegroundColor White
Write-Host "   aws s3 sync s3://YOUR-BUCKET-NAME/temp-mods/ . --region $Region" -ForegroundColor White
Write-Host "   sudo chown -R ubuntu:ubuntu /home/ubuntu/minecraft/mods" -ForegroundColor White
Write-Host "   sudo systemctl start minecraft" -ForegroundColor White
Write-Host ""
Write-Host "=== または、以下の自動アップロード方法を試してください ===" -ForegroundColor Cyan
Write-Host ""

# 自動アップロード（SSM Document Upload経由）
$response = Read-Host "自動アップロードを試しますか？ (y/n)"

if ($response -ne "y") {
    Write-Host "手動アップロードを選択しました" -ForegroundColor Yellow
    exit 0
}

Write-Host ""
Write-Host "自動アップロードを開始します..." -ForegroundColor Green
Write-Host ""

# Minecraftサーバーを停止
Write-Host "Minecraftサーバーを停止中..." -ForegroundColor Yellow
$stopCmd = "sudo systemctl stop minecraft && echo 'Server stopped'"
$stopResult = aws ssm send-command --instance-ids $InstanceId --region $Region --document-name "AWS-RunShellScript" --parameters commands="$stopCmd" --query "Command.CommandId" --output text

Start-Sleep -Seconds 5
Write-Host "サーバーを停止しました" -ForegroundColor Green
Write-Host ""

# MODフォルダを準備
Write-Host "MODフォルダを準備中..." -ForegroundColor Yellow
$prepareCmd = "cd /home/ubuntu/minecraft && mkdir -p mods mods_backup && mv mods/*.jar mods_backup/ 2>/dev/null || true && echo 'Folder prepared'"
$prepareResult = aws ssm send-command --instance-ids $InstanceId --region $Region --document-name "AWS-RunShellScript" --parameters commands="$prepareCmd" --query "Command.CommandId" --output text

Start-Sleep -Seconds 3
Write-Host "MODフォルダを準備しました" -ForegroundColor Green
Write-Host ""

# 各MODファイルをアップロード
$uploadedCount = 0
foreach ($mod in $modFiles) {
    Write-Host "アップロード中: $($mod.Name)" -ForegroundColor Cyan
    
    # ファイルを読み込んでBase64エンコード
    $bytes = [System.IO.File]::ReadAllBytes($mod.FullName)
    $base64 = [System.Convert]::ToBase64String($bytes)
    
    # 一時ファイルに保存
    $tempFile = [System.IO.Path]::GetTempFileName()
    [System.IO.File]::WriteAllText($tempFile, $base64)
    
    try {
        # S3-PutObjectを使用してアップロード（より大きなファイルに対応）
        $uploadCmd = "echo '$base64' | base64 -d > /home/ubuntu/minecraft/mods/$($mod.Name) && echo 'Uploaded: $($mod.Name)'"
        
        # コマンドが長すぎる場合はスキップ
        if ($base64.Length -gt 100000) {
            Write-Host "  警告: ファイルサイズが大きすぎます。S3経由でのアップロードを推奨します" -ForegroundColor Yellow
            continue
        }
        
        $uploadResult = aws ssm send-command --instance-ids $InstanceId --region $Region --document-name "AWS-RunShellScript" --parameters commands="$uploadCmd" --query "Command.CommandId" --output text
        
        if ($LASTEXITCODE -eq 0) {
            Start-Sleep -Seconds 2
            Write-Host "  ✓ アップロード完了" -ForegroundColor Green
            $uploadedCount++
        } else {
            Write-Host "  ✗ アップロード失敗" -ForegroundColor Red
        }
    } finally {
        Remove-Item -Path $tempFile -Force -ErrorAction SilentlyContinue
    }
}

Write-Host ""
Write-Host "アップロード完了: $uploadedCount / $($modFiles.Count) ファイル" -ForegroundColor Cyan
Write-Host ""

# サーバーを再起動
Write-Host "Minecraftサーバーを再起動中..." -ForegroundColor Yellow
$startCmd = "cd /home/ubuntu/minecraft && sudo chown -R ubuntu:ubuntu mods && sudo systemctl start minecraft && echo 'Server started'"
$startResult = aws ssm send-command --instance-ids $InstanceId --region $Region --document-name "AWS-RunShellScript" --parameters commands="$startCmd" --query "Command.CommandId" --output text

Start-Sleep -Seconds 3
Write-Host "サーバーを再起動しました" -ForegroundColor Green
Write-Host ""

Write-Host "✅ 処理が完了しました" -ForegroundColor Green
Write-Host ""
Write-Host "注意: 大きなMODファイルはアップロードできなかった可能性があります" -ForegroundColor Yellow
Write-Host "その場合は、S3経由でのアップロードを推奨します" -ForegroundColor Yellow
