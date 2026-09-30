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
    @Published private(set) var needsPermission = false
    @Published private(set) var errorMessage: String?

    private var regionUpdateTask: Task<Void, Never>?
    private var pendingRegion: CGRect?
    private var outlineDisplayID: CGDirectDisplayID?
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
        guard let region else { return "No display available." }
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
        regionOutline?.close()
        regionOutline = nil
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
        normalizeRegion()
        updateRegionOutline()
        save()
    }

    func ratioChanged() {
        normalizeRegion()
        updateRegionOutline()
        save()
        queueRegionUpdate()
    }

    private func updateRegionOutline() {
        guard let screen = selectedDisplay?.screen, let region else {
            regionOutline?.close()
            regionOutline = nil
            outlineDisplayID = nil
            return
        }
        if regionOutline == nil || outlineDisplayID != selectedDisplayID {
            regionOutline?.close()
            regionOutline = RegionOutline(screen: screen) { [weak self] region, finished in
                guard let self, !self.isBusy else { return }
                self.region = region
                self.updateRegionOutline()
                if finished { self.save() }
                self.queueRegionUpdate()
            }
            outlineDisplayID = selectedDisplayID
        }
        regionOutline?.update(region: region, ratio: aspectRatio, capturing: isCapturing, enabled: !isBusy)
    }

    private func normalizeRegion() {
        guard let screen = selectedDisplay?.screen else { region = nil; return }
        let size = screen.frame.size
        let fallback = RegionGeometry.defaultRegion(in: size, ratio: aspectRatio.value)
        let valid = RegionGeometry.constrained(region ?? fallback, to: size, ratio: aspectRatio.value)
        region = valid.isEmpty ? fallback : valid
    }

    private func queueRegionUpdate() {
        guard isCapturing, let session = capture, let scale = selectedDisplay?.screen.backingScaleFactor else { return }
        pendingRegion = region
        guard regionUpdateTask == nil else { return }
        regionUpdateTask = Task { [weak self] in
            guard let self else { return }
            defer { self.regionUpdateTask = nil }
            while self.isCapturing, let region = self.pendingRegion {
                self.pendingRegion = nil
                do {
                    try await session.update(region: region, scale: scale)
                    guard self.isCapturing else { return }
                    self.preview?.updateAspectRatio(region.size)
                } catch {
                    self.errorMessage = "Could not update capture: \(error.localizedDescription)"
                    Task { await self.stopCapture() }
                    return
                }
            }
        }
    }

    private func save() {
        let preferences = Preferences(displayID: selectedDisplayID, region: region, aspectRatio: aspectRatio.rawValue)
        if let data = try? JSONEncoder().encode(preferences) { defaults.set(data, forKey: "selection") }
    }

    func startCapture() async {
        guard !isBusy, !isCapturing, let choice = selectedDisplay, let region else { return }
        isBusy = true
        errorMessage = nil
        startupFailure = nil
        updateRegionOutline()
        defer {
            isBusy = false
            updateRegionOutline()
        }
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

    func showShareWindow() {
        guard isCapturing, !isBusy else { return }
        preview?.show()
    }

    func stopCapture() async {
        guard let session = capture, !isBusy else { return }
        isBusy = true
        capture = nil
        captureID = nil
        isCapturing = false
        pendingRegion = nil
        updateRegionOutline()
        defer {
            isBusy = false
            updateRegionOutline()
        }
        await regionUpdateTask?.value
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
