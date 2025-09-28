import SwiftUI
import CoreImage.CIFilterBuiltins

struct QRCodeView: View {
    let text: String
    @State private var image: UIImage?
    private let context = CIContext()
    private let filter = CIFilter.qrCodeGenerator()

    var body: some View {
        VStack(spacing: 16) {
            if let img = image {
                Image(uiImage: img)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 260, height: 260)
                    .padding()
            } else {
                ProgressView()
            }
            Text("このQRは編集後テキストをエンコードしています。")
                .font(.footnote).foregroundColor(.secondary)
            Spacer()
        }
        .navigationTitle("QRコード")
        .onAppear(perform: generate)
        .padding()
    }

    private func generate() {
        let data = Data(text.utf8)
        filter.setValue(data, forKey: "inputMessage")
        filter.correctionLevel = "M"
        if let outputImage = filter.outputImage?.transformed(by: CGAffineTransform(scaleX: 10, y: 10)),
           let cgimg = context.createCGImage(outputImage, from: outputImage.extent) {
            image = UIImage(cgImage: cgimg)
        }
    }
}

