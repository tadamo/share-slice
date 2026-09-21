import AVFoundation
import ScreenCaptureKit

final class CaptureSession: NSObject, SCStreamOutput, SCStreamDelegate {
    private var stream: SCStream?
    private let outputQueue = DispatchQueue(label: "ShareSlice.capture", qos: .userInteractive)
    private let lock = NSLock()
    private var pendingFrame: CMSampleBuffer?
    private var deliveryScheduled = false
    private var acceptingFrames = true
    private let displayLayer: AVSampleBufferDisplayLayer
    private let onFailure: @MainActor (String) -> Void

    init(displayLayer: AVSampleBufferDisplayLayer, onFailure: @escaping @MainActor (String) -> Void) {
        self.displayLayer = displayLayer
        self.onFailure = onFailure
    }

    func start(display: SCDisplay, excluding applications: [SCRunningApplication],
               region: CGRect, scale: CGFloat) async throws {
        let filter = SCContentFilter(display: display, excludingApplications: applications, exceptingWindows: [])
        let configuration = configuration(region: region, scale: scale)
        let stream = SCStream(filter: filter, configuration: configuration, delegate: self)
        self.stream = stream
        try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: outputQueue)
        try await stream.startCapture()
    }

    func update(region: CGRect, scale: CGFloat) async throws {
        guard let stream else { return }
        try await stream.updateConfiguration(configuration(region: region, scale: scale))
    }

    private func configuration(region: CGRect, scale: CGFloat) -> SCStreamConfiguration {
        let configuration = SCStreamConfiguration()
        configuration.sourceRect = region
        let pixels = RegionGeometry.pixelSize(region, scale: scale)
        configuration.width = Int(pixels.width)
        configuration.height = Int(pixels.height)
        configuration.minimumFrameInterval = CMTime(value: 1, timescale: 30)
        configuration.queueDepth = 3
        configuration.pixelFormat = kCVPixelFormatType_32BGRA
        configuration.showsCursor = true
        configuration.capturesAudio = false
        return configuration
    }

    func stop() async throws {
        discardFrames()
        guard let stream else { return }
        self.stream = nil
        try await stream.stopCapture()
    }

    private func discardFrames() {
        lock.lock()
        acceptingFrames = false
        pendingFrame = nil
        lock.unlock()
    }

    func stream(_ stream: SCStream, didStopWithError error: Error) {
        discardFrames()
        Task { @MainActor in onFailure(error.localizedDescription) }
    }

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer,
                of type: SCStreamOutputType) {
        guard type == .screen, sampleBuffer.isValid,
              let attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: false)
                as? [[SCStreamFrameInfo: Any]],
              let status = attachments.first?[.status] as? Int,
              status == SCFrameStatus.complete.rawValue else { return }
        // Present immediately, without a second playback clock or CPU image conversion.
        if let values = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: true) {
            let dictionary = unsafeBitCast(CFArrayGetValueAtIndex(values, 0), to: CFMutableDictionary.self)
            CFDictionarySetValue(dictionary,
                                 Unmanaged.passUnretained(kCMSampleAttachmentKey_DisplayImmediately).toOpaque(),
                                 Unmanaged.passUnretained(kCFBooleanTrue).toOpaque())
        }
        lock.lock()
        guard acceptingFrames else { lock.unlock(); return }
        pendingFrame = sampleBuffer
        let shouldSchedule = !deliveryScheduled
        deliveryScheduled = true
        lock.unlock()
        guard shouldSchedule else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.lock.lock()
            let frame = self.pendingFrame
            self.pendingFrame = nil
            self.deliveryScheduled = false
            self.lock.unlock()
            guard let frame else { return }
            if self.displayLayer.status == .failed { self.displayLayer.flush() }
            if self.displayLayer.isReadyForMoreMediaData { self.displayLayer.enqueue(frame) }
        }
    }
}
