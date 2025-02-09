//
//  ViewComponents.swift
//  Image Classifier
//
//  Created by Kristian Emil on 19/12/2024.
//

import SwiftUI

// MARK: - Background View
struct BackgroundView: View {
    let image: UIImage?
    let isClassifying: Bool
    
    var body: some View {
        ZStack {
            if let image = image {
                GeometryReader { geometry in
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .blur(radius: isClassifying ? 20 : 0)
                        .animation(.easeInOut(duration: 0.5), value: isClassifying)
                }
            } else {
                Color.black
            }
        }
        .ignoresSafeArea()
    }
}

// MARK: - Empty State View
struct EmptyStateView: View {
    @ObservedObject var viewModel: ClassificationViewModel
    @State private var isAnimating = false
    @Environment(\.verticalSizeClass) var verticalSizeClass
    
    private var isCompactHeight: Bool {
        verticalSizeClass == .compact
    }
    
    var body: some View {
        VStack(spacing: isCompactHeight ? 12 : 16) {
            Image(systemName: "camera.viewfinder")
                .font(.system(size: isCompactHeight ? 48 : 64))
                .foregroundColor(.secondary)
                .scaleEffect(isAnimating ? 1.1 : 1.0)
                .animation(
                    Animation
                        .spring(response: 0.5, dampingFraction: 0.6)
                        .repeatForever(autoreverses: true),
                    value: isAnimating
                )
            Text("Tap to capture an object")
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onTapGesture {
            viewModel.sourceType = .camera
            viewModel.showingCamera = true
        }
        .onAppear {
            isAnimating = true
        }
    }
}

// MARK: - Classification Results Card
struct ClassificationResultsCard: View {
    let results: String
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @Environment(\.verticalSizeClass) var verticalSizeClass
    
    private var isCompactHeight: Bool {
        verticalSizeClass == .compact
    }
    
    private var spacing: CGFloat {
        isCompactHeight ? 8 : 16
    }
    
    private func parseResult(_ result: String) -> (label: String, confidence: Int)? {
        let components = result.components(separatedBy: " (")
        guard components.count == 2,
              let confidenceStr = components[1].components(separatedBy: "%").first,
              let confidence = Int(confidenceStr) else {
            return nil
        }
        return (components[0], confidence)
    }
    
    var body: some View {
                VStack(alignment: .leading, spacing: spacing) {
            Text("Classifications")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            VStack(spacing: isCompactHeight ? 8 : 12) {
                let parsedResults = results.components(separatedBy: "\n")
                    .compactMap(parseResult)
                    .filter { $0.confidence > 0 }
                    .sorted { $0.confidence > $1.confidence }
                    .prefix(3)
                
                ForEach(parsedResults, id: \.label) { parsed in
                    HStack(spacing: 12) {
                        Text("\(parsed.confidence)%")
                            .font(.system(.body, design: .rounded))
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .frame(width: 60)
                            .padding(.vertical, isCompactHeight ? 4 : 6)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.blue.opacity(Double(parsed.confidence) / 100.0))
                            )
                        
                        Text(parsed.label)
                            .font(.system(.body, design: .rounded))
                            .foregroundColor(.primary)
                            .lineLimit(2)
                        
                        Spacer()
                    }
                    .padding(.vertical, isCompactHeight ? 2 : 4)
                    
                    if parsed.label != parsedResults.last?.label {
                        Divider()
                    }
                }
            }
        }
        .padding(isCompactHeight ? 12 : 16)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Controls View
struct ControlsView: View {
        
    @ObservedObject var viewModel: ClassificationViewModel
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @Environment(\.verticalSizeClass) var verticalSizeClass
    let hasImage: Bool
    
    private var isCompactHeight: Bool {
        verticalSizeClass == .compact
    }
    
    private var controlSpacing: CGFloat {
        isCompactHeight ? 12 : 20
    }
    
    private var controlHeight: CGFloat {
        if hasImage {
            return isCompactHeight ? 70 : 100
        } else {
            return isCompactHeight ? 100 : 140
        }
    }
    
    var body: some View {

        HStack(spacing: controlSpacing) {
            ActionButton(
                icon: "camera",
                label: "Camera",
                action: {
                    viewModel.sourceType = .camera
                    viewModel.showingCamera = true
                },
                isDisabled: !UIImagePickerController.isSourceTypeAvailable(.camera),
                hasImage: hasImage,
                width: nil
            )
            
            ActionButton(
                icon: "photo",
                label: "Library",
                action: {
                    viewModel.sourceType = .photoLibrary
                    viewModel.showingImagePicker = true
                },
                hasImage: hasImage,
                width: nil
            )
        }
        .frame(height: controlHeight)
    }
}

// MARK: - Action Button
struct ActionButton: View {
    let icon: String
    let label: String
    let action: () -> Void
    var isDisabled: Bool = false
    var hasImage: Bool
    var width: CGFloat?
    
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @Environment(\.verticalSizeClass) var verticalSizeClass
    
    private var isCompactHeight: Bool {
        verticalSizeClass == .compact
    }
    
    private var height: CGFloat {
        if hasImage {
            return isCompactHeight ? 70 : 100
        } else {
            return isCompactHeight ? 100 : 140
        }
    }
    
    private var iconSize: CGFloat {
        if hasImage {
            return isCompactHeight ? 24 : 30
        } else {
            return isCompactHeight ? 32 : 40
        }
    }
    
    private var fontSize: CGFloat {
        if hasImage {
            return isCompactHeight ? 12 : 14
        } else {
            return isCompactHeight ? 14 : 16
        }
    }
    
    private var spacing: CGFloat {
        hasImage ? (isCompactHeight ? 8 : 12) : (isCompactHeight ? 12 : 16)
    }
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: spacing) {
                Image(systemName: icon)
                    .font(.system(size: iconSize))
                Text(label)
                    .font(.system(size: fontSize, weight: .medium))
            }
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .foregroundColor(.primary)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: isCompactHeight ? 16 : 20))
        }
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.6 : 1)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: hasImage)
    }
}
