# AWS CLI と Terraform 自動インストールスクリプト（Windows PowerShell）
# 管理者権限で実行してください

Write-Host "=== AWS CLI と Terraform インストールスクリプト ===" -ForegroundColor Green
Write-Host ""

# 管理者権限チェック
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host "エラー: このスクリプトは管理者権限で実行する必要があります" -ForegroundColor Red
    Write-Host "PowerShellを右クリック → '管理者として実行' で開いてください" -ForegroundColor Yellow
    pause
    exit 1
}

# Chocolateyのインストール確認
Write-Host "Chocolateyを確認中..." -ForegroundColor Cyan
$chocoInstalled = Get-Command choco -ErrorAction SilentlyContinue

if (-not $chocoInstalled) {
    Write-Host "Chocolateyをインストールしています..." -ForegroundColor Yellow
    Set-ExecutionPolicy Bypass -Scope Process -Force
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
    iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "エラー: Chocolateyのインストールに失敗しました" -ForegroundColor Red
        pause
        exit 1
    }
    
    Write-Host "Chocolateyのインストール完了" -ForegroundColor Green
    
    # 環境変数を更新
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
} else {
    Write-Host "Chocolateyは既にインストールされています" -ForegroundColor Green
}

Write-Host ""

# AWS CLIのインストール
Write-Host "AWS CLIをインストール中..." -ForegroundColor Cyan
choco install awscli -y

if ($LASTEXITCODE -ne 0) {
    Write-Host "警告: AWS CLIのインストールでエラーが発生しました" -ForegroundColor Yellow
} else {
    Write-Host "AWS CLIのインストール完了" -ForegroundColor Green
}

Write-Host ""

# Terraformのインストール
Write-Host "Terraformをインストール中..." -ForegroundColor Cyan
choco install terraform -y

if ($LASTEXITCODE -ne 0) {
    Write-Host "警告: Terraformのインストールでエラーが発生しました" -ForegroundColor Yellow
} else {
    Write-Host "Terraformのインストール完了" -ForegroundColor Green
}

Write-Host ""

# 環境変数を更新
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

# インストール確認
Write-Host "=== インストール確認 ===" -ForegroundColor Green
Write-Host ""

Write-Host "AWS CLI バージョン:" -ForegroundColor Cyan
aws --version

Write-Host ""
Write-Host "Terraform バージョン:" -ForegroundColor Cyan
terraform --version

Write-Host ""
Write-Host "=== インストール完了 ===" -ForegroundColor Green
Write-Host ""
Write-Host "次のステップ:" -ForegroundColor Yellow
Write-Host "1. 新しいPowerShellウィンドウを開く（環境変数を反映するため）"
Write-Host "2. AWS認証を設定: aws configure"
Write-Host "3. terraform.tfvars を編集"
Write-Host "4. Terraformを実行: cd aws-deploy\terraform; terraform init"
Write-Host ""
Write-Host "詳細は INSTALL_TOOLS.md を参照してください"
Write-Host ""

pause
