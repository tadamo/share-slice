import SwiftUI

@main
@MainActor
struct ShareSliceApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        Window("Share Slice", id: "controls") {
            ControlView(model: model)
        }
        .windowResizability(.contentSize)
    }
}

@MainActor
private struct ControlView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Share Slice").font(.title2.bold())
            Text("Start capture, then in Teams choose Share > Window > \"\(PreviewWindow.title)\".")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Picker("Display", selection: $model.selectedDisplayID) {
                ForEach(model.displays) { display in
                    Text(display.name).tag(display.id)
                }
            }
            .disabled(model.isBusy || model.isCapturing)
            .onChange(of: model.selectedDisplayID) { _ in model.displayChanged() }

            Picker("Aspect ratio", selection: $model.aspectRatio) {
                ForEach(AspectRatio.allCases) { ratio in Text(ratio.rawValue).tag(ratio) }
            }
            .disabled(model.isBusy)
            .onChange(of: model.aspectRatio) { _ in model.ratioChanged() }

            Text("Drag Move to reposition the region or a corner to resize.")
                .font(.caption).foregroundStyle(.secondary)
            Text(model.regionDescription).font(.callout).foregroundStyle(.secondary)
            HStack {
                Spacer()
                if model.isCapturing {
                    Button("Show Share Window") { model.showShareWindow() }
                        .disabled(model.isBusy)
                    Button("Stop Capture") { Task { await model.stopCapture() } }
                        .disabled(model.isBusy)
                } else {
                    Button("Start Capture") { Task { await model.startCapture() } }
                        .keyboardShortcut(.defaultAction)
                        .disabled(model.region == nil || model.isBusy)
                }
            }
            if model.isCapturing {
                Text("Keep the share window open and unminimized so it appears in Teams. Click Show Share Window to restore it.")
                    .font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if model.isBusy { ProgressView().controlSize(.small) }
            if let error = model.errorMessage {
                Text(error).foregroundStyle(.red).textSelection(.enabled)
            }
            if model.needsPermission {
                Button("Open Screen Recording Settings") { model.openPermissionSettings() }
                Text("Enable Share Slice, then quit and reopen it if macOS asks.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(20)
        .frame(width: 420)
    }
}
