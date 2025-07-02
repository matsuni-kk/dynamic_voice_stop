# dynamic_voice_stop

## 概要
Claude Code の Stop フックとして動作し、アシスタントの最新回答テキストを VOICEVOX ENGINE を通じて音声合成し、macOS の `afplay` で再生する Bash スクリプト `hooks/dynamic_voice_stop.sh` を提供します。音声で内容を確認したい場合に便利です。

## 特長
- VOICEVOX ENGINE (デフォルト http://127.0.0.1:50021) と連携し高品質な日本語音声を生成
- 軽量モードと UUID 検索モードを切り替え可能 (`UUID_MODE`)
- 読み上げ範囲を柔軟に制御する 5 つのモード (`READING_MODE`)
  - `first_line`   : 最初の改行まで
  - `line_limit`   : 指定行数まで (`MAX_LINES`)
  - `after_first`  : 2 行目以降を全文
  - `full_text`    : 改行をスペースに変換して全文
  - `char_limit`   : 指定文字数まで (`MAX_CHARS`)
- `bash ... config` で対話的に設定変更可能
- ログを `/tmp/voicestop_debug.log` に出力しデバッグ容易

## 必要環境
| ソフトウェア | 備考 |
|--------------|------|
| macOS | `afplay` が標準搭載 |
| VOICEVOX ENGINE | ポート `50021` で起動しておく |
| Bash 4 以降 | スクリプト実行環境 |
| `jq` | JSON パース用 |
| `curl` | HTTP 通信 |

## インストール
```bash
# リポジトリをクローン
git clone https://github.com/matsuni-kk/dynamic_voice_stop.git
cd dynamic_voice_stop
```

Claude Code プロジェクトに組み込む場合は、次のように `.claude/hooks` へリンクまたはコピーしてください。
```bash
mkdir -p ~/.claude/hooks
ln -s "$(pwd)/hooks/dynamic_voice_stop.sh" ~/.claude/hooks/dynamic_voice_stop.sh
```

## 使い方
### Claude Code Stop フックとして
1. `.claude/hooks/dynamic_voice_stop.sh` が存在することを確認
2. Claude Code の設定 (例: `project.json`) に Stop フックを登録
   ```json
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
3. Claude Code で通常どおり作業すると、アシスタント回答後に自動で読み上げます。

### 手動実行・設定変更
```bash
# 対話型設定ウィザード
bash hooks/dynamic_voice_stop.sh config

# JSON で設定コマンドを直接渡す例 (全文読み上げへ変更)
echo '{"config_command":"mode_full"}' | bash hooks/dynamic_voice_stop.sh
```

## 主な設定変数
| 変数 | 説明 | デフォルト |
|------|------|------------|
| `UUID_MODE` | UUID 単位で完全取得するか (true/false) | false |
| `READING_MODE` | 読み上げモード | "first_line" |
| `MAX_LINES` | `line_limit` モード時の行数上限 | 3 |
| `MAX_CHARS` | `char_limit` モード時の文字数上限 | 500 |
| `speaker` | VOICEVOX 話者 ID | 47 (ナースロボ_タイプT) |

変更は `config` サブコマンド、または JSON で `config_command` を渡して動的に適用可能です。

## テスト方法
VOICEVOX ENGINE を起動後、任意のテキストを読み上げる例:
```bash
echo '{"transcript_path":"/path/to/transcript.jsonl"}' | bash hooks/dynamic_voice_stop.sh
```
(実運用では Claude Code が自動で `transcript_path` を渡すため、手動入力は不要です。)

## ライセンス
MIT License

## 作者
[matsuni-kk](https://github.com/matsuni-kk)
