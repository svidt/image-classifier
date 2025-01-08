//
//  ContentView.swift
//  Image Classifier
//
//  Created by Kristian Emil on 19/12/2024.
//

import SwiftUI
import CoreML
import Vision


struct ContentView: View {
    @StateObject private var viewModel = ClassificationViewModel()
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @Environment(\.verticalSizeClass) var verticalSizeClass
    @State private var isImageFullscreen = false
    @State private var captureMode: CaptureMode = .photo
    
    private var isCompactHeight: Bool {
        verticalSizeClass == .compact
    }
    
    private var isCompactWidth: Bool {
        horizontalSizeClass == .compact
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    if viewModel.selectedImage == nil {
                        EmptyStateView(viewModel: viewModel)
                    } else {
                        ScrollView(showsIndicators: false) {
                            VStack(spacing: isImageFullscreen ? 0 : isCompactHeight ? 8 : 16) {
                                // Image Container
                                GeometryReader { imageGeometry in
                                    ZStack {
                                        Image(uiImage: viewModel.selectedImage!)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(
                                                maxWidth: isImageFullscreen ? .infinity : geometry.size.width - (isCompactHeight ? 16 : 32),
                                                maxHeight: isImageFullscreen ? .infinity : calculateImageHeight(geometry: geometry)
                                            )
                                            .frame(
                                                width: isImageFullscreen ? geometry.size.width : nil,
                                                height: isImageFullscreen ? geometry.size.height : nil
                                            )
                                            .clipShape(RoundedRectangle(cornerRadius: isCompactHeight ? 15 : 25))
                                            .blur(radius: viewModel.isClassifying ? 20 : 0)
                                            .animation(.easeInOut(duration: 0.5), value: viewModel.isClassifying)
                                    }
                                    .frame(maxWidth: .infinity, maxHeight: isImageFullscreen ? .infinity : calculateImageHeight(geometry: geometry))
                                }
                                .frame(height: isImageFullscreen ? geometry.size.height : calculateImageHeight(geometry: geometry))
                                .contentShape(Rectangle())
                                .gesture(
                                    DragGesture()
                                        .onEnded { value in
                                            let verticalTranslation = value.translation.height
                                            let verticalVelocity = value.predictedEndTranslation.height - value.translation.height
                                            let threshold: CGFloat = 50
                                            
                                            if isImageFullscreen {
                                                if verticalTranslation < -threshold || verticalVelocity < -threshold {
                                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                                        isImageFullscreen = false
                                                    }
                                                }
                                            } else {
                                                if verticalTranslation > threshold || verticalVelocity > threshold {
                                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                                        isImageFullscreen = true
                                                    }
                                                }
                                            }
                                        }
                                )
                                .onTapGesture {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                        isImageFullscreen.toggle()
                                    }
                                }
                                
                                if !isImageFullscreen {
                                    // Results and Controls Container
                                    VStack(spacing: isCompactHeight ? 12 : 16) {
                                        if !viewModel.classificationResult.isEmpty {
                                            if viewModel.classificationResult.hasPrefix("Error:") {
                                                ErrorView(message: viewModel.classificationResult)
                                                    .transition(.scale.combined(with: .opacity))
                                            } else {
                                                ClassificationResultsCard(results: viewModel.classificationResult)
                                                    .transition(.scale.combined(with: .opacity))
                                            }
                                        }
                                        
                                        Spacer(minLength: 0)
                                        
                                        ControlsView(viewModel: viewModel, hasImage: true)
                                            .padding(.bottom, geometry.safeAreaInsets.bottom)
                                    }
                                    .frame(minHeight: isCompactHeight ? geometry.size.height * 0.25 : geometry.size.height * 0.4)
                                    .padding(.horizontal, isCompactHeight ? 8 : 16)
                                }
                            }
                        }
                        .scrollDisabled(isImageFullscreen)
                    }
                    
                    if viewModel.selectedImage == nil {
                        ControlsView(viewModel: viewModel, hasImage: false)
                            .padding(.horizontal, isCompactHeight ? 8 : 16)
                            .padding(.bottom, geometry.safeAreaInsets.bottom)
                    }
                }
            }
        }
        .sheet(isPresented: $viewModel.showingImagePicker) {
            ImagePicker(
                image: $viewModel.selectedImage,
                sourceType: viewModel.sourceType,
                completionHandler: viewModel.performClassification
            )
        }
        .sheet(isPresented: $viewModel.showingCamera) {
            CameraView { image in
                viewModel.selectedImage = image
                viewModel.performClassification()
            }
        }
        .alert("Camera Not Available",
               isPresented: .constant(!UIImagePickerController.isSourceTypeAvailable(.camera))) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("This device does not have a camera available.")
        }
        .animation(.easeInOut(duration: 0.3), value: viewModel.classificationResult)
    }
}

enum CaptureMode {
    case photo
    case liveVideo
}

// MARK: - Helper Methods
extension ContentView {
    private func calculateImageHeight(geometry: GeometryProxy) -> CGFloat {
        if isCompactHeight {
            // Landscape phone
            return min(geometry.size.height * 0.7, 300)
        } else if isCompactWidth {
            // Portrait phone
            return min(geometry.size.height * 0.45, 400)
        } else {
            // iPad and larger displays
            return min(geometry.size.height * 0.5, 500)
        }
    }
}


// MARK: - Error View
struct ErrorView: View {
    let message: String
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundColor(.yellow)
            
            Text(message)
                .font(.headline)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

#Preview {
    ContentView()
        .preferredColorScheme(.dark)
}
