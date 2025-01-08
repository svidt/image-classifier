//
//  ClassificationViewModel.swift
//  Image Classifier
//
//  Created by Kristian Emil on 19/12/2024.
//

import SwiftUI
import Vision
import CoreML


class ClassificationViewModel: ObservableObject {
    @Published var selectedImage: UIImage?
    @Published var classificationResult: String = ""
    @Published var showingImagePicker = false
    @Published var showingCamera = false
    @Published var isClassifying = false
    @Published var sourceType: UIImagePickerController.SourceType = .photoLibrary
    
    private let hapticFeedback = UINotificationFeedbackGenerator()
    
    func performClassification() {
        hapticFeedback.prepare()
        isClassifying = true
        classificationResult = ""
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.classifyImage()
        }
    }
    
    private func normalizePercentages(_ results: [VNClassificationObservation]) -> [(identifier: String, percentage: Int)] {
        // Convert confidences to percentages and round to nearest integer
        var percentages = results.map { (identifier: $0.identifier, percentage: Int(round($0.confidence * 100))) }
        
        // Calculate the sum of all percentages
        let totalPercentage = percentages.reduce(0) { $0 + $1.percentage }
        
        // If sum isn't 100, adjust the largest value to make it 100
        if totalPercentage != 100 {
            let diff = 100 - totalPercentage
            if let maxIndex = percentages.indices.max(by: { percentages[$0].percentage < percentages[$1].percentage }) {
                percentages[maxIndex].percentage += diff
            }
        }
        
        return percentages
    }
    
    private func classifyImage() {
        guard let image = selectedImage,
              let ciImage = CIImage(image: image) else {
            isClassifying = false
            hapticFeedback.notificationOccurred(.error)
            return
        }
        
        do {
            guard let model = try? MobileNetV3Large(),
                  let vnModel = try? VNCoreMLModel(for: model.model) else {
                classificationResult = "Failed to load classification model"
                isClassifying = false
                hapticFeedback.notificationOccurred(.error)
                return
            }
            
            let request = VNCoreMLRequest(model: vnModel) { [weak self] request, error in
                if let error = error {
                    self?.classificationResult = "Error: \(error.localizedDescription)"
                    self?.isClassifying = false
                    self?.hapticFeedback.notificationOccurred(.error)
                    return
                }
                
                guard let results = request.results as? [VNClassificationObservation] else {
                    self?.classificationResult = "No results found"
                    self?.isClassifying = false
                    self?.hapticFeedback.notificationOccurred(.warning)
                    return
                }
                
                DispatchQueue.main.async {
                    // Normalize percentages to ensure they sum to 100
                    let normalizedResults = self?.normalizePercentages(results) ?? []
                    
                    // Verify total is 100%
                    let total = normalizedResults.reduce(0) { $0 + $1.percentage }
                    print("Total percentage: \(total)%")
                    
                    // Create result string
                    self?.classificationResult = normalizedResults.map { result in
                        "\(result.identifier) (\(result.percentage)%)"
                    }.joined(separator: "\n")
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        self?.isClassifying = false
                        self?.hapticFeedback.notificationOccurred(.success)
                    }
                }
            }
            
            let handler = VNImageRequestHandler(ciImage: ciImage)
            try handler.perform([request])
            
        } catch {
            classificationResult = "Classification error: \(error.localizedDescription)"
            isClassifying = false
            hapticFeedback.notificationOccurred(.error)
        }
    }
}
