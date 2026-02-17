# AWS Console 手動EC2セットアップガイド

## 目的
Terraformでエラーが出る場合、AWS Consoleで手動でEC2インスタンスを起動して、利用可能なインスタンスタイプを確認します。

## ステップ1: AWS Consoleにログイン

1. ブラウザで https://console.aws.amazon.com/ を開く
2. アカウントIDまたはメールアドレスでログイン
3. リージョンが **東京（ap-northeast-1）** になっているか確認（右上）

## ステップ2: EC2ダッシュボードを開く

1. 上部の検索バーで「EC2」と入力
2. 「EC2」サービスをクリック
3. 左メニューから「インスタンス」をクリック

## ステップ3: インスタンスを起動

1. 右上の「インスタンスを起動」ボタンをクリック

### 3.1 名前とタグ
```
名前: minecraft-server-test
```

### 3.2 アプリケーションおよびOSイメージ（AMI）
- **Amazon Linux 2023 AMI** を選択
- アーキテクチャ: 64ビット (x86)

### 3.3 インスタンスタイプ
ここで **利用可能なインスタンスタイプを確認** してください。

試す順序：
1. **t3a.medium** （推奨）
2. **t3.medium** （代替）
3. **t2.medium** （古い世代）
4. **t2.small** （最小構成）

**重要**: どのインスタンスタイプが選択可能か確認してください。
- グレーアウトされている場合は選択不可
- 選択可能なものをメモしてください

### 3.4 キーペア
- **既存のキーペアを選択**: `minecraft-server-key`
- （リストに表示されているはずです）

### 3.5 ネットワーク設定
「編集」をクリックして以下を設定：

#### VPC
- デフォルトVPCを選択

#### サブネット
- 任意のサブネットを選択

#### パブリックIPの自動割り当て
- **有効化** を選択

#### ファイアウォール（セキュリティグループ）
「既存のセキュリティグループを選択」を選択
- **minecraft-server-sg** を選択（Terraformで作成済み）

もし存在しない場合、「新しいセキュリティグループを作成」を選択：
- セキュリティグループ名: `minecraft-server-sg`
- 説明: `Minecraft server security group`

ルール：
1. **SSH**
   - タイプ: SSH
   - ソース: マイIP（または 0.0.0.0/0）
   
2. **Minecraft**
   - タイプ: カスタムTCP
   - ポート範囲: 25565
   - ソース: 0.0.0.0/0

### 3.6 ストレージを設定
- サイズ: **20 GiB**
- ボリュームタイプ: **gp3**
- 終了時に削除: **チェックを入れる**

### 3.7 高度な詳細（重要）

下にスクロールして「高度な詳細」を展開

#### IAMインスタンスプロファイル
- **minecraft-instance-profile** を選択（Terraformで作成済み）

#### ユーザーデータ
以下のスクリプトをコピー＆ペースト：

```bash
#!/bin/bash
set -e

exec > >(tee /var/log/user-data.log)
exec 2>&1

echo "=== Minecraft Server Setup Started ==="

dnf update -y
dnf install -y java-21-amazon-corretto
dnf install -y aws-cli

mkdir -p /minecraft/server
cd /minecraft/server

cat > /minecraft/launch.sh << 'EOF'
#!/bin/bash
cd /minecraft/server
java -Xmx3072M -Xms3072M -jar server.jar nogui
EOF

chmod +x /minecraft/launch.sh

cat > /etc/systemd/system/minecraft.service << 'EOF'
[Unit]
Description=Minecraft Server
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/minecraft/server
ExecStart=/minecraft/launch.sh
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable minecraft.service

echo "=== Minecraft Server Setup Completed ==="
```

**注意**: メモリ設定（3072M）はインスタンスタイプに応じて調整：
- t3a.medium / t3.medium: 3072M
- t2.medium: 3072M
- t2.small: 1536M
- t2.micro: 512M

## ステップ4: インスタンスを起動

1. 右側の「概要」で設定を確認
2. 「インスタンスを起動」ボタンをクリック

### エラーが出た場合
エラーメッセージを確認：
- 「InvalidParameterCombination」→ インスタンスタイプを変更
- 「InsufficientInstanceCapacity」→ 別のアベイラビリティゾーンを試す
- 「VcpuLimitExceeded」→ サービスクォータの引き上げが必要

## ステップ5: インスタンスの確認

1. 「インスタンス」ページに戻る
2. 新しいインスタンスが「実行中」になるまで待つ（1-2分）
3. インスタンスを選択
4. 下部の「詳細」タブで以下を確認：
   - **パブリックIPv4アドレス**: これをメモ
   - **インスタンスID**: これもメモ

## ステップ6: SSH接続テスト

PowerShellで：

```powershell
ssh -i C:\Kiro\minecraft-server-key.pem ec2-user@<パブリックIP>
```

接続できたら成功です。

## ステップ7: サーバーファイルをアップロード

ローカルPCから：

```powershell
$PUBLIC_IP = "<パブリックIP>"

scp -i C:\Kiro\minecraft-server-key.pem -r C:\Kiro\Minecraft_HcSl-Server\* ec2-user@${PUBLIC_IP}:/home/ec2-user/minecraft-server/
```

## ステップ8: EC2上でサーバーファイルを配置

SSH接続した状態で：

```bash
# サーバーファイルを正しい場所に移動
sudo cp -r /home/ec2-user/minecraft-server/* /minecraft/server/

# 権限設定
sudo chown -R root:root /minecraft/server

# ファイル確認
ls -la /minecraft/server/

# 必要なファイル:
# - server.jar (Forge 1.20.1)
# - eula.txt
# - server.properties
# - mods/
# - world/
```

## ステップ9: Minecraftサーバー起動

```bash
# サービス起動
sudo systemctl start minecraft.service

# ログ確認
sudo journalctl -u minecraft.service -f
```

「Done」と表示されたら起動完了（Ctrl+Cで終了）

## ステップ10: 動作確認

Minecraftクライアントで：
- サーバーアドレス: `<パブリックIP>:25565`

## トラブルシューティング

### インスタンスタイプが選択できない

**原因**: アカウントの制限

**解決策**:
1. 別のインスタンスタイプを試す
2. 別のリージョン（us-east-1など）を試す
3. AWSサポートに連絡

### セキュリティグループが見つからない

**原因**: Terraformで作成されていない

**解決策**: 手動で作成（ステップ3.5参照）

### IAMインスタンスプロファイルが見つからない

**原因**: Terraformで作成されていない

**解決策**: 
1. 一旦IAMなしで起動
2. 後でIAMロールをアタッチ

### SSH接続できない

**原因**: セキュリティグループの設定

**確認**:
```powershell
# セキュリティグループ確認
aws ec2 describe-security-groups --group-ids <セキュリティグループID>
```

## 次のステップ

手動起動が成功したら：

1. **利用可能なインスタンスタイプを確認**
2. **terraform.tfvarsを更新**
   ```hcl
   instance_type = "利用可能だったインスタンスタイプ"
   ```
3. **Terraformで再試行**
   ```powershell
   cd C:\Kiro\Minecraft_HcSl-Server\aws-deploy\terraform
   terraform apply
   ```

## 参考情報

### 月額コスト（東京リージョン）
- t3a.medium: 約1,920円/月
- t3.medium: 約2,400円/月
- t2.medium: 約2,880円/月
- t2.small: 約1,440円/月

### 推奨スペック（5人未満）
- 最小: t2.small（2GB RAM）
- 推奨: t3a.medium（4GB RAM）
- 快適: t3a.large（8GB RAM）

## AWSサポートへの問い合わせ

もし全てのインスタンスタイプが選択できない場合：

1. AWS Console → サポート → サポートセンター
2. 「ケースを作成」をクリック
3. 以下の情報を記載：
   ```
   件名: EC2インスタンスタイプの利用制限について
   
   内容:
   アカウントID: 024460283611
   リージョン: ap-northeast-1
   エラー: InvalidParameterCombination - The specified instance type is not eligible for Free Tier
   
   t2.micro、t2.small、t2.medium、t3.medium、t3a.mediumなど、
   複数のインスタンスタイプで同じエラーが発生します。
   
   このアカウントで利用可能なインスタンスタイプを教えてください。
   また、制限がある場合は解除をお願いします。
   ```

通常24時間以内に返信があります。
