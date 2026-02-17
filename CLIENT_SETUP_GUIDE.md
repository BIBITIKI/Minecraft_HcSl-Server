# 🎮 Mine and Slash サーバー - クライアント環境構築ガイド

このサーバーで遊ぶために必要な準備を、初心者の方でもわかるように説明します。

---

## 📋 必要なもの

- Minecraft Java Edition（バージョン 1.20.1）
- 空き容量: 約5GB

---

## ステップ1️⃣: Minecraft Forge をインストール

Forgeは、MODを動かすために必要なツールです。

1. **Forgeをダウンロード**
   - <https://files.minecraftforge.net/net/minecraftforge/forge/index_1.20.1.html>
   - 「Installer」をクリックしてダウンロード
   - バージョン: **1.20.1-47.4.10** を選択

2. **Forgeをインストール**
   - ダウンロードした `.jar` ファイルをダブルクリック
   - 「Install client」を選択して「OK」をクリック
   - インストール完了まで待つ

3. **Minecraftランチャーで確認**
   - Minecraftランチャーを開く
   - 左下のプロファイル選択で「forge-1.20.1-47.4.10」が追加されていることを確認

---

## ステップ2️⃣: 必須MODをダウンロード

以下の7つのMODは**必ず**必要です。サーバーに接続できません。

### 📥 ダウンロードリンク

1. **Mine and Slash** (v6.3.14)
   <https://www.curseforge.com/minecraft/mc-mods/mine-and-slash-reloaded>

2. **Library of Exile** (v2.1.5)
   <https://www.curseforge.com/minecraft/mc-mods/library-of-exile>

3. **Dungeon Realm** (v1.1.7)
   <https://www.curseforge.com/minecraft/mc-mods/dungeon-realm>

4. **The Harvest** (v1.1.3)
   <https://www.curseforge.com/minecraft/mc-mods/the-harvest>

5. **Ancient Obelisks** (v1.2.3)
   <https://www.curseforge.com/minecraft/mc-mods/ancient-obelisks>

6. **Curios API** (v5.14.1)
   <https://www.curseforge.com/minecraft/mc-mods/curios>

7. **Player Animation Lib** (v1.0.2)
   <https://www.curseforge.com/minecraft/mc-mods/playeranimator>

### ⚠️ 注意点
- 各ページで「Files」タブを開く
- **1.20.1対応版**を選択してダウンロード
- ダウンロードボタンは右側にあります

---

## ステップ3️⃣: MODをインストール

1. **modsフォルダを開く**
   - Windowsキー + R を押す
   - `%appdata%\.minecraft` と入力してEnter
   - `mods` フォルダを開く（なければ作成）

2. **MODファイルを配置**
   - ダウンロードした7つの `.jar` ファイルを `mods` フォルダにコピー
   - ZIPファイルは解凍しないでください

---

## ステップ4️⃣: 日本語化リソースパックをダウンロード

アイテムやスキルの説明を日本語で表示するために必要です。

### 📥 ダウンロードリンク

以下のブログから各リソースパックをダウンロード:
<https://www.mine-blog.tech/mine-and-slash-6-3-x/>

1. **Mine and Slash 日本語化** (v6.3.8)
2. **Library of Exile 日本語化**
3. **Dungeon Realm 日本語化**
4. **The Harvest 日本語化**
5. **Ancient Obelisks 日本語化**

### 🎨 推奨テクスチャパック

**Alacrity** - RPG風の見た目になります（任意）
<https://www.curseforge.com/minecraft/texture-packs/alacrity>

---

## ステップ5️⃣: リソースパックをインストール

1. **resourcepacksフォルダを開く**
   - Windowsキー + R を押す
   - `%appdata%\.minecraft` と入力してEnter
   - `resourcepacks` フォルダを開く（なければ作成）

2. **リソースパックを配置**
   - ダウンロードした `.zip` ファイルを `resourcepacks` フォルダにコピー
   - 解凍しないでください

---

## ステップ6️⃣: Minecraftを起動して設定

1. **Forgeプロファイルで起動**
   - Minecraftランチャーを開く
   - 左下で「forge-1.20.1-47.4.10」を選択
   - 「プレイ」をクリック

2. **リソースパックを有効化**
   - メニューから「設定」→「リソースパック」を開く
   - 左側の利用可能なパックから、右側の選択中に移動
   - **順番が重要**: 上から順に
     1. Alacrity（入れた場合）
     2. Mine and Slash 日本語化
     3. Library of Exile 日本語化
     4. Dungeon Realm 日本語化
     5. The Harvest 日本語化
     6. Ancient Obelisks 日本語化
   - 「完了」をクリック

3. **MODが読み込まれたか確認**
   - メインメニューに「Mods」ボタンが表示されていればOK
   - クリックして7つのMODが表示されることを確認

---

## ステップ7️⃣: サーバーに接続

1. **サーバーアドレスを確認**
   - Discordの `#server-status` チャンネルで `/status` コマンドを実行
   - サーバーが停止中の場合は `/start` で起動

2. **マルチプレイに接続**
   - Minecraftのメインメニューから「マルチプレイ」を選択
   - 「サーバーを追加」をクリック
   - サーバー名: 好きな名前（例: Mine and Slash Server）
   - サーバーアドレス: Discordで確認したIPアドレス
   - 「完了」→ サーバーをダブルクリックして接続

---

## 🔧 推奨クライアント専用MOD（任意）

より快適にプレイするための追加MOD:

1. **JEI (Just Enough Items)** - レシピ確認
   <https://www.curseforge.com/minecraft/mc-mods/jei>

2. **JourneyMap** - マップ表示
   <https://www.curseforge.com/minecraft/mc-mods/journeymap>

3. **Embeddium** - パフォーマンス向上
   <https://www.curseforge.com/minecraft/mc-mods/embeddium>

4. **Loot Journal** - ドロップアイテム記録
   <https://www.curseforge.com/minecraft/mc-mods/loot-journal>

これらも `mods` フォルダに入れるだけで使えます。

---

## ❓ トラブルシューティング

### 接続できない場合
- サーバーが起動しているか確認（`/status` コマンド）
- 必須MOD 7つが全て入っているか確認
- Forgeバージョンが 1.20.1-47.4.10 か確認

### クラッシュする場合
- MODのバージョンが 1.20.1 対応か確認
- 他のMODと競合していないか確認（必須MOD以外を一旦削除）

### 日本語が表示されない場合
- リソースパックが有効化されているか確認
- リソースパックの順番を確認（Alacrity → 日本語化パック）

---

## 📞 サポート

わからないことがあれば、Discordの `#help` チャンネルで質問してください！

楽しいハクスラライフを！ 🎉
