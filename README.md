# Mine and Slash Minecraft Server

AWS EC2上で動作するMine and Slash MODサーバーのインフラストラクチャとクライアント環境構築ガイド。

## 🎮 クライアント環境構築ガイド

サーバーで遊ぶための環境構築手順はこちら:

**📖 [セットアップガイド](https://BIBITIKI.github.io/Minecraft_HcSl-Server/)**

## 🏗️ インフラ構成

- **EC2**: t3a.medium (Minecraft サーバー)
- **Lambda**: サーバー起動/停止/ステータス管理
- **API Gateway**: Discord Bot からの操作エンドポイント
- **CloudWatch Events**: 深夜3時自動停止
- **SSM**: サーバー管理とコマンド実行

## 📦 必須MOD

- Mine and Slash (v6.3.14)
- Library of Exile (v2.1.5)
- Dungeon Realm (v1.1.7)
- The Harvest (v1.1.3)
- Ancient Obelisks (v1.2.3)
- Curios API (v5.14.1)
- Player Animation Lib (v1.0.2)

## 🤖 Discord Bot

サーバー管理用Discord Bot: [minecraft-discord-bot](https://github.com/BIBITIKI/minecraft-discord-bot)

### 主なコマンド

- `/start` - サーバー起動
- `/stop` - サーバー停止
- `/status` - サーバー状態確認
- `/mods` - MOD一覧表示
- `/info` - サーバー情報表示

## 🚀 デプロイ

```bash
cd aws-deploy/terraform
terraform init
terraform apply
```

## 📝 ライセンス

MIT License
