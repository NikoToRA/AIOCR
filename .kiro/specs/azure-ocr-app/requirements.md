# 要件定義書（Software Requirements Specification / SRS）

版: v1.0  最終更新: 2025-09-28

- 対象アプリ: KoEReq OCR (Azure Edition)
- 対象プラットフォーム: iOS 17+（実機 18.5 検証）
- 開発スタック: SwiftUI, AVFoundation, Azure Functions + Azure Document Intelligence + Azure OpenAI（後段）
- リポジトリ構成（実装本体）:
  - `ios/KoEReqOCR/Sources/KoEReqOCR/KoEReqOCR.xcodeproj`
  - `ios/KoEReqOCR/Sources/{App, Core, Features}`
  - 仕様・設計: `.kiro/specs/azure-ocr-app/*`

---

## 1. 概要 / 目的

医療文書（紹介状/お薬手帳/一般テキスト/オリジナル）をスマホカメラで撮影し、AIでテキスト化・編集・QR化・保存するアプリ。MVPはローカル動作（スタブ）で安定化し、その後 Azure 連携に差し替える。

- アプリの最上位ゴール
  - 起動直後カメラ（ガイド・歯車・AIボタン）
  - 連続撮影→文書タイプ選択（円形）→AI解析→結果編集→QR生成→保存（ローカル/クラウド）
  - 設定からオリジナル文書タイプ（カスタムプロンプト）とストレージ履歴を管理

---

## 2. スコープ

- In-scope（MVP→本実装）
  - カメラ撮影（連続）/ 撮影数表示 / 撮り直し
  - 文書タイプ選択（円形 UI + オリジナル文書チップ）
  - 解析結果の編集 / QR生成 / セッション保存（ローカル）
  - 設定（オリジナル文書編集、ストレージ確認）
  - 監査ログ（JSONL + コンソール DEBUG）
  - Azure連携（Blob/DI/OpenAI）に差し替え可能なサービス層

- Out-of-scope（初期）
  - 多言語 UI、詳細なアクセシビリティ設定
  - 高度なレイアウト認識（表/チェックボックスの完全抽出）
  - 組織的 SSO、MDM 専用設定
  - バックグラウンドアップロード/プッシュ通知

---

## 3. 利用者 / 役割

- 一般ユーザー（医療従事者/患者）: 撮影→AI→編集→共有
- システム管理者: Azure 側の構成・鍵管理・ログ監査

---

## 4. 前提・依存関係

- 端末カメラ権限の許諾
- ネットワーク（Azure 連携時）
- iOS 17 以上, Xcode 16 系
- Azure Functions/Blob/Document Intelligence/OpenAI のサブスクリプション（本実装時）

---

## 5. 画面フロー / ナビゲーション

1) 起動: `CameraView`
   - カメラプレビュー / 撮影ガイド / 歯車 / AIでテキスト化
2) 文書タイプ選択: `DocumentTypeMenu`
   - 円形: 紹介状 / お薬手帳 / 一般テキスト
   - 水平チップ: オリジナル文書（保存済み）
3) 結果編集: `TextAnalysisView`
   - 編集可能 / 取り直し / QR生成 / 保存
4) 設定: `SettingsView`
   - オリジナル文書編集（作成/一覧/削除）
   - ストレージ確認（保存済みセッションの一覧）

---

## 6. 機能要件（ユーザーストーリー / 受入基準）

### 要件1: カメラファースト起動
- ユーザーストーリー: 起動直後に撮影を始めたい
- 受入基準:
  1) 起動時に `CameraView` を表示する
  2) 撮影ガイド枠を表示する
  3) 右上に設定（歯車）ボタンを表示する
  4) シャッターで撮影できる
  5) 「AIでテキスト化」ボタンを表示する

### 要件2: 設定画面
- ユーザーストーリー: オリジナル文書管理と保存データ確認をしたい
- 受入基準:
  1) 歯車で設定画面を開ける（シート）
  2) 「オリジナル文書編集」「ストレージ確認」を表示
  3) オリジナル文書の作成/一覧/削除ができる
  4) 保存済みセッション一覧を表示できる

### 要件3: 連続撮影
- ユーザーストーリー: 必要枚数を連続で撮って後から解析
- 受入基準:
  1) 撮影ごとに画像を蓄積
  2) 画面に「n枚撮影済み」を表示
  3) AIボタンでタイプ選択へ
  4) 0枚時は警告
  5) 複数枚でもカウント反映

### 要件4: 円形タイプ選択 → 解析開始
- ユーザーストーリー: 素早くタイプを選び解析開始
- 受入基準:
  1) 円形メニューでタイプを表示
  2) 紹介状/お薬手帳/一般テキスト + オリジナルを提供
  3) 選択でタイプ別プロンプト準備→解析
  4) メニューを閉じて結果画面へ遷移

### 要件5: Azure Blob 連携（本実装）
- 受入基準（概要）:
  1) SAS URL を Functions から取得
  2) 画像を PUT アップロード（`raw/<docId>.jpg`）
  3) 監査ログに `uploaded`
  4) 失敗時はローカルキュー→指数バックオフ再送

### 要件6: Azure 解析/LLM（本実装）
- 受入基準（概要）:
  1) DI に解析依頼→OCR テキスト取得
  2) タイプ別プロンプトで Azure OpenAI へ
  3) 構造化テキストを受領
  4) 監査ログ `analysis_done`

### 要件7: 結果編集
- 受入基準:
  1) 解析結果を編集可能に表示
  2) 表/チェックボックスは簡易的に扱う（将来拡張）
  3) 取り直しでカメラへ戻る
  4) 複数枚の統合表示（MVP は結合テキスト）
  5) QR生成ボタンを提供

### 要件8: QR生成 + 保存
- 受入基準:
  1) QRモーダルを表示
  2) 編集済みテキストをQRエンコード
  3) 画像保存オプション
  4) セッション（画像・テキスト・タイプ・日時）をローカル保存
  5) クラウド保存（本実装）
  6) 監査ログ `session_saved`

### 要件9: ストレージ確認
- 受入基準:
  1) 保存済みセッション一覧を表示
  2) 簡易検索/ソート（MVPは一覧/最新順）
  3) 項目選択で内容参照（将来: 再編集）

### 要件10: IAP（将来）
- 受入基準（概要）:
  1) プラン: Light/Standard/Pro
  2) 月次ページ数の制御と無料トライアル

### 要件11: エラー/再送（本実装）
- 受入基準（概要）:
  1) 失敗はキュー退避→指数バックオフ
  2) 24h 超過は通知/バッジ

### 要件12: プライバシー/セキュリティ
- 受入基準（概要）:
  1) App Privacy Manifest 準拠（匿名ID）
  2) Private Endpoint / Managed Identity
  3) カメラ/写真使用目的の明記

---

## 7. 非機能要件

- 性能: 起動→プレビュー表示 < 1.5s（スタブ時）。UI スレッドをブロックしない。
- 安定性: 撮影/解析/保存でクラッシュがない。撮影は 5 回連続操作でも応答性が落ちない。
- 可用性: オフライン時はローカルのみで動作（解析は不可/メッセージ）。
- ログ: `Documents/KoEReqOCR/audit_log.jsonl` + DEBUG 時はコンソール `[Audit]` 出力。
- セキュリティ: 機密設定は Info.plist / Keychain、通信は HTTPS。
- メンテ: サービス層はプロトコルで抽象化、スタブ↔本実装差し替え可能。

---

## 8. アーキテクチャ / 実装マッピング

- App 入口: `App/KoEReqOCRApp.swift`（`NavigationStack { CameraView() } .environmentObject(SessionManager)`）
- Features
  - Camera: `Features/Camera/{CameraView.swift, CameraSession.swift}`
  - DocumentType: `Features/DocumentType/DocumentTypeMenuView.swift`
  - Result: `Features/Result/{TextAnalysisView.swift, QRCodeView.swift}`
  - Settings: `Features/Settings/{SettingsView.swift, CustomPromptEditorView.swift, StorageBrowserView.swift}`
- Core
  - Business: `Core/Business/{SessionManager.swift, DocumentProcessor.swift, PromptManager.swift}`
  - Services: `Core/Services/{Protocols.swift, AzureStubs.swift, AzureReal.swift, LocalStorageServiceImpl.swift}`
  - Models: `Core/Models/Models.swift`
  - Utils: `Core/Utils/AuditLogger.swift`

---

## 9. データモデル（抜粋）

- `SessionData { id, images:[Data], originalText, editedText, documentType, customPromptUsed?, createdAt, qrCodeGenerated }`
- `DocumentType: referralLetter/medicationNotebook/generalText/custom`
- `CustomPrompt { id, name, prompt, createdAt }`
- `OCRResult { textBlocks:[String], tables:[[[String]]], checkboxes:[{label,checked}] }`

---

## 10. サービス/API（本実装仕様）

- Azure Functions（例）
  - `POST /getSas` Request: `{ containerName, fileName }` → Response: `{ sasUrl }`
  - `POST /di/analyze` Request: `{ imageUrls:[String], documentType }` → Response: `{ textBlocks:[String], tables, checkboxes }`
  - `POST /openai/structure` Request: `{ ocrText, documentType, customPrompt? }` → Response: `{ text:String }`
- 失敗時共通: `{ error:{ code, message } }`、HTTP 4xx/5xx

---

## 11. 設定/ビルド

- Info.plist（UsageDescriptions）
  - `NSCameraUsageDescription`: カメラで文書を撮影します。
  - `NSPhotoLibraryAddUsageDescription`: 撮影画像の保存に使用します。
- Azure（本実装）
  - `AZURE_FUNCTIONS_BASE_URL`
  - `AZURE_OPENAI_ENDPOINT`
  - `AZURE_OPENAI_DEPLOYMENT`
- Xcode 運用
  - 追加は「Create groups（黄色）」で、Target Membership を必ず `KoEReqOCR` に
  - Build Phases > Compile Sources 重複なし（@main は 1 つ）
  - 実行スキーム: `ios/KoEReqOCR/Sources/KoEReqOCR/KoEReqOCR.xcodeproj` の `KoEReqOCR`

---

## 12. ロギング/監査

- 形式: JSON Lines（`audit_log.jsonl`）
- イベント: `appLaunch, cameraGranted, cameraDenied, capture, analyzeStart, analyzeSuccess, analyzeError, sessionSaved`
- DEBUG 時はコンソールに `[Audit]` を出力

---

## 13. エラーハンドリング方針

- カメラ権限拒否: アラート表示→設定誘導
- 0枚で AI: 「写真を撮影してください」
- 解析失敗: アラート（詳細メッセージ）+ 監査ログ `analyzeError`
- アップロード失敗（本実装）: ローカルキュー→指数バックオフ再送

---

## 14. UI/UX 要件

- 歯車（右上）常時表示
- ガイド枠（コントラスト/視認性）
- 撮影ボタン: タップ領域 44pt 以上
- 文書タイプ円形: 3種 + オリジナル横スクロール
- 結果画面: 編集テキスト + 取り直し + QR + 保存
- 色弱/暗所でも見える配色（最小限）

---

## 15. テストと受入

- 起動→カメラ→歯車表示
- 連続撮影 1〜5回→枚数表示
- 0枚 AI→警告
- タイプ選択→AI→結果
- 結果編集→QR→戻る
- オリジナル文書 作成/一覧/削除
- ストレージ確認で保存済み表示
- 監査ログに主要イベントが出力

---

## 16. パフォーマンス/スレッド

- カメラ開始はバックグラウンド / 構成は専用キュー
- UI 更新（`@Published`）は MainActor（`SessionManager`）
- `AVCapturePhotoOutput` は delegate を強参照保持、`capturePhoto` はメインで実行

---

## 17. リリース準備

- プライバシー・マニフェスト: `PrivacyInfo.xcprivacy`
- Info.plist 用途説明 OK
- 実機デバッグ・リリースビルド検証

---

## 18. 将来拡張

- 詳細な表/チェックボックス抽出とUI整形
- 多言語対応、VoiceOver
- IAP 課金の実装
- クラウド履歴/検索

---

## 19. トレーサビリティ（要件→実装）

- R1/R3/R4: `CameraView`, `DocumentTypeMenuView`, `SessionManager`, `CameraSession`
- R2/R9: `SettingsView`, `CustomPromptEditorView`, `StorageBrowserView`, `LocalStorageServiceImpl`
- R6/R7/R8: `DocumentProcessor`, `TextAnalysisView`, `QRCodeView`, `Azure*`, `Models`
- ログ: `AuditLogger`

---

## 20. 付録

- 既知の留意点
  - Xcode のフォルダ参照（グレー）は Target Membership に入らないことがあるため、Create groups を使用
  - `@main` は 1 つのみ
  - デバッガ接続中の `Hang detected` ログは情報であり致命ではない

- 参考ディレクトリ（主要）
  - `ios/KoEReqOCR/Sources/KoEReqOCR/Features/Camera/CameraView.swift`
  - `ios/KoEReqOCR/Sources/KoEReqOCR/Core/Business/SessionManager.swift`
  - `ios/KoEReqOCR/Sources/KoEReqOCR/Core/Utils/AuditLogger.swift`
  - `ios/KoEReqOCR/Sources/KoEReqOCR/Core/Services/{AzureStubs.swift, AzureReal.swift}`
  - `ios/KoEReqOCR/Sources/KoEReqOCR/Core/Models/Models.swift`
