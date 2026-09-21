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
            Text("Choose a region, then share the preview window in Teams.")
                .foregroundStyle(.secondary)

            Picker("Display", selection: $model.selectedDisplayID) {
                ForEach(model.displays) { display in
                    Text(display.name).tag(display.id)
                }
            }
            .disabled(model.isBusy || model.isCapturing || model.isSelecting)
            .onChange(of: model.selectedDisplayID) { _ in model.displayChanged() }

            Picker("Aspect ratio", selection: $model.aspectRatio) {
                ForEach(AspectRatio.allCases) { ratio in Text(ratio.rawValue).tag(ratio) }
            }
            .disabled(model.isBusy || model.isCapturing || model.isSelecting)
            .onChange(of: model.aspectRatio) { _ in model.ratioChanged() }

            Text(model.regionDescription).font(.callout).foregroundStyle(.secondary)
            HStack {
                Button("Select Region…") { model.selectRegion() }
                    .disabled(model.displays.isEmpty || model.isBusy || model.isCapturing || model.isSelecting)
                Spacer()
                if model.isCapturing {
                    Button("Stop Capture") { Task { await model.stopCapture() } }
                        .disabled(model.isBusy)
                } else {
                    Button("Start Capture") { Task { await model.startCapture() } }
                        .keyboardShortcut(.defaultAction)
                        .disabled(model.region == nil || model.isBusy || model.isSelecting)
                }
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
