# AWS Minecraft サーバー デプロイメントガイド

## 前提条件
- AWSアカウント
- AWS CLIがインストール済み
- SSH接続可能な環境

## ステップ1: AWS EC2インスタンス作成

### 1.1 EC2インスタンス起動
1. AWS Management Consoleにログイン
2. EC2 → インスタンスを起動
3. 以下の設定で作成:
   - **AMI**: Amazon Linux 2
   - **インスタンスタイプ**: t3.small
   - **ストレージ**: 30GB（gp3推奨）
   - **セキュリティグループ**: 以下を許可
     - SSH (22): あなたのIP
     - Minecraft (25565): 0.0.0.0/0

### 1.2 キーペア作成
- 新しいキーペアを作成し、`.pem`ファイルをダウンロード
- 権限設定: `chmod 400 your-key.pem`

## ステップ2: サーバーファイル準備

### 2.1 必要なファイル
以下をサーバーディレクトリに配置:
```
Minecraft_HcSl-Server/
├── server.jar (Forge 1.20.1)
├── server.properties
├── eula.txt (内容: eula=true)
├── mods/
│   ├── Ancient-Obelisks-1.20.1-1.2.3.jar
│   ├── curios-forge-5.14.1+1.20.1.jar
│   ├── Dungeon-Realm-1.20.1-1.1.7.jar
│   ├── Library_of_Exile-1.20.1-2.1.5.jar
│   ├── Mine_and_Slash-1.20.1-6.3.14.jar
│   ├── player-animation-lib-forge-1.0.2-rc1+1.20.jar
│   └── The-Harvest-1.20.1-1.1.3.jar
└── world/ (既存ワールドデータ)
```

### 2.2 eula.txt作成
```
#By changing the setting below to TRUE you are indicating your agreement to our EULA (https://account.mojang.com/documents/minecraft_eula).
#Fri Feb 14 00:00:00 JST 2026
eula=true
```

## ステップ3: EC2インスタンスセットアップ

### 3.1 SSH接続
```bash
ssh -i your-key.pem ec2-user@<EC2-Public-IP>
```

### 3.2 初期セットアップ実行
```bash
# セットアップスクリプトをダウンロード
curl -O https://your-repo/aws-deploy/setup.sh
chmod +x setup.sh
./setup.sh

# ログアウトして再ログイン（Dockerグループ反映）
exit
ssh -i your-key.pem ec2-user@<EC2-Public-IP>
```

## ステップ4: サーバーファイルアップロード

### 4.1 ローカルからアップロード
```bash
scp -i your-key.pem -r Minecraft_HcSl-Server/* ec2-user@<EC2-Public-IP>:/home/ec2-user/minecraft-server/
```

### 4.2 EC2上で確認
```bash
ssh -i your-key.pem ec2-user@<EC2-Public-IP>
cd /home/ec2-user/minecraft-server
ls -la
```

## ステップ5: Docker起動

### 5.1 イメージビルド
```bash
cd /home/ec2-user/minecraft-server
docker-compose build
```

### 5.2 コンテナ起動
```bash
docker-compose up -d
```

### 5.3 ログ確認
```bash
docker-compose logs -f minecraft
```

サーバーが起動するまで1-2分待機してください。

## ステップ6: バックアップ設定

### 6.1 バックアップスクリプト配置
```bash
cp aws-deploy/backup.sh /home/ec2-user/
chmod +x /home/ec2-user/backup.sh
```

### 6.2 Cron設定（毎日3:00 JST）
```bash
crontab -e
```

以下を追加:
```
0 3 * * * /home/ec2-user/backup.sh
```

## 運用コマンド

### サーバー停止
```bash
docker-compose down
```

### サーバー再起動
```bash
docker-compose restart minecraft
```

### ログ確認
```bash
docker-compose logs -f minecraft
```

### ワールドデータ確認
```bash
ls -la /home/ec2-user/minecraft-server/world
```

## トラブルシューティング

### サーバーが起動しない
```bash
docker-compose logs minecraft
```

### メモリ不足
- EC2インスタンスをt3.mediumにアップグレード
- docker-compose.ymlのmem_limitを調整

### MODが読み込まれない
- modsディレクトリが正しくマウントされているか確認
- MODのバージョンが1.20.1と互換性があるか確認

## 月額コスト概算

- EC2 t3.small: $10/月
- EBS 30GB: $3/月
- **合計: 約1,560円/月**

## セキュリティ推奨事項

1. セキュリティグループで接続元IPを制限
2. 定期的なバックアップ実施
3. EC2インスタンスのセキュリティアップデート
4. server.propertiesでオンラインモード有効化

## 参考リンク

- [AWS EC2 料金](https://aws.amazon.com/jp/ec2/pricing/on-demand/)
- [Docker Compose ドキュメント](https://docs.docker.com/compose/)
- [Minecraft Forge](https://files.minecraftforge.net/)
