//
//  CameraLiveModel.swift
//  Image Classifier
//
//  Created by Kristian Emil on 23/12/2024.
//

import AVFoundation
import Vision

class LiveCameraModel: NSObject, ObservableObject {
    @Published var classificationResult: String = ""
    @Published var permissionGranted = false
    let session = AVCaptureSession()
    private let videoOutput = AVCaptureVideoDataOutput()
    private var lastAnalysis: Date = .distantPast
    private let minimumAnalysisInterval: TimeInterval = 0.5
    
    override init() {
        super.init()
        checkPermissions()
        videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue"))
    }
    
    private func checkPermissions() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
            case .authorized:
                setupCamera()
                permissionGranted = true
            case .notDetermined:
                AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                    if granted {
                        DispatchQueue.main.async {
                            self?.setupCamera()
                            self?.permissionGranted = true
                        }
                    }
                }
            case .denied, .restricted:
                permissionGranted = false
            @unknown default:
                permissionGranted = false
        }
    }
    
    private func setupCamera() {
        session.beginConfiguration()
        
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device) else { return }
        
        if session.canAddInput(input) {
            session.addInput(input)
        }
        
        if session.canAddOutput(videoOutput) {
            session.addOutput(videoOutput)
        }
        
        session.commitConfiguration()
    }
    
    func startSession() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.session.startRunning()
        }
    }
    
    func stopSession() {
        session.stopRunning()
    }
}

// MARK: - Video Processing Extension
extension LiveCameraModel: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput,
                      didOutput sampleBuffer: CMSampleBuffer,
                      from connection: AVCaptureConnection) {
        let currentDate = Date()
        guard currentDate.timeIntervalSince(lastAnalysis) > minimumAnalysisInterval else { return }
        lastAnalysis = currentDate
        
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        do {
            guard let model = try? MobileNetV3Large(),
                  let vnModel = try? VNCoreMLModel(for: model.model) else { return }
            
            let request = VNCoreMLRequest(model: vnModel) { [weak self] request, error in
                guard let results = request.results as? [VNClassificationObservation],
                      error == nil else { return }
                
                let normalizedResults = self?.normalizePercentages(results) ?? []
                let resultString = normalizedResults.map { result in
                    "\(result.identifier) (\(result.percentage)%)"
                }.joined(separator: "\n")
                
                DispatchQueue.main.async {
                    self?.classificationResult = resultString
                }
            }
            
            try VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .right).perform([request])
        } catch {
            print("Classification error: \(error.localizedDescription)")
        }
    }
    
    private func normalizePercentages(_ results: [VNClassificationObservation]) -> [(identifier: String, percentage: Int)] {
        var percentages = results.map { (identifier: $0.identifier, percentage: Int(round($0.confidence * 100))) }
        let totalPercentage = percentages.reduce(0) { $0 + $1.percentage }
        
        if totalPercentage != 100 {
            let diff = 100 - totalPercentage
            if let maxIndex = percentages.indices.max(by: { percentages[$0].percentage < percentages[$1].percentage }) {
                percentages[maxIndex].percentage += diff
            }
        }
        
        return percentages
    }
}
