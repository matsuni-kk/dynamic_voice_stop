# Dynamic Voice Stop

## 概要
Claude Code の Stop フックとして動作し、アシスタントの最新回答テキストを **VOICEVOX ENGINE** または **AivisSpeech** を通じて音声合成し、macOS の `afplay` で再生する高機能 Bash スクリプトです。音声で内容を確認したい場合に便利で、柔軟な設定変更機能を備えています。

## 🎯 主な特長

### 🎤 マルチエンジン対応
- **VOICEVOX ENGINE** (http://127.0.0.1:50021) - 高品質な日本語音声合成
- **AivisSpeech** (http://127.0.0.1:10101) - 多様な話者を提供する音声合成エンジン
- 自動エンジン検出機能により、利用可能なエンジンを自動選択
- エンジン優先順位の設定可能（`ENGINE_PRIORITY`）

### 🎭 豊富な話者選択
#### VOICEVOX話者
- デフォルト: `47` (ナースロボ＿タイプT)
- その他多数の話者に対応

#### AivisSpeech話者
- `888753760` - Anneli ノーマル（デフォルト）
- `888753761` - Anneli 通常
- `888753762` - Anneli テンション高め
- `888753763` - Anneli 落ち着き
- `888753764` - Anneli 上機嫌
- `888753765` - Anneli 怒り・悲しみ
- `606865152` - fumifumi
- `933744512` - peach
- `706073888` - white
- `1431611904` - まい
- `376644064` - 桜音
- `1325133120` - 花音

### 📖 柔軟な読み上げ制御
- **軽量モード** と **UUID検索モード** の切り替え可能
- 5つの読み上げモード：
  - `first_line` : 最初の改行まで（高速・推奨）
  - `line_limit` : 指定行数まで（`MAX_LINES`）
  - `after_first` : 2行目以降を全文
  - `full_text` : 改行をスペースに変換して全文
  - `char_limit` : 指定文字数まで（`MAX_CHARS`）

### ⚙️ 高度な設定機能
- 対話型設定ウィザード（`bash hooks/dynamic_voice_stop.sh config`）
- JSON コマンドによる動的設定変更
- デバッグログ出力（`/tmp/voicestop_debug.log`）

## 🛠️ 必要環境

| ソフトウェア | 用途 | 備考 |
|--------------|------|------|
| **macOS** | 音声再生 | `afplay` が標準搭載 |
| **VOICEVOX ENGINE** または **AivisSpeech** | 音声合成 | どちらか一方でも可 |
| **Bash 4+** | スクリプト実行 | macOS標準のBashで動作 |
| **jq** | JSON解析 | `brew install jq` |
| **curl** | HTTP通信 | macOS標準搭載 |

### 音声エンジンのセットアップ

#### VOICEVOX ENGINE
```bash
# VOICEVOX ENGINEをダウンロード・起動
# https://voicevox.hiroshiba.jp/ からダウンロード
# デフォルトポート: 50021
```

#### AivisSpeech
```bash
# AivisSpeechをダウンロード・起動
# https://aivis-project.com/ からダウンロード
# デフォルトポート: 10101
```

## 📦 インストール

```bash
# リポジトリをクローン
git clone https://github.com/matsuni-kk/dynamic_voice_stop.git
cd dynamic_voice_stop

# Claude Code プロジェクトに組み込み
mkdir -p ~/.claude/hooks
ln -s "$(pwd)/hooks/dynamic_voice_stop.sh" ~/.claude/hooks/dynamic_voice_stop.sh

# 実行権限を付与
chmod +x hooks/dynamic_voice_stop.sh
```

## 🚀 使い方

### Claude Code Stop フックとして使用

1. **フック設定ファイルの作成**
   ```json
   // .claude/hooks/settings.json
   {
     "hooks": {
       "Stop": [
         {
           "matcher": "",
           "hooks": [
             {
               "type": "command",
               "command": ".claude/hooks/dynamic_voice_stop.sh"
             }
           ]
         }
       ]
     }
   }
   ```

2. **自動実行**
   - Claude Code で通常どおり作業
   - アシスタント回答後に自動で音声読み上げが開始

### 手動設定・テスト

#### 対話型設定ウィザード
```bash
bash hooks/dynamic_voice_stop.sh config
```

設定メニュー：
1. UUID検索 ON/OFF
2. 読み上げモード変更
3. 行数制限値変更
4. 文字数制限値変更
5. 音声エンジン優先順位変更
6. 設定確認のみ

#### JSON コマンドによる設定変更
```bash
# 全文読み上げモードに変更
echo '{"config_command":"mode_full"}' | bash hooks/dynamic_voice_stop.sh

# AivisSpeechを優先エンジンに設定
echo '{"config_command":"engine_aivisspeech"}' | bash hooks/dynamic_voice_stop.sh

# UUID検索モードを有効化
echo '{"config_command":"uuid_on"}' | bash hooks/dynamic_voice_stop.sh

# 現在の設定を表示
echo '{"config_command":"show_config"}' | bash hooks/dynamic_voice_stop.sh
```

## ⚙️ 設定変数詳細

| 変数名 | 説明 | デフォルト値 | 選択肢 |
|--------|------|-------------|--------|
| `UUID_MODE` | UUID検索モード | `false` | `true`/`false` |
| `READING_MODE` | 読み上げモード | `"first_line"` | `first_line`/`line_limit`/`after_first`/`full_text`/`char_limit` |
| `MAX_LINES` | 行数制限値 | `3` | 正の整数 |
| `MAX_CHARS` | 文字数制限値 | `500` | 正の整数 |
| `ENGINE_PRIORITY` | エンジン優先順位 | `"voicevox"` | `voicevox`/`aivisspeech` |
| `VOICEVOX_SPEAKER` | VOICEVOX話者ID | `47` | 話者ID |
| `AIVISSPEECH_SPEAKER` | AivisSpeech話者ID | `888753760` | 話者ID |

### 読み上げモード詳細

| モード | 説明 | 用途 |
|--------|------|------|
| `first_line` | 最初の改行まで | 高速・概要確認 |
| `line_limit` | 指定行数まで | 適度な詳細レベル |
| `after_first` | 2行目以降 | 概要をスキップ |
| `full_text` | 全文読み上げ | 完全な情報取得 |
| `char_limit` | 指定文字数まで | 時間制御 |

## 🧪 テスト方法

### 基本テスト
```bash
# 音声エンジンの接続確認
curl -s "http://127.0.0.1:50021/version"  # VOICEVOX
curl -s "http://127.0.0.1:10101/speakers"  # AivisSpeech

# スクリプトの動作テスト
echo '{"transcript_path":"/path/to/transcript.jsonl"}' | bash hooks/dynamic_voice_stop.sh
```

### 設定テスト
```bash
# 各読み上げモードのテスト
echo '{"config_command":"mode_first"}' | bash hooks/dynamic_voice_stop.sh
echo '{"config_command":"mode_full"}' | bash hooks/dynamic_voice_stop.sh
echo '{"config_command":"mode_char"}' | bash hooks/dynamic_voice_stop.sh

# エンジン切り替えテスト
echo '{"config_command":"engine_voicevox"}' | bash hooks/dynamic_voice_stop.sh
echo '{"config_command":"engine_aivisspeech"}' | bash hooks/dynamic_voice_stop.sh
```

## 🐛 トラブルシューティング

### よくある問題

1. **音声エンジンが見つからない**
   ```
   ⚠️ 利用可能な音声エンジンが見つかりません
   ```
   → VOICEVOX ENGINE または AivisSpeech を起動してください

2. **transcript ファイルが見つからない**
   ```
   ⚠️ transcript file not found
   ```
   → Claude Code の設定を確認してください

3. **音声合成に失敗**
   ```
   ⚠️ 音声合成に失敗しました
   ```
   → デバッグログ（`/tmp/voicestop_debug.log`）を確認してください

### デバッグ方法
```bash
# デバッグログの確認
tail -f /tmp/voicestop_debug.log

# 現在の設定確認
grep -E "^(UUID_MODE|READING_MODE|MAX_CHARS|MAX_LINES|ENGINE_PRIORITY)=" hooks/dynamic_voice_stop.sh
```

## 🔄 アップデート履歴

### v2.0.0 (最新)
- **AivisSpeech対応** - 新しい音声エンジンのサポート
- **マルチエンジン自動検出** - 利用可能なエンジンを自動選択
- **豊富な話者選択** - AivisSpeechで10種類以上の話者をサポート
- **エンジン優先順位設定** - 使用するエンジンの優先順位を設定可能
- **設定機能の拡張** - より詳細な設定変更オプション

### v1.0.0
- VOICEVOX ENGINE対応
- 基本的な読み上げ機能
- 5つの読み上げモード

## 📄 ライセンス
MIT License

## 👨‍💻 作者
[matsuni-kk](https://github.com/matsuni-kk)
