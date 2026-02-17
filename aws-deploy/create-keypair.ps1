# EC2キーペア作成スクリプト

Write-Host "=== EC2キーペア作成 ===" -ForegroundColor Green
Write-Host ""

$keyName = "minecraft-server-key"
$keyFile = "$HOME\$keyName.pem"

# 既存のキーペアを確認
Write-Host "既存のキーペアを確認中..." -ForegroundColor Cyan
$existingKey = aws ec2 describe-key-pairs --key-names $keyName 2>$null

if ($existingKey) {
    Write-Host "キーペア '$keyName' は既に存在します" -ForegroundColor Yellow
    $response = Read-Host "削除して再作成しますか？ (y/n)"
    
    if ($response -eq "y") {
        Write-Host "既存のキーペアを削除中..." -ForegroundColor Yellow
        aws ec2 delete-key-pair --key-name $keyName
        Write-Host "削除完了" -ForegroundColor Green
    } else {
        Write-Host "スクリプトを終了します" -ForegroundColor Yellow
        exit 0
    }
}

# 新しいキーペアを作成
Write-Host "新しいキーペアを作成中..." -ForegroundColor Cyan
$keyPair = aws ec2 create-key-pair --key-name $keyName --query 'KeyMaterial' --output text

if ($LASTEXITCODE -ne 0) {
    Write-Host "エラー: キーペアの作成に失敗しました" -ForegroundColor Red
    Write-Host "AWS認証情報を確認してください: aws sts get-caller-identity" -ForegroundColor Yellow
    exit 1
}

# .pemファイルとして保存
$keyPair | Out-File -FilePath $keyFile -Encoding ASCII

Write-Host ""
Write-Host "=== キーペア作成完了 ===" -ForegroundColor Green
Write-Host "キーペア名: $keyName" -ForegroundColor Cyan
Write-Host "保存場所: $keyFile" -ForegroundColor Cyan
Write-Host ""
Write-Host "次のステップ:" -ForegroundColor Yellow
Write-Host "1. terraform.tfvars を確認（key_pair_name = `"$keyName`"）"
Write-Host "2. terraform apply を実行"
Write-Host ""
