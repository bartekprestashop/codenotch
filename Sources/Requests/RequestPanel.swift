import AppKit
import SwiftUI

final class RequestPanel: NSPanel {
    var onClose: (() -> Void)?
    init(contentRect: NSRect) {
        super.init(contentRect: contentRect, styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered, defer: false)
        level = .statusBar
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
    }

    override var canBecomeKey: Bool { true }
    override func close() {
        super.close()
        onClose?()
    }
    override func cancelOperation(_ sender: Any?) { close() }
}
/// The request panel shares the black card language of the usage tooltip.
/// It is its own window so the notch's mouse interception cannot swallow its buttons.
struct RequestPanelView: View {
    static let preferredWidth: CGFloat = 520

    static func height(for requests: [ActionRequest], width: CGFloat) -> CGFloat {
        let textWidth = width - 64
        func textHeight(_ text: String, font: NSFont) -> CGFloat {
            let bounds = (text as NSString).boundingRect(
                with: NSSize(width: textWidth, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: [.font: font]
            )
            return ceil(bounds.height)
        }
        let rows = requests.reduce(CGFloat.zero) { total, request in
            let title = textHeight("\(request.project) · \(request.task)",
                                   font: .systemFont(ofSize: 16, weight: .semibold))
            let message = textHeight(request.message, font: .systemFont(ofSize: 14))
            return total + title + message + 76
        }
        return max(160, 80 + rows + CGFloat(max(0, requests.count - 1)) * 16)
    }

    let requests: [ActionRequest]
    let width: CGFloat
    let maxHeight: CGFloat
    let open: (ActionRequestKey) -> Void
    let clear: (ActionRequestKey) -> Void
    let dismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Requests · \(requests.count)")
                    .font(.system(size: 17, weight: .semibold))
                Spacer()
                Button("Close", action: dismiss)
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.white.opacity(0.65))
            }
            .padding(.horizontal, 24)
            .padding(.top, 22)
            .padding(.bottom, 14)
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(requests, id: \.id) { request in
                        VStack(alignment: .leading, spacing: 10) {
                            Button { open(request.key) } label: {
                                VStack(alignment: .leading, spacing: 7) {
                                    Text("\(request.project) · \(request.task)")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundStyle(.white)
                                    Text(request.message)
                                        .font(.system(size: 14))
                                        .foregroundStyle(Color.white.opacity(0.65))
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Open Codex chat. \(request.project), \(request.task). \(request.message)")
                            HStack {
                                Button("Open Codex chat") { open(request.key) }
                                    .foregroundStyle(.orange)
                                Spacer()
                                Button("Clear orphaned request") { clear(request.key) }
                                    .foregroundStyle(Color.white.opacity(0.65))
                            }
                            .buttonStyle(.plain)
                            .font(.system(size: 13))
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.white.opacity(0.09), in: RoundedRectangle(cornerRadius: 14))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 18)
            }
        }
        .foregroundStyle(.white)
        .frame(width: width, height: maxHeight)
        .background(Color.black, in: RoundedRectangle(cornerRadius: 22))
        .environment(\.colorScheme, .dark)
    }
}
