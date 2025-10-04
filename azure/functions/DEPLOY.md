# Azure Functions デプロイメントガイド

## 前提条件

1. Azure CLI がインストールされている
2. Azure Functions Core Tools v4 がインストールされている
3. Python 3.10+ がインストールされている
4. Azure サブスクリプションにアクセス権がある

## 1. Azure リソースの作成

```bash
# プロビジョニングスクリプトを実行
cd azure/functions/scripts
chmod +x provision.sh
./provision.sh
```

このスクリプトは以下を作成します：
- リソースグループ
- Storage Account + Blob Container
- Document Intelligence (Form Recognizer)
- Function App (Python/Linux/Consumption)

## 2. Azure OpenAI の設定

Azure Portal で Azure OpenAI リソースを作成し、以下を設定：

1. Azure OpenAI リソースを作成
2. GPT-4o モデルをデプロイ（デプロイメント名: `gpt-4o`）
3. Function App の設定に追加：

```bash
FUNCTION_APP_NAME="your-function-app-name"
OPENAI_ENDPOINT="https://your-openai.openai.azure.com/"
OPENAI_KEY="your-openai-key"

az functionapp config appsettings set \
  -g koereq-ocr-rg -n $FUNCTION_APP_NAME \
  --settings \
  AZURE_OPENAI_ENDPOINT="$OPENAI_ENDPOINT" \
  AZURE_OPENAI_KEY="$OPENAI_KEY"
```

## 3. Functions のデプロイ

```bash
# プロジェクトディレクトリに移動
cd azure/functions

# Python 仮想環境の作成（推奨）
python -m venv .venv
source .venv/bin/activate  # macOS/Linux
# .venv\Scripts\activate  # Windows

# 依存関係のインストール
pip install -r requirements.txt

# Azure にログイン
az login

# デプロイ
func azure functionapp publish your-function-app-name
```

## 4. デプロイ後の確認

### Function URLs の確認

```bash
# Function App の URL を取得
az functionapp show -g koereq-ocr-rg -n your-function-app-name --query defaultHostName -o tsv
```

エンドポイント:
- `POST https://your-function-app.azurewebsites.net/api/issueUploadUrls`
- `POST https://your-function-app.azurewebsites.net/api/analyzeDocument`
- `POST https://your-function-app.azurewebsites.net/api/processText`

### Function Key の取得

```bash
# Function の認証キーを取得
az functionapp keys list -g koereq-ocr-rg -n your-function-app-name
```

### テスト用のリクエスト例

```bash
# SAS URL の発行テスト
curl -X POST https://your-function-app.azurewebsites.net/api/issueUploadUrls \
  -H "Content-Type: application/json" \
  -H "x-functions-key: YOUR_FUNCTION_KEY" \
  -d '{"count": 1}'
```

## 5. iOS アプリの設定更新

取得した情報を iOS アプリの Info.plist に設定：

```xml
<key>AZURE_FUNCTIONS_BASE_URL</key>
<string>https://your-function-app.azurewebsites.net/api</string>
<key>AZURE_FUNCTIONS_KEY</key>
<string>your-function-key</string>
<key>AZURE_OPENAI_DEPLOYMENT</key>
<string>gpt-4o</string>
```

## トラブルシューティング

### よくある問題

1. **Function Key が見つからない**
   ```bash
   # マスターキーを使用
   az functionapp keys list -g koereq-ocr-rg -n your-function-app-name --query masterKey -o tsv
   ```

2. **CORS エラー**
   ```bash
   # CORS を設定（開発時のみ）
   az functionapp cors add -g koereq-ocr-rg -n your-function-app-name --allowed-origins "*"
   ```

3. **ログの確認**
   ```bash
   # リアルタイムログ
   func azure functionapp logstream your-function-app-name
   ```

### 環境変数の確認

```bash
# Function App の設定を確認
az functionapp config appsettings list -g koereq-ocr-rg -n your-function-app-name
```

必要な設定:
- `AZURE_STORAGE_ACCOUNT`
- `AZURE_STORAGE_KEY`
- `AZURE_STORAGE_CONTAINER`
- `AZURE_DI_ENDPOINT`
- `AZURE_DI_KEY`
- `AZURE_OPENAI_ENDPOINT`
- `AZURE_OPENAI_KEY`