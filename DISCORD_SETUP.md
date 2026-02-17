# Discord Bot セットアップガイド

## 概要

Discord Botを使って以下の操作が可能になります：
- `/serverstart` - サーバー起動
- `/serverstop` - サーバー停止
- 起動時にサーバーIPを自動通知

## 前提条件

- Terraformでインフラ構築済み
- Discord サーバー（ギルド）の管理者権限

## ステップ1: Discord Webhook作成

### 1.1 Webhookの作成

1. Discordサーバーを開く
2. 通知を送信したいチャンネルを選択
3. チャンネル設定（歯車アイコン）→ 連携サービス → Webhook
4. 「新しいWebhook」をクリック
5. Webhook名を設定（例: Minecraft Server）
6. 「Webhook URLをコピー」をクリック

### 1.2 Webhook URLを設定

`terraform.tfvars`に追加：

```hcl
discord_webhook_url = "https://discord.com/api/webhooks/YOUR_WEBHOOK_URL"
```

### 1.3 Terraformを再適用

```powershell
cd aws-deploy\terraform
terraform apply
```

## ステップ2: Discord Bot作成

### 2.1 Discord Developer Portalでアプリ作成

1. https://discord.com/developers/applications にアクセス
2. 「New Application」をクリック
3. アプリ名を入力（例: Minecraft Server Bot）
4. 「Create」をクリック

### 2.2 Botを作成

1. 左メニューから「Bot」を選択
2. 「Add Bot」をクリック
3. 「Reset Token」をクリックしてトークンをコピー（後で使用）

### 2.3 Bot権限を設定

1. 「OAuth2」→「URL Generator」を選択
2. Scopesで「bot」と「applications.commands」を選択
3. Bot Permissionsで「Send Messages」を選択
4. 生成されたURLをコピーしてブラウザで開く
5. Botを追加するサーバーを選択

## ステップ3: Glitchでホスティング

### 3.1 Glitchプロジェクト作成

1. https://glitch.com/ にアクセス
2. 「New Project」→「glitch-hello-node」を選択

### 3.2 package.jsonを編集

```json
{
  "name": "minecraft-discord-bot",
  "version": "1.0.0",
  "description": "Minecraft server control bot",
  "main": "index.js",
  "scripts": {
    "start": "node index.js"
  },
  "dependencies": {
    "discord.js": "^14.14.1",
    "@discordjs/rest": "^2.2.0",
    "discord-api-types": "^0.37.61"
  }
}
```

### 3.3 index.jsを作成

```javascript
const { Client, GatewayIntentBits, REST, Routes } = require('discord.js');
const https = require('https');

const TOKEN = process.env.DISCORD_TOKEN;
const CLIENT_ID = process.env.CLIENT_ID;
const LAMBDA_START_URL = process.env.LAMBDA_START_URL;
const LAMBDA_STOP_URL = process.env.LAMBDA_STOP_URL;

const client = new Client({ intents: [GatewayIntentBits.Guilds] });

// スラッシュコマンド登録
const commands = [
  {
    name: 'serverstart',
    description: 'Minecraftサーバーを起動します'
  },
  {
    name: 'serverstop',
    description: 'Minecraftサーバーを停止します'
  }
];

const rest = new REST({ version: '10' }).setToken(TOKEN);

(async () => {
  try {
    console.log('スラッシュコマンドを登録中...');
    await rest.put(Routes.applicationCommands(CLIENT_ID), { body: commands });
    console.log('スラッシュコマンドの登録完了');
  } catch (error) {
    console.error(error);
  }
})();

client.on('ready', () => {
  console.log(`${client.user.tag} でログインしました`);
});

client.on('interactionCreate', async interaction => {
  if (!interaction.isChatInputCommand()) return;

  if (interaction.commandName === 'serverstart') {
    await interaction.reply('サーバー起動処理を開始します...');
    
    https.get(LAMBDA_START_URL, (res) => {
      console.log('サーバー起動リクエスト送信');
    }).on('error', (error) => {
      console.error(error);
      interaction.followUp('エラーが発生しました');
    });
  }

  if (interaction.commandName === 'serverstop') {
    await interaction.reply('サーバー停止処理を開始します...');
    
    https.get(LAMBDA_STOP_URL, (res) => {
      console.log('サーバー停止リクエスト送信');
    }).on('error', (error) => {
      console.error(error);
      interaction.followUp('エラーが発生しました');
    });
  }
});

client.login(TOKEN);

// Glitch用のキープアライブ
const http = require('http');
http.createServer((req, res) => {
  res.writeHead(200);
  res.end('Bot is running');
}).listen(3000);
```

### 3.4 commands.jsを作成

```javascript
const { SlashCommandBuilder } = require('@discordjs/builders');
const https = require('https');

module.exports = {
  serverstart: {
    data: new SlashCommandBuilder()
      .setName('serverstart')
      .setDescription('Minecraftサーバーを起動します'),
    async execute(interaction) {
      const url = process.env.LAMBDA_START_URL;
      await interaction.reply('サーバー起動処理開始');
      
      https.get(url, (res) => {
        console.log('Server start requested');
      }).on('error', (error) => {
        console.error(error);
      });
    }
  },
  serverstop: {
    data: new SlashCommandBuilder()
      .setName('serverstop')
      .setDescription('Minecraftサーバーを停止します'),
    async execute(interaction) {
      const url = process.env.LAMBDA_STOP_URL;
      await interaction.reply('サーバー停止処理開始');
      
      https.get(url, (res) => {
        console.log('Server stop requested');
      }).on('error', (error) => {
        console.error(error);
      });
    }
  }
};
```

### 3.5 環境変数を設定

Glitchの「.env」ファイルに以下を追加：

```
DISCORD_TOKEN=YOUR_BOT_TOKEN
CLIENT_ID=YOUR_CLIENT_ID
LAMBDA_START_URL=YOUR_LAMBDA_START_URL
LAMBDA_STOP_URL=YOUR_LAMBDA_STOP_URL
```

値の取得方法：
- `DISCORD_TOKEN`: Discord Developer PortalのBot設定から
- `CLIENT_ID`: Discord Developer PortalのGeneral Informationから
- `LAMBDA_START_URL`: `terraform output lambda_start_url`
- `LAMBDA_STOP_URL`: `terraform output lambda_stop_url`

## ステップ4: 動作確認

1. Discordサーバーで `/serverstart` を実行
2. 2-3分待つ
3. WebhookでサーバーIPが通知される
4. Minecraftクライアントで接続

## 自動停止の仕組み

以下の条件でサーバーが自動停止します：

1. **深夜3時（JST）**: EventBridgeで自動停止
2. **Discord経由**: `/serverstop` コマンド
3. **プレイヤー不在**: 15分間誰もいない場合

## トラブルシューティング

### Botが応答しない
- Glitchプロジェクトが起動しているか確認
- 環境変数が正しく設定されているか確認
- Bot TokenとClient IDが正しいか確認

### サーバーが起動しない
- Lambda関数URLが正しいか確認
- EC2インスタンスが停止状態か確認
- CloudWatch Logsでエラーを確認

### Webhookが届かない
- Webhook URLが正しいか確認
- terraform.tfvarsに設定されているか確認
- `terraform apply` を実行したか確認

## 参考リンク

- [Discord Developer Portal](https://discord.com/developers/applications)
- [Glitch](https://glitch.com/)
- [Discord.js ドキュメント](https://discord.js.org/)
