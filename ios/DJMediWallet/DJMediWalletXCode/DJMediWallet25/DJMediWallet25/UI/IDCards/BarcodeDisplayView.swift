import SwiftUI
import CoreImage.CIFilterBuiltins
import UIKit

struct BarcodeDisplayView: View {
    @Environment(\.dismiss) private var dismiss

    let card: IDCard

    @State private var brightness: Double = 1.0
    @State private var originalBrightness: CGFloat?
    @State private var observedScreen: UIScreen?

    private let context = CIContext()

    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 4) {
                Text(card.name)
                    .font(.title2.bold())
                Text(card.category)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 12) {
                if let barcodeImage = generateBarcodeImage() {
                    Image(uiImage: barcodeImage)
                        .resizable()
                        .interpolation(.none)
                        .scaledToFit()
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(radius: 8)
                } else if let qrImage = generateQRImage() {
                    Image(uiImage: qrImage)
                        .resizable()
                        .interpolation(.none)
                        .scaledToFit()
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(radius: 8)
                } else {
                    Text(card.number)
                        .font(.title3.monospacedDigit())
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(radius: 8)
                }

                Text(card.number)
                    .font(.title3.monospacedDigit())
            }

            GroupBox("Brightness") {
                Slider(value: $brightness, in: 0.3...1.0, step: 0.01) {
                    Text("Brightness")
                }
                .onChange(of: brightness, initial: false) { _, newValue in
                    updateScreenBrightness(to: newValue)
                }
                .disabled(observedScreen == nil)
            }

            Spacer()
        }
        .padding()
        .navigationTitle("Barcode")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") { dismiss() }
            }
        }
        .background(ScreenObserver(screen: $observedScreen).allowsHitTesting(false))
        .onAppear {
            if let screen = observedScreen {
                engageDisplayMode(on: screen)
            }
        }
        .onDisappear {
            if let screen = observedScreen, let originalBrightness {
                screen.brightness = originalBrightness
            }
        }
        .onChange(of: observedScreen, initial: false) { _, screen in
            guard let screen else { return }
            engageDisplayMode(on: screen)
        }
    }

    private func generateBarcodeImage() -> UIImage? {
        guard card.number.rangeOfCharacter(from: CharacterSet.decimalDigits.inverted) == nil else { return nil }
        let filter = CIFilter.code128BarcodeGenerator()
        filter.message = Data(card.number.utf8)
        guard let outputImage = filter.outputImage else { return nil }
        let scaleX = 320 / outputImage.extent.width
        let scaleY = 120 / outputImage.extent.height
        let transformed = outputImage.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))
        guard let cgImage = context.createCGImage(transformed, from: transformed.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }

    private func generateQRImage() -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.setValue(Data(card.number.utf8), forKey: "inputMessage")
        guard let outputImage = filter.outputImage else { return nil }
        let scale = 280 / outputImage.extent.width
        let transformed = outputImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        guard let cgImage = context.createCGImage(transformed, from: transformed.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }

    @MainActor
    private func engageDisplayMode(on screen: UIScreen) {
        if originalBrightness == nil {
            originalBrightness = screen.brightness
        }
        screen.brightness = 1.0
        brightness = 1.0
    }

    @MainActor
    private func updateScreenBrightness(to value: Double) {
        guard let screen = observedScreen else { return }
        screen.brightness = CGFloat(value)
    }
}

private struct ScreenObserver: UIViewRepresentable {
    @Binding var screen: UIScreen?

    func makeUIView(context: Context) -> ObserverView {
        let view = ObserverView()
        view.onScreenUpdate = { updateScreen($0) }
        return view
    }

    func updateUIView(_ uiView: ObserverView, context: Context) {
        uiView.onScreenUpdate = { updateScreen($0) }
    }

    private func updateScreen(_ newScreen: UIScreen?) {
        DispatchQueue.main.async {
            screen = newScreen
        }
    }

    final class ObserverView: UIView {
        var onScreenUpdate: ((UIScreen?) -> Void)?

        override func didMoveToWindow() {
            super.didMoveToWindow()
            onScreenUpdate?(window?.windowScene?.screen)
        }
    }
}
