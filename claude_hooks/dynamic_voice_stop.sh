#!/usr/bin/env bash
# ========================================
# Claude Code Stop Hook - 音声読み上げスクリプト
# ========================================
# 
# 概要: Claude Codeの Stop フックで呼び出され、最後のアシスタント回答を
#       VOICEVOXを使って音声で読み上げるスクリプト
#
# 依存関係:
#   - VOICEVOX ENGINE (http://127.0.0.1:50021)
#   - jq (JSON解析)
#   - afplay (macOS音声再生)
#   - curl (HTTP通信)
#
# 設定可能項目:
#   - UUID_MODE: UUID検索モード (true=全コンテンツ/false=軽量)
#   - READING_MODE: 読み上げ範囲 (first_line/after_first/full_text/char_limit)
#   - MAX_CHARS: 文字数制限値
#   - speaker: VOICEVOXの話者ID
#
# 使用方法:
#   - Claude Code の Stop フックとして自動実行
#   - 手動設定変更: bash voice_config.sh
#
# ログ出力: /tmp/voicestop_debug.log
# ========================================

# スクリプト実行設定
set -e                        # エラー発生時に即座に終了
read -r json || json="{}"     # stdin からJSONを読み取り（失敗時はデフォルト値）
speaker=47                    # VOICEVOX話者ID（ナースロボ＿タイプT）

# ========================================
# 設定変更コマンド処理（オプション機能）
# ========================================
# 
# 受信JSONに設定変更コマンドが含まれている場合、
# スクリプト自体の設定値を動的に変更する
#
# 対応コマンド:
#   uuid_on/uuid_off: UUID検索モードの切り替え
#   mode_first/mode_after/mode_full/mode_char: 読み上げモード変更
#   show_config: 現在の設定表示
#
# コマンドライン引数での設定変更チェック（スクリプト単体実行時）
if [[ $# -gt 0 ]]; then
    case "$1" in
        "config")
            echo "🎵 音声読み上げ設定変更"
            echo ""
            echo "📊 現在の設定:"
            grep -E "^(UUID_MODE|READING_MODE|MAX_CHARS|MAX_LINES)=" "$0"
            echo ""
            echo "変更したい項目を選択してください:"
            echo "1) UUID検索 ON/OFF"
            echo "2) 読み上げモード変更"
            echo "3) 行数制限値変更"
            echo "4) 文字数制限値変更"
            echo "5) 設定確認のみ"
            echo "6) 終了"
            read -p "選択 (1-6): " choice
            
            case $choice in
                1)
                    current_uuid=$(grep '^UUID_MODE=' "$0" | cut -d'=' -f2)
                    if [[ "$current_uuid" == "true" ]]; then
                        sed -i '' 's/^UUID_MODE=.*/UUID_MODE=false/' "$0"
                        echo "✅ UUID検索モード: OFF"
                    else
                        sed -i '' 's/^UUID_MODE=.*/UUID_MODE=true/' "$0"
                        echo "✅ UUID検索モード: ON"
                    fi
                    ;;
                2)
                    echo "読み上げモードを選択:"
                    echo "a) first_line: 最初の改行まで"
                    echo "b) line_limit: 指定行数まで"
                    echo "c) after_first: 改行後の内容"
                    echo "d) full_text: 全文読み上げ"
                    echo "e) char_limit: 文字数制限"
                    read -p "選択 (a-e): " mode_choice
                    case $mode_choice in
                        a) sed -i '' 's/^READING_MODE=.*/READING_MODE="first_line"/' "$0"; echo "✅ 最初の改行まで" ;;
                        b) sed -i '' 's/^READING_MODE=.*/READING_MODE="line_limit"/' "$0"; echo "✅ 行数制限" ;;
                        c) sed -i '' 's/^READING_MODE=.*/READING_MODE="after_first"/' "$0"; echo "✅ 改行後の内容" ;;
                        d) sed -i '' 's/^READING_MODE=.*/READING_MODE="full_text"/' "$0"; echo "✅ 全文読み上げ" ;;
                        e) sed -i '' 's/^READING_MODE=.*/READING_MODE="char_limit"/' "$0"; echo "✅ 文字数制限" ;;
                        *) echo "❌ 無効な選択" ;;
                    esac
                    ;;
                3)
                    current_lines=$(grep '^MAX_LINES=' "$0" | cut -d'=' -f2)
                    read -p "行数制限値を入力 (現在: $current_lines): " new_lines
                    if [[ "$new_lines" =~ ^[0-9]+$ ]] && [ "$new_lines" -gt 0 ]; then
                        sed -i '' "s/^MAX_LINES=.*/MAX_LINES=$new_lines/" "$0"
                        echo "✅ 行数制限: ${new_lines}行"
                    else
                        echo "❌ 無効な行数"
                    fi
                    ;;
                4)
                    current_chars=$(grep '^MAX_CHARS=' "$0" | cut -d'=' -f2)
                    read -p "文字数制限値を入力 (現在: $current_chars): " new_chars
                    if [[ "$new_chars" =~ ^[0-9]+$ ]] && [ "$new_chars" -gt 0 ]; then
                        sed -i '' "s/^MAX_CHARS=.*/MAX_CHARS=$new_chars/" "$0"
                        echo "✅ 文字数制限: ${new_chars}文字"
                    else
                        echo "❌ 無効な文字数"
                    fi
                    ;;
                5)
                    echo "📊 詳細設定:"
                    grep -E "^(UUID_MODE|READING_MODE|MAX_CHARS|MAX_LINES)=" "$0"
                    ;;
                6)
                    echo "👋 終了"
                    ;;
                *)
                    echo "❌ 無効な選択"
                    ;;
            esac
            exit 0
            ;;
    esac
fi

config_command=$(echo "$json" | jq -r '.config_command // empty' 2>/dev/null || echo "")
if [[ -n "$config_command" ]]; then
    case "$config_command" in
        "uuid_on") 
            # UUID検索モードを有効化（全コンテンツ取得・重い処理）
            sed -i '' 's/^UUID_MODE=.*/UUID_MODE=true/' "$0"
            echo "✅ UUID検索モード: ON" >&2
            exit 0 ;;
        "uuid_off") 
            # UUID検索モードを無効化（軽量・高速処理）
            sed -i '' 's/^UUID_MODE=.*/UUID_MODE=false/' "$0"
            echo "✅ UUID検索モード: OFF" >&2
            exit 0 ;;
        "mode_first") 
            # 読み上げモード: 最初の改行まで
            sed -i '' 's/^READING_MODE=.*/READING_MODE="first_line"/' "$0"
            echo "✅ 読み上げモード: 最初の改行まで" >&2
            exit 0 ;;
        "mode_after") 
            # 読み上げモード: 改行後の内容のみ
            sed -i '' 's/^READING_MODE=.*/READING_MODE="after_first"/' "$0"
            echo "✅ 読み上げモード: 改行後の内容" >&2
            exit 0 ;;
        "mode_full") 
            # 読み上げモード: 全文読み上げ
            sed -i '' 's/^READING_MODE=.*/READING_MODE="full_text"/' "$0"
            echo "✅ 読み上げモード: 全文読み上げ" >&2
            exit 0 ;;
        "mode_line") 
            # 読み上げモード: 行数制限
            sed -i '' 's/^READING_MODE=.*/READING_MODE="line_limit"/' "$0"
            echo "✅ 読み上げモード: 行数制限" >&2
            exit 0 ;;
        "mode_char") 
            # 読み上げモード: 文字数制限
            sed -i '' 's/^READING_MODE=.*/READING_MODE="char_limit"/' "$0"
            echo "✅ 読み上げモード: 文字数制限" >&2
            exit 0 ;;
        "show_config")
            # 現在の設定を表示
            echo "📊 現在の設定:" >&2
            grep -E "^(UUID_MODE|READING_MODE|MAX_CHARS|MAX_LINES)=" "$0" >&2
            exit 0 ;;
    esac
fi

# ========================================
# デバッグログ出力
# ========================================
echo "🔧 voicestop.sh が呼び出されました $(date)" >> /tmp/voicestop_debug.log
echo "🔧 受信JSON: $json" >> /tmp/voicestop_debug.log

# ========================================
# ① transcript ファイルの取得・検証
# ========================================
# 
# Claude Code の Stop フックから transcript_path を取得
# 提供されない場合は最新のセッションファイルを自動検索
#

# JSONから transcript_path を抽出
path=$(jq -r '.transcript_path // empty' <<<"$json" 2>/dev/null || echo "")

# transcript_path が提供されない場合は最新ファイルを検索
if [[ -z "$path" ]] || [[ "$path" == "null" ]]; then
    echo "🔧 transcript_pathが提供されないため、最新ファイルを検索します" >> /tmp/voicestop_debug.log
    # ~/.claude/projects から最新の .jsonl ファイルを検索
    path=$(find ~/.claude/projects -name "*.jsonl" -type f -exec ls -t {} + 2>/dev/null | head -1)
    echo "🔧 検出したファイル: $path" >> /tmp/voicestop_debug.log
fi

# transcript ファイルの存在確認
if [[ -z "$path" ]] || [[ ! -f "$path" ]]; then
    echo "⚠️ transcript file not found or empty: '$path'" >&2
    echo "🔧 ファイルが見つかりません: $path" >> /tmp/voicestop_debug.log
    exit 0  # 正常終了（ファイルが見つからない場合もエラーとしない）
fi

# ========================================
# ② アシスタントメッセージのテキスト抽出
# ========================================
# 
# 2つのモードでテキスト取得を行う:
# 1. UUID検索モード: 完全なメッセージ取得（重い・正確）
# 2. 軽量モード: 最初のテキストのみ取得（軽い・高速）
#

if [ "$UUID_MODE" = true ]; then
    # ========================================
    # UUID検索モード（全コンテンツ取得・重い処理）
    # ========================================
    # 
    # 最新のassistantメッセージのUUIDを特定し、
    # そのUUIDに関連する全てのレコードからテキストを抽出・結合
    #
    echo "🔧 UUID検索モード使用" >> /tmp/voicestop_debug.log
    
    if command -v tac >/dev/null 2>&1; then
        # Linux: tac コマンドでファイルを逆順読み込み
        latest_uuid=$(tac "$path" | jq -r 'select(.type == "assistant") | .uuid' 2>/dev/null | head -n 1)
        text=$(tac "$path" | jq -r --arg uuid "$latest_uuid" 'select(.uuid == $uuid and .message.role == "assistant") | .message.content[]? | select(.type == "text") | .text' 2>/dev/null | paste -sd ' ' -)
    else
        # macOS: tail -r コマンドでファイルを逆順読み込み  
        latest_uuid=$(tail -r "$path" | jq -r 'select(.type == "assistant") | .uuid' 2>/dev/null | head -n 1)
        text=$(tail -r "$path" | jq -r --arg uuid "$latest_uuid" 'select(.uuid == $uuid and .message.role == "assistant") | .message.content[]? | select(.type == "text") | .text' 2>/dev/null | paste -sd ' ' -)
    fi
    echo "🔧 検出したUUID: $latest_uuid" >> /tmp/voicestop_debug.log
else
    # ========================================
    # 軽量モード（最初のtextのみ・高速）
    # ========================================
    # 
    # 最新のassistantメッセージの最初のtextコンテンツのみ取得
    # 処理速度重視、複数のテキストブロックがあっても最初の1つのみ
    #
    echo "🔧 軽量モード使用" >> /tmp/voicestop_debug.log
    
    if command -v tac >/dev/null 2>&1; then
        # Linux: tac + jq + head で最初のテキストを取得
        text=$(tac "$path" | jq -r 'select(.type == "assistant") | .message.content[]? | select(.type == "text") | .text' 2>/dev/null | head -n 1)
    else
        # macOS: tail -r + jq + head で最初のテキストを取得
        text=$(tail -r "$path" | jq -r 'select(.type == "assistant") | .message.content[]? | select(.type == "text") | .text' 2>/dev/null | head -n 1)
    fi
fi

echo "🔧 取得したテキスト長: ${#text}" >> /tmp/voicestop_debug.log

# ========================================
# テキスト取得結果の検証
# ========================================
if [[ -z "$text" || "$text" == "null" ]]; then
    echo "⚠️ No assistant message found in transcript" >&2
    exit 0  # 非ブロッキング終了（エラーとして扱わない）
fi

# ========================================
# ③ 読み上げ設定値（ユーザーカスタマイズ可能）
# ========================================
UUID_MODE=false            # UUID検索モード（false=軽量、true=全コンテンツ取得）
READING_MODE="first_line"  # 読み上げモード（後述の5種類から選択）
MAX_CHARS=500              # 文字数制限モード時の最大文字数
MAX_LINES=3                # 行数制限モード時の最大行数

# ========================================
# 読み上げモード詳細説明
# ========================================
# first_line:  最初の改行まで（初期値・高速・推奨）
#              - 長い回答の概要のみ読み上げ
#              - 処理速度最優先
#
# line_limit:  指定行数まで読み上げ（NEW!）
#              - MAX_LINES 設定値の行数まで読み上げ
#              - 概要＋詳細の適度なバランス
#
# after_first: 改行後の内容のみ
#              - 概要行をスキップして詳細部分を読み上げ
#              - 説明文の本文のみ聞きたい場合
#
# full_text:   全文読み上げ（改行をスペースに変換）
#              - 完全な内容を全て読み上げ
#              - 時間がかかるが情報は完全
#
# char_limit:  指定文字数で切断
#              - MAX_CHARS 設定値まで読み上げ
#              - 時間制御したい場合

# ========================================
# ④ 読み上げ範囲の処理実行
# ========================================
case "$READING_MODE" in
    "first_line")
        # 最初の改行まで（初期値・高速）
        text=$(echo "$text" | head -n 1)
        echo "🔧 読み上げモード: 最初の改行まで" >> /tmp/voicestop_debug.log
        ;;
    "line_limit")
        # 指定行数まで読み上げ（head -n N で N行まで取得）
        text=$(echo "$text" | head -n $MAX_LINES | tr '\n' ' ')
        echo "🔧 読み上げモード: ${MAX_LINES}行制限" >> /tmp/voicestop_debug.log
        ;;
    "after_first")
        # 改行後の内容のみ（tail -n +2 で2行目以降を取得）
        text=$(echo "$text" | tail -n +2 | tr '\n' ' ')
        echo "🔧 読み上げモード: 改行後の内容" >> /tmp/voicestop_debug.log
        ;;
    "full_text")
        # 全文読み上げ（改行をスペースに変換して1行にまとめる）
        text=$(echo "$text" | tr '\n' ' ')
        echo "🔧 読み上げモード: 全文読み上げ" >> /tmp/voicestop_debug.log
        ;;
    "char_limit")
        # 指定文字数で切断（cut -c1-N で N文字まで取得）
        text=$(echo "$text" | tr '\n' ' ' | cut -c1-$MAX_CHARS)
        echo "🔧 読み上げモード: ${MAX_CHARS}文字制限" >> /tmp/voicestop_debug.log
        ;;
    *)
        # 無効なモード指定時のフォールバック（first_line と同じ処理）
        text=$(echo "$text" | head -n 1)
        echo "🔧 読み上げモード: デフォルト（最初の改行まで）" >> /tmp/voicestop_debug.log
        ;;
esac

# 処理結果をログに記録
echo "🔧 処理後テキスト長: ${#text}文字" >> /tmp/voicestop_debug.log

# 最終的な読み上げテキストを表示（デバッグ用）
echo "📢 読み上げテキスト: $text" >&2

# ========================================
# ⑤ VOICEVOX ENGINE 接続確認
# ========================================
# 
# VOICEVOX ENGINE が起動しているかチェック
# ポート 50021 で /version エンドポイントへの接続を確認
#
if ! curl -s "http://127.0.0.1:50021/version" >/dev/null 2>&1; then
    echo "⚠️ VOICEVOX ENGINE が起動していません (http://127.0.0.1:50021)" >&2
    echo "VOICEVOXアプリを起動してから再実行してください" >&2
    exit 0  # 非ブロッキング終了（サービス未起動は正常ケース）
fi

# ========================================
# ⑥ VOICEVOX ENGINE へ音声クエリ生成
# ========================================
# 
# テキストと話者IDを指定して音声合成用のクエリを生成
# 生成されたクエリJSONは次のステップで音声合成に使用
#
query_json=$(mktemp)  # 一時ファイル作成
if ! curl -s -X POST "http://127.0.0.1:50021/audio_query?speaker=$speaker" \
     --get --data-urlencode "text=$text" -o "$query_json"; then
    echo "⚠️ VOICEVOX ENGINE へのクエリ生成に失敗しました" >&2
    rm -f "$query_json"  # 一時ファイル削除
    exit 0  # 非ブロッキング終了
fi

# ========================================
# ⑦ 音声合成実行
# ========================================
# 
# 生成されたクエリJSONを使用して実際の音声ファイル（WAV形式）を生成
# 合成された音声データは一時ファイルに保存
#
wave_file=$(mktemp).wav  # 音声ファイル用一時ファイル作成
if ! curl -s -H 'Content-Type: application/json' \
     -d @"$query_json" \
     "http://127.0.0.1:50021/synthesis?speaker=$speaker" -o "$wave_file"; then
    echo "⚠️ 音声合成に失敗しました" >&2
    rm -f "$query_json" "$wave_file"  # 一時ファイル削除
    exit 0  # 非ブロッキング終了
fi

# ========================================
# ⑧ 音声ファイル再生
# ========================================
# 
# 生成された音声ファイルをmacOS標準のafplayコマンドで再生
# バックグラウンド実行で非同期再生、一定時間後に一時ファイルを自動削除
#
if command -v afplay >/dev/null 2>&1; then
    echo "🔊 音声を再生中..." >&2
    afplay "$wave_file" &  # バックグラウンドで再生開始
    
    # 10秒後に一時ファイルを削除（バックグラウンドで実行）
    (sleep 10; rm -f "$query_json" "$wave_file") &
else
    # afplayコマンドが見つからない場合（通常はmacOSなら存在する）
    echo "⚠️ afplayコマンドが見つかりません（macOS標準のはずですが...）" >&2
    rm -f "$query_json" "$wave_file"  # 一時ファイル削除
    exit 0  # 非ブロッキング終了
fi

echo "✅ 音声読み上げ完了" >&2 