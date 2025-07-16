import UIKit
import AVFoundation

class CameraViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {
    
    // MARK: - Properties
    var session: AVCaptureSession!
    var previewLayer: AVCaptureVideoPreviewLayer!
    var onFrameCaptured: ((CMSampleBuffer) -> Void)?
    
    private var assetWriter: AVAssetWriter?
    private var assetWriterInput: AVAssetWriterInput?
    private var isRecording = false
    private var videoOutputURL: URL?
    private var startTime: CMTime?

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupCaptureSession()
    }
    
    func startRecording() throws {
        guard !isRecording else { return }

        let tempDirectory = FileManager.default.temporaryDirectory
        videoOutputURL = tempDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("mp4")
        guard let url = videoOutputURL else { return }

        assetWriter = try AVAssetWriter(outputURL: url, fileType: .mp4)

        guard let inputDevice = session.inputs.first as? AVCaptureDeviceInput else { return }
        let formatDesc = inputDevice.device.activeFormat.formatDescription
        let dimensions = CMVideoFormatDescriptionGetDimensions(formatDesc)

        let outputSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: dimensions.height,
            AVVideoHeightKey: dimensions.width
        ]

        assetWriterInput = AVAssetWriterInput(mediaType: .video, outputSettings: outputSettings)
        assetWriterInput?.expectsMediaDataInRealTime = true

        assetWriterInput?.transform = CGAffineTransform(rotationAngle: -.pi / 2)

        if let writerInput = assetWriterInput, assetWriter!.canAdd(writerInput) {
            assetWriter!.add(writerInput)
        }

        assetWriter!.startWriting()
        isRecording = true
        startTime = nil
    }


    
    func stopRecording() async -> URL? {
        guard isRecording, let writer = assetWriter else { return nil }
        
        isRecording = false
        assetWriterInput?.markAsFinished()
        
        await writer.finishWriting()
        return videoOutputURL
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        onFrameCaptured?(sampleBuffer)
        
        if isRecording,
           let input = assetWriterInput,
           input.isReadyForMoreMediaData,
           let writer = assetWriter,
           writer.status == .writing {
            
            if startTime == nil {
                // 最初のフレームが来た時のタイムスタンプで開始する
                let presentationTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
                writer.startSession(atSourceTime: presentationTime)
                startTime = presentationTime
            }
            
            input.append(sampleBuffer)
        }
    }
    
    // MARK: - Private Methods
    private func setupCaptureSession() {
        session = AVCaptureSession()
        session.sessionPreset = .hd1280x720

        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else { return }
        session.addInput(input)

        let output = AVCaptureVideoDataOutput()
        output.alwaysDiscardsLateVideoFrames = true
        
        let videoQueue = DispatchQueue(label: "videoQueue", qos: .userInitiated)
        output.setSampleBufferDelegate(self, queue: videoQueue)
        
        if session.canAddOutput(output) {
            session.addOutput(output)
        }
        
        if let videoConnection = output.connection(with: .video) {
            let rotationAngle: CGFloat = 90
            if videoConnection.isVideoRotationAngleSupported(rotationAngle) {
                videoConnection.videoRotationAngle = rotationAngle
            } else if videoConnection.isVideoOrientationSupported {
                videoConnection.videoOrientation = .landscapeRight
            }
        }

        previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.frame = view.bounds
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)

        
        DispatchQueue.global(qos: .background).async {
            self.session.startRunning()
        }
    }
}
