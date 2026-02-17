# Discord Bot クイックセットアップ

## 現在の状態

✅ EC2インスタンス起動中
✅ Minecraftサーバー稼働中
✅ Lambda関数作成済み
✅ 自動停止監視起動中

## Lambda URL（Discord Botで使用）

**起動URL**: `https://wxefluc2qfy2dd32czkvefeozi0yetwi.lambda-url.ap-northeast-1.on.aws/`
**停止URL**: `https://hvyt42jkwftvbrxhepo27ikisa0xxwtw.lambda-url.ap-northeast-1.on.aws/`

## ステップ1: Discord Webhook作成（5分）

### 1.1 Discordサーバーを開く
1. 通知を受け取りたいチャンネルを選択
2. チャンネル名の横の歯車アイコン（設定）をクリック

### 1.2 Webhookを作成
1. 左メニューから「連携サービス」を選択
2. 「Webhook」タブをクリック
3. 「新しいWebhook」をクリック
4. Webhook名を入力（例: Minecraft Server）
5. 「Webhook URLをコピー」をクリック

### 1.3 Webhook URLを設定

コピーしたURLを保存してください：
```
https://discord.com/api/webhooks/YOUR_WEBHOOK_ID/YOUR_WEBHOOK_TOKEN
```

### 1.4 Terraformに設定

`terraform.tfvars`を編集：

```hcl
discord_webhook_url = "https://discord.com/api/webhooks/YOUR_WEBHOOK_ID/YOUR_WEBHOOK_TOKEN"
```

### 1.5 Terraformを再適用

```powershell
cd C:\Kiro\Minecraft_HcSl-Server\aws-deploy\terraform
terraform apply -auto-approve
```

これでLambda関数がWebhookを使用するようになります。

## ステップ2: Discord Bot作成（15分）

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
2. Scopesで以下を選択：
   - `bot`
   - `applications.commands`
3. Bot Permissionsで以下を選択：
   - `Send Messages`
4. 生成されたURLをコピーしてブラウザで開く
5. Botを追加するサーバーを選択

### 2.4 Client IDを取得

1. 左メニューから「OAuth2」→「General」を選択
2. 「Client ID」をコピー

## ステップ3: Glitchでホスティング（10分）

### 3.1 Glitchプロジェクト作成

**方法1: Glitchのウェブサイトから**

1. https://glitch.com/ にアクセス
2. ログイン（GitHubアカウントでログイン推奨）
3. ダッシュボードで「New project」または「Create project」ボタンをクリック
4. 以下のいずれかを選択:
   - 「Hello Node」（Node.jsテンプレート）
   - 「Import from GitHub」
   - 「Blank project」

**方法2: 直接プロジェクトを作成**

1. https://glitch.com/edit/ に直接アクセス
2. 自動的に新しいプロジェクトが作成されます

**方法3: テンプレートから作成（推奨）**

1. https://glitch.com/~hello-express にアクセス
2. 「Remix」ボタンをクリック
3. 自動的に新しいプロジェクトが作成されます

**注意**: Glitchのインターフェースは頻繁に変更されます。上記の選択肢が見つからない場合は、任意のNode.jsプロジェクトを作成してください。

### 代替案: Glitchが使えない場合

Glitchが使えない場合は、以下の代替サービスを検討してください:

- **Replit**: https://replit.com/ （無料プランあり）
- **Railway**: https://railway.app/ （無料プランあり）
- **Render**: https://render.com/ （無料プランあり）

いずれも同じDiscord Bot コードが動作します。

### 3.2 package.jsonを作成/編集

左側のファイルリストから`package.json`を選択（なければ「New File」で作成）して以下の内容に置き換え：

```json
{
  "name": "minecraft-discord-bot",
  "version": "1.0.0",
  "description": "Minecraft server control bot",
  "main": "server.js",
  "scripts": {
    "start": "node server.js"
  },
  "dependencies": {
    "discord.js": "^14.14.1"
  }
}
```

### 3.3 server.jsを作成

`server.js`を以下の内容で作成：

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
  },
  {
    name: 'serverstatus',
    description: 'サーバーの状態を確認します'
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
    await interaction.reply('🚀 サーバー起動処理を開始します...');
    
    https.get(LAMBDA_START_URL, (res) => {
      console.log('サーバー起動リクエスト送信');
    }).on('error', (error) => {
      console.error(error);
      interaction.followUp('❌ エラーが発生しました');
    });
  }

  if (interaction.commandName === 'serverstop') {
    await interaction.reply('🛑 サーバー停止処理を開始します...');
    
    https.get(LAMBDA_STOP_URL, (res) => {
      console.log('サーバー停止リクエスト送信');
    }).on('error', (error) => {
      console.error(error);
      interaction.followUp('❌ エラーが発生しました');
    });
  }

  if (interaction.commandName === 'serverstatus') {
    await interaction.reply('📊 サーバーを起動すると、IPアドレスが自動通知されます。\n\n`/serverstart` コマンドでサーバーを起動してください。');
  }
});

client.login(TOKEN);

// Glitch用のキープアライブ
const http = require('http');
http.createServer((req, res) => {
  res.writeHead(200);
  res.end('Bot is running');
}).listen(3000);

console.log('Bot starting...');
```

### 3.4 環境変数を設定

Glitchの左下の「.env」ファイルをクリックして以下を追加：

```
DISCORD_TOKEN=YOUR_BOT_TOKEN_HERE
CLIENT_ID=YOUR_CLIENT_ID_HERE
LAMBDA_START_URL=https://wxefluc2qfy2dd32czkvefeozi0yetwi.lambda-url.ap-northeast-1.on.aws/
LAMBDA_STOP_URL=https://hvyt42jkwftvbrxhepo27ikisa0xxwtw.lambda-url.ap-northeast-1.on.aws/
```

値を入力：
- `DISCORD_TOKEN`: ステップ2.2でコピーしたBotトークン
- `CLIENT_ID`: ステップ2.4でコピーしたClient ID
- `LAMBDA_START_URL`: 上記の起動URL
- `LAMBDA_STOP_URL`: 上記の停止URL

### 3.5 Botを起動

Glitchが自動的にBotを起動します。ログに「Bot starting...」と表示されればOK。

## ステップ4: 動作確認

### 4.1 Discordでコマンドを実行

Discordサーバーで以下を試してください：

1. `/serverstatus` - サーバーアドレスを表示
2. `/serverstop` - サーバーを停止（テスト）
3. `/serverstart` - サーバーを起動

### 4.2 Webhook通知を確認

サーバー起動時に、Discordチャンネルに以下のような通知が届きます：

```
✅ Minecraftサーバーが起動しました！

サーバーアドレス: XX.XX.XX.XX:25565

接続まで2-3分お待ちください。
```

**注意**: Elastic IPを削除したため、起動のたびにIPアドレスが変わります。Discord通知で最新のIPアドレスを確認してください。

## トラブルシューティング

### Botが応答しない

1. Glitchのログを確認
2. 環境変数が正しく設定されているか確認
3. Bot TokenとClient IDが正しいか確認

### Webhookが届かない

1. Webhook URLが正しいか確認
2. `terraform apply`を実行したか確認
3. Lambda関数のログを確認：
   ```powershell
   aws logs tail /aws/lambda/minecraft-start-server --follow
   ```

### サーバーが起動しない

1. EC2インスタンスが停止しているか確認：
   ```powershell
   aws ec2 describe-instances --instance-ids i-0be762ecb97115b07
   ```

2. Lambda関数を直接テスト：
   ```powershell
   curl https://wxefluc2qfy2dd32czkvefeozi0yetwi.lambda-url.ap-northeast-1.on.aws/
   ```

## まとめ

完了すると以下が可能になります：

✅ Discord経由でサーバー起動
✅ Discord経由でサーバー停止（安全な停止処理）
✅ サーバー起動時にIPアドレスを自動通知（動的IP）
✅ 深夜3時に自動停止
✅ 15分間プレイヤー不在で自動停止
✅ 監視スクリプトは自動起動（systemctl enable済み）

月額コスト: 約2,208円（Elastic IP削除により-432円）

## コスト削減オプション

さらにコストを抑えたい場合は`COST_OPTIMIZATION.md`を参照してください：

- **t3a.smallにダウングレード**: 月額1,248円（-960円）
- **Reserved Instance（1年契約）**: 月額1,584円（-624円）
- **自動停止の活用**: 月額約600円（月180時間稼働想定）

## 安全な停止処理について

Lambda stop関数は以下の手順で安全に停止します：

1. SSM経由で`systemctl stop minecraft.service`を実行
2. 10秒待機（データ保存完了を待つ）
3. `shutdown -h now`でEC2を停止

これにより、ワールドデータの破損を防ぎます。
