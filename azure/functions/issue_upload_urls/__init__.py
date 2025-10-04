import json
import logging
import azure.functions as func
from typing import List
from uuid import uuid4
from datetime import datetime, timedelta
from azure.storage.blob import (
    BlobServiceClient,
    generate_blob_sas,
    BlobSasPermissions,
)
from ..shared import get_env
from ..function_app import app


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
