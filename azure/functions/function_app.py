import json
import logging
import azure.functions as func
from typing import List, Optional
from uuid import uuid4
from datetime import datetime, timedelta
from azure.storage.blob import (
    BlobServiceClient,
    generate_blob_sas,
    BlobSasPermissions,
)
from azure.ai.documentintelligence import DocumentIntelligenceClient
from azure.core.credentials import AzureKeyCredential
# openai imported locally in processText function
from shared import get_env

# Single FunctionApp instance for all functions in this project
app = func.FunctionApp(http_auth_level=func.AuthLevel.FUNCTION)


@app.function_name(name="issueUploadUrls")
@app.route(route="issueUploadUrls", methods=["POST"])
def issue_upload_urls(req: func.HttpRequest) -> func.HttpResponse:
    try:
        payload = req.get_json()
    except ValueError:
        return func.HttpResponse("invalid json", status_code=400)

    count = int(payload.get("count", 0))
    if count <= 0 or count > 20:
        return func.HttpResponse("invalid count", status_code=400)

    account = get_env("AZURE_STORAGE_ACCOUNT")
    key = get_env("AZURE_STORAGE_KEY")
    container = get_env("AZURE_STORAGE_CONTAINER")

    service = BlobServiceClient(
        account_url=f"https://{account}.blob.core.windows.net",
        credential=key,
    )
    try:
        service.create_container(container)
    except Exception:
        pass

    expire = datetime.utcnow() + timedelta(minutes=10)
    results: List[str] = []
    for _ in range(count):
        blob_name = f"{uuid4().hex}.jpg"
        # Grant read+write+create so client can PUT and DI can read later
        sas = generate_blob_sas(
            account_name=account,
            container_name=container,
            blob_name=blob_name,
            account_key=key,
            permission=BlobSasPermissions(read=True, write=True, create=True),
            expiry=expire,
            content_type="image/jpeg",
        )
        url = f"https://{account}.blob.core.windows.net/{container}/{blob_name}?{sas}"
        results.append(url)

    return func.HttpResponse(
        body=json.dumps(results),
        status_code=200,
        mimetype="application/json",
    )


@app.function_name(name="analyzeDocument")
@app.route(route="analyzeDocument", methods=["POST"])
def analyze_document(req: func.HttpRequest) -> func.HttpResponse:
    try:
        payload = req.get_json()
    except ValueError:
        return func.HttpResponse("invalid json", status_code=400)

    urls = payload.get("urls", [])
    if not isinstance(urls, list) or not urls:
        return func.HttpResponse("missing urls", status_code=400)

    endpoint = get_env("AZURE_DI_ENDPOINT")
    key = get_env("AZURE_DI_KEY")
    client = DocumentIntelligenceClient(endpoint=endpoint, credential=AzureKeyCredential(key))

    text_blocks: List[str] = []

    for u in urls:
        try:
            # azure-ai-documentintelligence v1.x expects a request body, not url_source kwarg
            from azure.ai.documentintelligence.models import AnalyzeDocumentRequest
            body = AnalyzeDocumentRequest(url_source=u)
            poller = client.begin_analyze_document(
                model_id="prebuilt-read",
                body=body,
            )
            result = poller.result()
            # Aggregate lines
            for page in result.pages or []:
                for line in page.lines or []:
                    if line.content:
                        text_blocks.append(line.content)
        except Exception as e:
            logging.exception("analyze failed for %s", u)
            return func.HttpResponse(f"analyze error: {e}", status_code=500)

    resp = {"textBlocks": text_blocks, "tables": [], "checkboxes": []}
    return func.HttpResponse(
        body=json.dumps(resp, ensure_ascii=False),
        status_code=200,
        mimetype="application/json",
    )


@app.function_name(name="processText")
@app.route(route="processText", methods=["POST"])
def process_text(req: func.HttpRequest) -> func.HttpResponse:
    # Parse request
    try:
        payload = req.get_json()
    except ValueError:
        return func.HttpResponse("invalid json", status_code=400)

    ocr_text = payload.get("ocrText", "")
    doc_type = payload.get("documentType", "一般テキスト")
    custom_prompt = payload.get("customPrompt")
    deployment = payload.get("deployment")
    if not deployment:
        return func.HttpResponse("missing deployment", status_code=400)

    # Build prompt
    system = (
        "あなたは医療文書を正確に構造化するアシスタントです。"
        "OCRテキストを読みやすく整理し、必要な情報を適切に抽出してください。"
        "出力は読みやすい日本語テキストで、見出しや箇条書きを適宜用いてください。"
    )

    # Document type specific prompts
    type_prompts = {
        "紹介状": """
        以下のOCRテキストは医療機関の紹介状です。以下の項目を抽出し、構造化して出力してください：

        【基本情報】
        - 紹介先医療機関名
        - 紹介元医療機関名・医師名
        - 患者氏名・年齢・性別
        - 紹介日

        【症状・所見】
        - 主訴
        - 現病歴
        - 既往歴
        - 家族歴
        - 身体所見・検査結果

        【紹介理由・依頼事項】
        - 紹介目的
        - 検査依頼項目
        - 治療依頼事項

        不明な項目は「記載なし」として出力してください。
        """,
        "お薬手帳": """
        以下のOCRテキストはお薬手帳の記録です。薬剤情報を以下の形式で構造化して出力してください：

        【処方情報】
        - 処方日：
        - 医療機関名：
        - 医師名：

        【薬剤一覧】
        各薬剤について以下の形式で出力：
        1. 薬品名（商品名・一般名）
           - 用量：〇〇mg/錠
           - 用法：1日〇回、〇錠ずつ
           - 服用時間：朝食後、夕食後など
           - 処方日数：〇日分
           - 効能・効果：

        【注意事項】
        - 薬剤師からの指導内容
        - 副作用情報
        - その他の注意点

        不明な項目は「記載なし」として出力してください。
        """,
        "一般テキスト": """
        以下のOCRテキストを読みやすく整形してください：

        1. 文章の構造を分析し、適切な段落に分割
        2. 箇条書きや番号付きリストがあれば適切にフォーマット
        3. 日付、数値、固有名詞の誤認識を可能な限り修正
        4. 文脈に合わない文字や記号を除去
        5. 適切な句読点を補完

        元のテキストの意味を変えることなく、読みやすい形式で出力してください。
        """
    }

    # Use custom prompt if provided, otherwise use type-specific prompt
    if custom_prompt:
        user_prompt = f"{custom_prompt}\n\n以下のOCRテキストを処理してください:\n\n{ocr_text}"
    else:
        type_prompt = type_prompts.get(doc_type, type_prompts["一般テキスト"])
        user_prompt = f"{type_prompt}\n\n{ocr_text}"

    # Call Azure OpenAI with robust error handling
    try:
        from openai import AzureOpenAI
        endpoint = get_env("AZURE_OPENAI_ENDPOINT").rstrip('/')
        client = AzureOpenAI(
            api_key=get_env("AZURE_OPENAI_KEY"),
            api_version="2024-08-01-preview",
            azure_endpoint=endpoint
        )

        resp = client.chat.completions.create(
            model=deployment,
            messages=[
                {"role": "system", "content": system},
                {"role": "user", "content": user_prompt},
            ],
        )
        text = resp.choices[0].message.content if resp.choices else ""
        return func.HttpResponse(text, status_code=200, mimetype="text/plain; charset=utf-8")
    except Exception as e:
        # Return detailed error to help client diagnostics
        err = {"error": "openai", "message": str(e)}
        return func.HttpResponse(json.dumps(err, ensure_ascii=False), status_code=500, mimetype="application/json")
