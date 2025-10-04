Azure Functions Backend for KoEReq OCR

Overview
- Provides three HTTP endpoints expected by the iOS app:
  - POST /issueUploadUrls → returns SAS URLs for JPEG PUT and later DI read
  - POST /analyzeDocument → runs Azure Document Intelligence Read to extract text
  - POST /processText → calls Azure OpenAI with document-type prompt

Quick Start (CLI)
1) Prereqs
   - Azure CLI: az login
   - Python 3.10+, Functions Core Tools v4 (for local run)

2) Create resources (example)
   - Resource group, Storage, Cognitive Services (Document Intelligence), Azure OpenAI, Function App (Python/Linux/Consumption)
   - Use the script in this folder: scripts/provision.sh (edit variables first)

3) Configure Function App settings
   - AZURE_STORAGE_ACCOUNT, AZURE_STORAGE_KEY, AZURE_STORAGE_CONTAINER (e.g., raw)
   - AZURE_DI_ENDPOINT, AZURE_DI_KEY
   - AZURE_OPENAI_ENDPOINT, AZURE_OPENAI_KEY
   - Optional: CORS/Networking as needed

4) Deploy
   - from azure/functions: func azure functionapp publish <YOUR_FUNCTION_APP>

Local Development
- Copy local.settings.json.example → local.settings.json and fill values
- Start: func start

Contracts
- issueUploadUrls
  - Request: {"count": number}
  - Response: ["<blob_sas_url>" ...]  (SAS grants r/w/create for short TTL)
- analyzeDocument
  - Request: {"urls": ["<blob_url_or_sas>", ...]}
  - Response: {"textBlocks":["..."], "tables":[], "checkboxes":[]}
- processText
  - Request: {"ocrText":"...", "documentType":"紹介状|お薬手帳|一般テキスト|オリジナル", "customPrompt":"..."|null, "deployment":"<openai_deployment_name>"}
  - Response: text/plain (structured text)

Notes
- SAS URLs must include both read and write permissions so iOS can PUT and DI can read.
- Blob PUT requires header: x-ms-blob-type: BlockBlob (iOS client sends it).

