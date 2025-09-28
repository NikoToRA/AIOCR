import SwiftUI

struct DocumentTypeMenu: View {
    var onSelect: (DocumentType, String?) -> Void
    @State private var customPrompts: [CustomPrompt] = []
    private let local = LocalStorageServiceImpl()
    private let ringRadius: CGFloat = 110

    var body: some View {
        VStack(spacing: 24) {
            Text("文書タイプを選択").font(.headline)
            ZStack {
                ForEach(presetItems().indices, id: \.self) { idx in
                    let item = presetItems()[idx]
                    let angle = Angle(degrees: Double(idx) / Double(max(1, presetItems().count)) * 360)
                    typeButton(title: item.0) {
                        onSelect(item.1, nil)
                    }
                    .offset(x: cos(CGFloat(angle.radians)) * ringRadius,
                            y: sin(CGFloat(angle.radians)) * ringRadius)
                }
            }

            if !customPrompts.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(customPrompts) { prompt in
                            typeChip(title: prompt.name) {
                                onSelect(.custom, prompt.prompt)
                            }
                        }
                    }.padding(.horizontal)
                }
            }
        }
        .onAppear { customPrompts = (try? local.loadCustomPrompts()) ?? [] }
        .padding()
    }

    private func presetItems() -> [(String, DocumentType)] {
        [
            (DocumentType.referralLetter.rawValue, .referralLetter),
            (DocumentType.medicationNotebook.rawValue, .medicationNotebook),
            (DocumentType.generalText.rawValue, .generalText)
        ]
    }

    private func typeButton(title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline).bold()
                .padding(16)
                .background(Circle().fill(Color.blue.opacity(0.85)))
                .foregroundColor(.white)
        }
    }

    private func typeChip(title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(.subheadline)
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(Capsule().fill(Color.secondary.opacity(0.15)))
        }
    }
}

