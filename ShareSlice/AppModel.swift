import AppKit
import Combine
import ScreenCaptureKit

struct DisplayChoice: Identifiable {
    let id: CGDirectDisplayID
    let name: String
    let screen: NSScreen
}

@MainActor
final class AppModel: NSObject, ObservableObject {
    @Published var displays: [DisplayChoice] = []
    @Published var selectedDisplayID: CGDirectDisplayID = 0
    @Published var aspectRatio: AspectRatio = .freeform
    @Published private(set) var region: CGRect?
    @Published private(set) var isCapturing = false
    @Published private(set) var isBusy = false
    @Published private(set) var isSelecting = false
    @Published private(set) var needsPermission = false
    @Published private(set) var errorMessage: String?

    private var overlay: SelectionOverlay?
    private var regionOutline: RegionOutline?
    private var preview: PreviewWindow?
    private var capture: CaptureSession?
    private var captureID: UUID?
    private var startupFailure: String?
    private var displayRevision = 0
    private let defaults = UserDefaults.standard

    private struct Preferences: Codable {
        let displayID: CGDirectDisplayID
        let region: CGRect?
        let aspectRatio: String
    }

    override init() {
        super.init()
        refreshDisplays()
        if let data = defaults.data(forKey: "selection"),
           let saved = try? JSONDecoder().decode(Preferences.self, from: data) {
            aspectRatio = AspectRatio(rawValue: saved.aspectRatio) ?? .freeform
            if displays.contains(where: { $0.id == saved.displayID }) {
                selectedDisplayID = saved.displayID
                region = saved.region
            }
        }
        normalizeRegion()
        updateRegionOutline()
        NotificationCenter.default.addObserver(self, selector: #selector(screensChanged),
                                               name: NSApplication.didChangeScreenParametersNotification, object: nil)
    }

    private var selectedDisplay: DisplayChoice? { displays.first { $0.id == selectedDisplayID } }

    var regionDescription: String {
        guard let region else { return "Select a region to begin." }
        return "Region: \(Int(region.width)) × \(Int(region.height)) points"
    }

    private func refreshDisplays() {
        displays = NSScreen.screens.compactMap { screen in
            guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
                return nil
            }
            return DisplayChoice(id: number.uint32Value,
                                 name: "\(screen.localizedName) — \(Int(screen.frame.width)) × \(Int(screen.frame.height))",
                                 screen: screen)
        }
        if !displays.contains(where: { $0.id == selectedDisplayID }) {
            selectedDisplayID = displays.first?.id ?? 0
            region = nil
        }
    }

    @objc private func screensChanged() {
        displayRevision += 1
        overlay?.close()
        overlay = nil
        isSelecting = false
        refreshDisplays()
        normalizeRegion()
        updateRegionOutline()
        if isCapturing {
            errorMessage = "The display configuration changed. Select the display and region again."
            Task { await stopCapture() }
        }
    }

    func displayChanged() {
        region = nil
        updateRegionOutline()
        save()
    }

    func ratioChanged() {
        normalizeRegion()
        updateRegionOutline()
        save()
    }

    private func updateRegionOutline() {
        regionOutline?.close()
        regionOutline = nil
        guard !isSelecting, let screen = selectedDisplay?.screen, let region else { return }
        regionOutline = RegionOutline(screen: screen, region: region)
    }

    private func normalizeRegion() {
        guard let screen = selectedDisplay?.screen, let region else { return }
        let valid = RegionGeometry.constrained(region, to: screen.frame.size, ratio: aspectRatio.value)
        self.region = valid.isEmpty ? nil : valid
    }

    private func save() {
        let preferences = Preferences(displayID: selectedDisplayID, region: region, aspectRatio: aspectRatio.rawValue)
        if let data = try? JSONEncoder().encode(preferences) { defaults.set(data, forKey: "selection") }
    }

    func selectRegion() {
        guard !isBusy, !isCapturing, !isSelecting, let screen = selectedDisplay?.screen else { return }
        errorMessage = nil
        let size = screen.frame.size
        let initial = region ?? CGRect(x: size.width * 0.2, y: size.height * 0.2,
                                       width: size.width * 0.6, height: size.height * 0.6)
        isSelecting = true
        updateRegionOutline()
        overlay = SelectionOverlay(screen: screen,
                                   region: RegionGeometry.constrained(initial, to: size, ratio: aspectRatio.value),
                                   ratio: aspectRatio) { [weak self] result in
            guard let self else { return }
            self.overlay?.close()
            self.overlay = nil
            self.isSelecting = false
            if let result {
                self.region = result
                self.save()
            }
            self.updateRegionOutline()
        }
    }

    func startCapture() async {
        guard !isBusy, !isCapturing, !isSelecting, let choice = selectedDisplay, let region else { return }
        isBusy = true
        errorMessage = nil
        startupFailure = nil
        defer { isBusy = false }
        guard CGPreflightScreenCaptureAccess() || CGRequestScreenCaptureAccess() else {
            needsPermission = true
            errorMessage = "Share Slice needs Screen Recording permission to capture the selected region."
            return
        }
        needsPermission = false
        let revision = displayRevision
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
            guard revision == displayRevision,
                  let display = content.displays.first(where: { $0.displayID == choice.id }) else {
                throw CaptureError.message("The selected display is unavailable. Select a display and region again.")
            }
            let ownApplications = content.applications.filter { $0.processID == ProcessInfo.processInfo.processIdentifier }
            guard !ownApplications.isEmpty else {
                throw CaptureError.message("Could not exclude Share Slice from capture. Try starting capture again.")
            }
            let preview = PreviewWindow(size: region.size)
            self.preview = preview
            let id = UUID()
            captureID = id
            let session = CaptureSession(displayLayer: preview.view.displayLayer) { [weak self] message in
                guard let self, self.captureID == id else { return }
                self.startupFailure = message
                self.errorMessage = "Capture stopped: \(message)"
                if self.isCapturing { Task { await self.stopCapture() } }
            }
            capture = session
            try await session.start(display: display, excluding: ownApplications,
                                    region: region, scale: choice.screen.backingScaleFactor)
            guard revision == displayRevision else {
                throw CaptureError.message("The display configuration changed. Select the region again.")
            }
            if let startupFailure { throw CaptureError.message(startupFailure) }
            isCapturing = true
            preview.onClose = { [weak self] in Task { await self?.stopCapture() } }
            preview.show()
        } catch {
            let session = capture
            capture = nil
            captureID = nil
            var message = error.localizedDescription
            do { try await session?.stop() }
            catch { message += " Cleanup: \(error.localizedDescription)" }
            preview?.close()
            preview = nil
            isCapturing = false
            needsPermission = !CGPreflightScreenCaptureAccess()
            errorMessage = "Could not start capture: \(message)"
        }
    }

    func stopCapture() async {
        guard let session = capture, !isBusy else { return }
        isBusy = true
        capture = nil
        captureID = nil
        defer { isBusy = false }
        do { try await session.stop() }
        catch { errorMessage = "Could not stop capture cleanly: \(error.localizedDescription)" }
        preview?.close()
        preview = nil
        isCapturing = false
    }

    func openPermissionSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
            NSWorkspace.shared.open(url)
        }
    }
}

private enum CaptureError: LocalizedError {
    case message(String)
    var errorDescription: String? {
        switch self { case .message(let message): return message }
    }
}
