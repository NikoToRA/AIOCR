KoEReq OCR (Azure Edition) — iOS SwiftUI MVP

概要
- 目的: 要件1〜4/7/12を満たすローカル動作MVP（カメラ→連続撮影→文書タイプ選択→結果編集）。
- 配布想定: App Store / ABM。Azure連携は後続で差し替え可能なプロトコル層を用意。

Xcodeプロジェクト作成手順（ローカル）
1) Xcodeで File > New > Project… を選択し、iOS > App、Interface: SwiftUI、Language: Swift、Name: `KoEReqOCR`、Minimum iOS: 17 以上で作成。
2) このフォルダ `ios/KoEReqOCR` の `Sources` 配下をプロジェクトへドラッグ＆ドロップ（Copy items if needed をチェック）。
3) Info.plist に以下を追加:
   - `NSCameraUsageDescription`: カメラで文書を撮影します。
   - `NSPhotoLibraryAddUsageDescription`: 撮影画像の保存に使用します。
   - （Azure接続時）`AZURE_FUNCTIONS_BASE_URL`、`AZURE_OPENAI_ENDPOINT`、`AZURE_OPENAI_DEPLOYMENT`
4) Capabilities（後続想定）:
   - In-App Purchase（後で有効化）
   - Push/Background は現時点不要
5) プライバシー・マニフェストを追加: `PrivacyInfo.xcprivacy` をプロジェクト直下に追加（本リポジトリの同名ファイルを利用可）。

画面フロー（MVP）
- 起動: CameraView（ガイド枠、撮影、撮影枚数、設定ボタン、AIでテキスト化）
- 文書タイプ選択: CircularDocumentTypeMenu（紹介状/お薬手帳/一般テキスト + カスタム）
- 結果編集: TextAnalysisView（編集可能テキスト、QR生成は後続）
- 設定: SettingsView（カスタム文書タイプ編集、ストレージ確認）

Azure連携
- `Protocols.swift` に定義した `AzureStorageService`/`DocumentIntelligenceService`/`OpenAIService` を差し替え。
- 現状 `AzureStubs.swift` はモック実装（ローカル動作用）。
 - 実装用: `AzureReal.swift` に Azure Functions 経由の実装骨子あり。Info.plist にベースURLとOpenAI設定を追加し、`DocumentProcessor` の依存を差し替える。

差し替え例（`CameraView` 内）
```
private let processor = DocumentProcessor(
    storage: AzureFunctionsStorage() ?? AzureStorageStub(),
    di: AzureDocumentIntelligence() ?? DocumentIntelligenceStub(),
    openai: AzureOpenAIText() ?? OpenAIStub()
)
```

ビルドメモ
- 本MVPは SwiftUI + AVFoundation のみ。
- 実機テスト時は Signing & Capabilities を適切に設定してください。
