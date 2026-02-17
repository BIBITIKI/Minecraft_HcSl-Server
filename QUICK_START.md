# クイックスタートガイド

## 最短デプロイ手順（15分）

### 1. 前提条件
- AWSアカウント
- AWS CLI インストール済み
- Terraform インストール済み

### 2. ファイル準備
```bash
# 必要なファイルをサーバーディレクトリに配置
cd Minecraft_HcSl-Server

# eula.txtを作成
echo "eula=true" > eula.txt

# server.jarをダウンロード（Forge 1.20.1）
# https://files.minecraftforge.net/ から server.jar をダウンロード
```

### 3. Terraform設定
```bash
cd aws-deploy/terraform

# terraform.tfvars.exampleをコピー
cp terraform.tfvars.example terraform.tfvars

# terraform.tfvarsを編集
# - key_pair_name: あなたのEC2キーペア名
# - ssh_cidr: あなたのIP/32
nano terraform.tfvars
```

### 4. インフラ構築
```bash
terraform init
terraform plan
terraform apply
```

出力されたPublic IPをメモ

### 5. サーバーファイルアップロード
```bash
# EC2インスタンスが起動するまで待機（2-3分）
# その後、ファイルをアップロード

PUBLIC_IP=$(terraform output -raw instance_public_ip)

scp -i /path/to/your-key.pem -r ../* ec2-user@$PUBLIC_IP:/home/ec2-user/minecraft-server/
```

### 6. サーバー起動
```bash
ssh -i /path/to/your-key.pem ec2-user@$PUBLIC_IP

cd /home/ec2-user/minecraft-server
docker-compose up -d
docker-compose logs -f minecraft
```

### 7. クライアント接続
Minecraftクライアントで:
- サーバーアドレス: `$PUBLIC_IP:25565`

## トラブル時の確認

```bash
# ログ確認
docker-compose logs minecraft

# コンテナ状態確認
docker ps

# ディスク使用量確認
df -h
```

## クリーンアップ（削除）
```bash
cd aws-deploy/terraform
terraform destroy
```

## 月額コスト
- **約1,560円/月**（t3.small + 30GB EBS）

詳細は `DEPLOYMENT_GUIDE.md` を参照
