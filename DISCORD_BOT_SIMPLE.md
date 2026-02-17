# Discord Bot 簡単セットアップ（Replit版 - 2025年最新）

## 方法1: Replit（推奨・最も簡単）

### ステップ1: Replitアカウント作成とログイン（2分）

1. https://replit.com/ にアクセス
2. 右上の「Sign up」または「Log in」をクリック
3. GitHubアカウントでサインアップ（推奨）またはメールアドレスで登録

### ステップ2: 新しいReplを作成（1分）

**2025年版の手順**:

1. ダッシュボードで「+ Create Repl」または「+ New repl」ボタンをクリック
   - ボタンは画面上部または中央にあります
2. テンプレートギャラリーが開きます
3. 検索ボックスで「Node.js」と入力するか、一覧から「Node.js」を選択
4. Replに名前を付ける（例: `minecraft-discord-bot`）
5. 「Create Repl」または「Create」ボタンをクリック

**注意**: インターフェースは頻繁に変更されます。「Create」「New」「+」などのボタンを探してください。

### ステップ3: ファイルを作成（5分）

#### 3-1. package.jsonを作成

1. 左側のファイルツリーで「Files」タブを確認
2. 既存の`package.json`がある場合は開く、ない場合は以下の方法で作成:
   - 「Add file」または「+」ボタンをクリック
   - ファイル名に`package.json`と入力
3. 以下の内容を貼り付け:

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
    "express": "^4.18.2"
  }
}
```

#### 3-2. index.jsを作成

1. 既存の`index.js`または`main.js`がある場合は開く、ない場合は新規作成
2. 以下の内容を貼り付け（既存の内容は全て削除）:

```javascript
const { Client, GatewayIntentBits, REST, Routes } = require('discord.js');
const https = require('https');
const express = require('express');

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

// Replit用のキープアライブ
const app = express();
app.get('/', (req, res) => {
  res.send('Bot is running');
});
app.listen(3000, () => {
  console.log('Keep-alive server started on port 3000');
});

console.log('Bot starting...');
```

### ステップ4: 環境変数（Secrets）を設定（3分）

**2025年版の手順**:

1. 左側のツールバーで「Tools」または「Secrets」を探す
   - 鍵アイコン🔒または「Tools」メニュー内にあります
   - 見つからない場合は、画面左下の「Tools」→「Secrets」を確認
2. 「Add new secret」または「+ New secret」をクリック
3. 以下の4つの環境変数を1つずつ追加:

**追加する環境変数**:

| Key | Value |
|-----|-------|
| `DISCORD_TOKEN` | （後で取得するBotトークン） |
| `CLIENT_ID` | （後で取得するClient ID） |
| `LAMBDA_START_URL` | `https://wxefluc2qfy2dd32czkvefeozi0yetwi.lambda-url.ap-northeast-1.on.aws/` |
| `LAMBDA_STOP_URL` | `https://hvyt42jkwftvbrxhepo27ikisa0xxwtw.lambda-url.ap-northeast-1.on.aws/` |

**注意**: `DISCORD_TOKEN`と`CLIENT_ID`は次のステップで取得します。先にLambda URLだけ設定してもOKです。

### ステップ5: Discord Bot Token取得（5分）

#### 5-1. Discord Developer Portalでアプリ作成

1. https://discord.com/developers/applications にアクセス
2. 右上の「New Application」ボタンをクリック
3. アプリ名を入力（例: `Minecraft Server Bot`）
4. 利用規約に同意して「Create」をクリック

#### 5-2. Botを作成してトークンを取得

1. 左メニューから「Bot」を選択
2. 「Add Bot」をクリック（既にBotがある場合はスキップ）
3. 「Reset Token」ボタンをクリック
4. 表示されたトークンをコピー（これが`DISCORD_TOKEN`です）
5. Replitに戻って、Secretsの`DISCORD_TOKEN`に貼り付け

**重要**: トークンは一度しか表示されません。必ずコピーしてください。

#### 5-3. Client IDを取得

1. 左メニューから「OAuth2」→「General」を選択
2. 「Client ID」の下にある長い数字をコピー
3. Replitに戻って、Secretsの`CLIENT_ID`に貼り付け

#### 5-4. Bot権限を設定してサーバーに追加

1. 左メニューから「OAuth2」→「URL Generator」を選択
2. 「Scopes」セクションで以下を選択:
   - ☑ `bot`
   - ☑ `applications.commands`
3. 「Bot Permissions」セクションで以下を選択:
   - ☑ `Send Messages`
   - ☑ `Use Slash Commands`（自動的に選択される場合もあります）
4. 一番下の「Generated URL」をコピー
5. 新しいタブでそのURLを開く
6. Botを追加したいDiscordサーバーを選択
7. 「認証」をクリック

### ステップ6: Botを起動（1分）

**2025年版の手順**:

1. Replitの画面上部にある「Run」ボタンをクリック
   - 緑色の再生ボタン▶または「Run」と書かれたボタンです
2. 下部のコンソールに以下のメッセージが表示されればOK:
   ```
   Bot starting...
   Keep-alive server started on port 3000
   スラッシュコマンドを登録中...
   スラッシュコマンドの登録完了
   Minecraft Server Bot#1234 でログインしました
   ```

3. エラーが出た場合:
   - Secretsが正しく設定されているか確認
   - `DISCORD_TOKEN`と`CLIENT_ID`が正しいか確認
   - コンソールのエラーメッセージを確認

### ステップ7: 動作確認（2分）

1. Discordサーバーを開く
2. チャットで `/` を入力
3. Botのコマンドが表示されるはずです:
   - `/serverstart` - サーバー起動
   - `/serverstop` - サーバー停止
   - `/serverstatus` - サーバー状態確認

4. `/serverstatus` を実行してテスト

**成功**: Botが応答すれば完了です！

### ステップ8: 24時間稼働設定（オプション）

Replitの無料プランでは、一定時間アクセスがないとスリープします。24時間稼働させるには:

**オプション1: Replit有料プラン（推奨）**
- Replit Coreプラン（月$7）で常時稼働

**オプション2: UptimeRobot（無料）**
1. https://uptimerobot.com/ にアクセス
2. アカウント作成
3. 「Add New Monitor」をクリック
4. Monitor Type: HTTP(s)
5. Friendly Name: Minecraft Bot
6. URL: Replitの実行中のURL（画面上部に表示）
7. Monitoring Interval: 5分
8. 「Create Monitor」をクリック

これで5分ごとにBotにアクセスし、スリープを防ぎます。

---

## トラブルシューティング

### エラー: "Invalid token"

- `DISCORD_TOKEN`が正しいか確認
- Discord Developer Portalで新しいトークンを生成

### エラー: "Missing Access"

- Bot権限が正しく設定されているか確認
- BotをDiscordサーバーから削除して再度追加

### コマンドが表示されない

- Botがオンラインか確認（Replitで「Run」ボタンを押す）
- Discordを再起動
- 最大1時間待つ（コマンド登録に時間がかかる場合があります）

### Replitが「Run」ボタンを押しても起動しない

- `package.json`の内容が正しいか確認
- コンソールのエラーメッセージを確認
- 「Shell」タブで`npm install`を実行

### サーバーが起動しない

- Lambda URLが正しいか確認
- AWSコンソールでEC2インスタンスの状態を確認

---

## まとめ

完了すると以下が可能になります:

✅ Discord経由でMinecraftサーバー起動（`/serverstart`）
✅ Discord経由でMinecraftサーバー停止（`/serverstop`）
✅ サーバー状態確認（`/serverstatus`）
✅ 起動時に動的IPアドレスを自動通知
✅ 深夜3時に自動停止
✅ 15分間プレイヤー不在で自動停止

月額コスト: 約2,208円（AWS） + 無料（Replit）

---

## 方法2: ローカルPC（Windows）で動かす

### ステップ1: Node.jsをインストール

1. https://nodejs.org/ にアクセス
2. LTS版をダウンロードしてインストール

### ステップ2: プロジェクトフォルダを作成

```powershell
mkdir C:\minecraft-discord-bot
cd C:\minecraft-discord-bot
```

### ステップ3: package.jsonを作成

`C:\minecraft-discord-bot\package.json`を作成:

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
    "discord.js": "^14.14.1"
  }
}
```

### ステップ4: index.jsを作成

`C:\minecraft-discord-bot\index.js`を作成（上記のReplitと同じコード、ただしExpressは不要）:

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

console.log('Bot starting...');
```

### ステップ5: 依存関係をインストール

```powershell
cd C:\minecraft-discord-bot
npm install
```

### ステップ6: 環境変数を設定して起動

```powershell
$env:DISCORD_TOKEN="YOUR_BOT_TOKEN_HERE"
$env:CLIENT_ID="YOUR_CLIENT_ID_HERE"
$env:LAMBDA_START_URL="https://wxefluc2qfy2dd32czkvefeozi0yetwi.lambda-url.ap-northeast-1.on.aws/"
$env:LAMBDA_STOP_URL="https://hvyt42jkwftvbrxhepo27ikisa0xxwtw.lambda-url.ap-northeast-1.on.aws/"

npm start
```

**注意**: PCを再起動すると環境変数がリセットされるため、毎回設定が必要です。

---

## Discord Bot Token取得方法（共通）

### 1. Discord Developer Portalでアプリ作成

1. https://discord.com/developers/applications にアクセス
2. 「New Application」をクリック
3. アプリ名を入力（例: Minecraft Server Bot）
4. 「Create」をクリック

### 2. Botを作成

1. 左メニューから「Bot」を選択
2. 「Add Bot」をクリック（既にある場合はスキップ）
3. 「Reset Token」をクリックしてトークンをコピー
4. これが`DISCORD_TOKEN`です

### 3. Client IDを取得

1. 左メニューから「OAuth2」→「General」を選択
2. 「Client ID」をコピー
3. これが`CLIENT_ID`です

### 4. Bot権限を設定

1. 「OAuth2」→「URL Generator」を選択
2. Scopesで以下を選択：
   - `bot`
   - `applications.commands`
3. Bot Permissionsで以下を選択：
   - `Send Messages`
4. 生成されたURLをコピーしてブラウザで開く
5. Botを追加するサーバーを選択

---

## 推奨: Replit

- 無料で24時間稼働
- ブラウザだけで完結
- 設定が簡単

ローカルPCで動かす場合は、PCを常時起動しておく必要があります。
