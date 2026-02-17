# Terraform設定ガイド

## 設定手順

### 1. terraform.tfvarsを編集

`terraform.tfvars`ファイルを開いて、以下の値を設定してください：

#### key_pair_name（必須）
AWSでEC2キーペアを作成し、その名前を入力します。

**キーペアの作成方法:**
1. AWS Management Console → EC2 → キーペア
2. 「キーペアを作成」をクリック
3. 名前を入力（例: `minecraft-server-key`）
4. キータイプ: RSA
5. プライベートキーファイル形式: .pem
6. 「キーペアを作成」をクリック
7. ダウンロードされた`.pem`ファイルを安全な場所に保存

**terraform.tfvarsに記入:**
```hcl
key_pair_name = "minecraft-server-key"
```

#### ssh_cidr（推奨設定）
SSH接続を許可するIPアドレスを指定します。

**あなたのIPアドレスを確認:**
```bash
curl ifconfig.me
```

**terraform.tfvarsに記入:**
```hcl
ssh_cidr = "123.456.789.012/32"
```

### 2. 設定例

```hcl
aws_region      = "ap-northeast-1"
instance_type   = "t3.small"
ebs_volume_size = 30
key_pair_name   = "minecraft-server-key"
ssh_cidr        = "123.456.789.012/32"
```

### 3. Terraform実行

#### 初期化
```bash
cd Minecraft_HcSl-Server/aws-deploy/terraform
terraform init
```

#### プラン確認
```bash
terraform plan
```

#### インフラ構築
```bash
terraform apply
```

`yes`と入力して実行

#### 出力確認
```bash
terraform output
```

Public IPアドレスが表示されます。

### 4. インフラ削除（不要になった場合）

```bash
terraform destroy
```

## トラブルシューティング

### エラー: "InvalidKeyPair.NotFound"
- キーペア名が間違っています
- AWSコンソールでキーペアが作成されているか確認

### エラー: "UnauthorizedOperation"
- AWS CLIの認証情報が設定されていません
- `aws configure`を実行して設定

### エラー: "InvalidParameterValue"
- terraform.tfvarsの値が不正です
- 特にIPアドレスの形式を確認（例: "1.2.3.4/32"）

## 次のステップ

Terraformでインフラ構築後:
1. Public IPアドレスをメモ
2. サーバーファイルをアップロード
3. Docker起動

詳細は `../../QUICK_START.md` を参照
