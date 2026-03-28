#!/usr/bin/env python3
"""共通認証モジュール: APIキー → ADC(Vertex AI) → エラー の3段階フォールバック"""

import os
import sys
from pathlib import Path


def load_env():
    """複数の .env ファイルから環境変数を読み込む"""
    env_paths = [
        Path(__file__).parent.parent / ".env",
        Path.home() / ".claude" / "skills" / ".env",
        Path.home() / ".claude" / ".env",
    ]
    for env_path in env_paths:
        if env_path.exists():
            try:
                with open(env_path) as f:
                    for line in f:
                        line = line.strip()
                        if not line or line.startswith("#") or "=" not in line:
                            continue
                        key, value = line.split("=", 1)
                        key = key.strip()
                        value = value.strip().strip("\"'")
                        if key and key not in os.environ:
                            os.environ[key] = value
            except Exception:
                continue


def create_client():
    """Gemini APIクライアントを作成する（3段階フォールバック）

    認証優先順位:
    1. APIキー (GEMINI_API_KEY or GOOGLE_API_KEY)
    2. ADC - Application Default Credentials (Vertex AI経由)
    3. エラー + セットアップガイダンス

    Returns:
        google.genai.Client: 認証済みクライアント
    """
    try:
        from google import genai
    except ImportError:
        print("エラー: google-genai パッケージがインストールされていません。")
        print("  pip install google-genai")
        sys.exit(1)

    # .envファイルから環境変数を読み込み
    load_env()

    # 1. APIキーで認証
    api_key = os.environ.get("GEMINI_API_KEY") or os.environ.get("GOOGLE_API_KEY")
    if api_key:
        return genai.Client(api_key=api_key)

    # 2. ADC (Vertex AI) で認証
    try:
        project = os.environ.get("GOOGLE_CLOUD_PROJECT")
        location = os.environ.get("GOOGLE_CLOUD_LOCATION", "us-central1")
        if project:
            return genai.Client(vertexai=True, project=project, location=location)
        # プロジェクトID自動検出を試行
        return genai.Client(vertexai=True)
    except Exception:
        pass

    # 3. エラー + ガイダンス
    print("エラー: Gemini API の認証情報が見つかりません。")
    print()
    print("以下のいずれかの方法で設定してください:")
    print()
    print("  方法1: APIキー (最も簡単、推奨)")
    print("    export GEMINI_API_KEY='your-key'")
    print("    # APIキー取得: https://aistudio.google.com/apikey")
    print()
    print("  方法2: .env ファイル")
    print("    echo 'GEMINI_API_KEY=your-key' >> ~/.claude/.env")
    print()
    print("  方法3: ADC (APIキー管理不要)")
    print("    gcloud auth application-default login")
    print("    export GOOGLE_CLOUD_PROJECT='your-project-id'")
    print("    # Vertex AI APIの有効化が必要")
    sys.exit(1)
