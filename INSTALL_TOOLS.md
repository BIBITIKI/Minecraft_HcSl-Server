# AWS CLI と Terraform インストールガイド（Windows）

## 方法1: Chocolatey を使う（推奨・最速）

### Chocolateyのインストール
PowerShellを管理者権限で開いて実行：

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
```

### AWS CLI と Terraform をインストール
```powershell
choco install awscli terraform -y
```

インストール後、PowerShellを再起動して確認：
```powershell
aws --version
terraform --version
```

---

## 方法2: 手動インストール

### AWS CLI のインストール

1. **インストーラーをダウンロード**
   - https://awscli.amazonaws.com/AWSCLIV2.msi

2. **インストーラーを実行**
   - ダウンロードした `AWSCLIV2.msi` をダブルクリック
   - ウィザードに従ってインストール

3. **確認**
   コマンドプロンプトまたはPowerShellで：
   ```cmd
   aws --version
   ```

### Terraform のインストール

1. **ダウンロード**
   - https://www.terraform.io/downloads
   - Windows AMD64版をダウンロード（例: terraform_1.7.0_windows_amd64.zip）

2. **解凍と配置**
   ```powershell
   # ダウンロードフォルダから解凍
   Expand-Archive -Path "$env:USERPROFILE\Downloads\terraform_*_windows_amd64.zip" -DestinationPath "C:\terraform"
   
   # 環境変数PATHに追加
   [Environment]::SetEnvironmentVariable("Path", $env:Path + ";C:\terraform", "User")
   ```

3. **PowerShellを再起動して確認**
   ```powershell
   terraform --version
   ```

---

## AWS CLI の設定

### 1. AWSアクセスキーの作成

1. AWS Management Console → IAM → ユーザー
2. あなたのユーザーを選択
3. 「セキュリティ認証情報」タブ
4. 「アクセスキーを作成」
5. 「コマンドラインインターフェイス (CLI)」を選択
6. アクセスキーIDとシークレットアクセスキーをメモ

### 2. AWS CLIの認証設定

```cmd
aws configure
```

以下を入力：
```
AWS Access Key ID: YOUR_ACCESS_KEY_ID
AWS Secret Access Key: YOUR_SECRET_ACCESS_KEY
Default region name: ap-northeast-1
Default output format: json
```

### 3. 確認

```cmd
aws sts get-caller-identity
```

アカウント情報が表示されればOK

---

## インストール確認チェックリスト

すべてのコマンドが正常に動作することを確認：

```powershell
# AWS CLI
aws --version

# Terraform
terraform --version

# AWS認証
aws sts get-caller-identity

# Git（既にインストール済みの場合）
git --version
```

---

## トラブルシューティング

### "aws" コマンドが見つからない
- PowerShellまたはコマンドプロンプトを再起動
- 環境変数PATHを確認：
  ```powershell
  $env:Path
  ```

### "terraform" コマンドが見つからない
- PowerShellを再起動
- 手動インストールの場合、PATHが正しく設定されているか確認

### AWS認証エラー
- `aws configure` を再実行
- アクセスキーが正しいか確認
- IAMユーザーに適切な権限があるか確認（EC2FullAccess推奨）

---

## 次のステップ

インストールが完了したら：

1. **terraform.tfvars を編集**
   ```
   Minecraft_HcSl-Server/aws-deploy/terraform/terraform.tfvars
   ```

2. **Terraform実行**
   ```powershell
   cd Minecraft_HcSl-Server\aws-deploy\terraform
   terraform init
   terraform plan
   terraform apply
   ```

詳細は `QUICK_START.md` を参照
