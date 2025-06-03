//
//  OnboardingView.swift
//  FreeWhisper
//
//  Created by user on 08.02.2025.
//

import Foundation
import SwiftUI

class OnboardingViewModel: ObservableObject {
    @Published var selectedLanguage: String {
        didSet {
            AppPreferences.shared.whisperLanguage = selectedLanguage
        }
    }

    @Published var selectedModel: DownloadableModel?
    @Published var models: [DownloadableModel]
    @Published var isDownloadingAny: Bool = false
    @Published var currentStep: OnboardingStep = .welcome

    private let modelManager = WhisperModelManager.shared

    init() {
        let systemLanguage = LanguageUtil.getSystemLanguage()
        AppPreferences.shared.whisperLanguage = systemLanguage
        self.selectedLanguage = systemLanguage
        self.models = []
        initializeModels()

        if let defaultModel = models.first(where: { $0.name == "Turbo V3 large" }) {
            self.selectedModel = defaultModel
        }
    }

    private func initializeModels() {
        // Initialize models with their actual download status
        models = availableModels.map { model in
            var updatedModel = model
            updatedModel.isDownloaded = modelManager.isModelDownloaded(name: model.name)
            return updatedModel
        }
    }

    @MainActor
    func downloadSelectedModel() async throws {
        guard let model = selectedModel, !model.isDownloaded else { return }

        guard !isDownloadingAny else { return }
        isDownloadingAny = true

        do {
            // Find the index of the model we're downloading
            guard let modelIndex = models.firstIndex(where: { $0.name == model.name }) else {
                isDownloadingAny = false
                return
            }

            // Start the download with progress updates
            let filename = model.url.lastPathComponent

            try await modelManager.downloadModel(url: model.url, name: filename) { [weak self] progress in
                DispatchQueue.main.async {
                    self?.models[modelIndex].downloadProgress = progress
                    if progress >= 1.0 {
                        self?.models[modelIndex].isDownloaded = true
                        self?.isDownloadingAny = false
                        // Update the model path after successful download
                        if let modelPath = self?.modelManager.modelsDirectory.appendingPathComponent(filename).path {
                            AppPreferences.shared.selectedModelPath = modelPath
                            print("Model path after download: \(modelPath)")
                        }
                    }
                }
            }
        } catch {
            print("Failed to download model: \(error)")
            if let modelIndex = models.firstIndex(where: { $0.name == model.name }) {
                models[modelIndex].downloadProgress = 0
            }
            isDownloadingAny = false
            throw error
        }
    }
    
    func nextStep() {
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
            switch currentStep {
            case .welcome:
                currentStep = .language
            case .language:
                currentStep = .model
            case .model:
                break // Handled in the view
            }
        }
    }
    
    func previousStep() {
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
            switch currentStep {
            case .welcome:
                break
            case .language:
                currentStep = .welcome
            case .model:
                currentStep = .language
            }
        }
    }
}

enum OnboardingStep: Int, CaseIterable {
    case welcome = 0
    case language = 1
    case model = 2
    
    var title: String {
        switch self {
        case .welcome: return "Welcome"
        case .language: return "Language"
        case .model: return "Model"
        }
    }
}

struct OnboardingView: View {
    @StateObject private var viewModel = OnboardingViewModel()
    @EnvironmentObject private var appState: AppState
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var isVisible = false

    var body: some View {
        ZStack {
            backgroundGradient
            
            VStack(spacing: 0) {
                OnboardingHeader(currentStep: viewModel.currentStep)
                contentArea
                OnboardingFooter(
                    viewModel: viewModel,
                    onNext: handleNextButtonTap,
                    onPrevious: { viewModel.previousStep() }
                )
            }
        }
        .frame(width: 800, height: 700)
        .opacity(isVisible ? 1 : 0)
        .scaleEffect(isVisible ? 1 : 0.95)
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.8).delay(0.1)) {
                isVisible = true
            }
        }
        .alert("Download Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }
    
    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                Color(.windowBackgroundColor),
                Color(.controlBackgroundColor).opacity(0.5),
                Color(.windowBackgroundColor)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
    
    private var contentArea: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                ForEach(OnboardingStep.allCases, id: \.self) { step in
                    stepView(for: step)
                        .frame(width: geometry.size.width)
                }
            }
            .offset(x: -CGFloat(viewModel.currentStep.rawValue) * geometry.size.width)
            .animation(.spring(response: 0.6, dampingFraction: 0.8), value: viewModel.currentStep)
        }
    }
    
    @ViewBuilder
    private func stepView(for step: OnboardingStep) -> some View {
        switch step {
        case .welcome:
            WelcomeStepView()
        case .language:
            LanguageStepView(viewModel: viewModel)
        case .model:
            ModelStepView(viewModel: viewModel)
        }
    }

    private func handleNextButtonTap() {
        switch viewModel.currentStep {
        case .welcome, .language:
            viewModel.nextStep()
        case .model:
            guard let selectedModel = viewModel.selectedModel else { return }

            if selectedModel.isDownloaded {
                appState.hasCompletedOnboarding = true
            } else {
                Task {
                    do {
                        try await viewModel.downloadSelectedModel()
                        await MainActor.run {
                            appState.hasCompletedOnboarding = true
                        }
                    } catch {
                        await MainActor.run {
                            errorMessage = error.localizedDescription
                            showError = true
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Step Views

struct WelcomeStepView: View {
    @State private var animateElements = false
    
    var body: some View {
        VStack(spacing: 40) {
            Spacer()
            appIconSection
            featuresList
            Spacer()
        }
        .onAppear {
            animateElements = true
        }
    }
    
    private var appIconSection: some View {
        VStack(spacing: 24) {
            appIconWithGradient
            welcomeText
        }
    }
    
    private var appIconWithGradient: some View {
        ZStack {
            iconBackground
            iconImage
        }
        .scaleEffect(animateElements ? 1 : 0.8)
        .animation(.spring(response: 0.8, dampingFraction: 0.6).delay(0.2), value: animateElements)
    }
    
    private var iconBackground: some View {
        Circle()
            .fill(.ultraThinMaterial)
            .frame(width: 120, height: 120)
            .overlay(
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [.blue, .cyan],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 2
                    )
            )
    }
    
    private var iconImage: some View {
        Image(systemName: "waveform.circle.fill")
            .font(.system(size: 60, weight: .medium))
            .foregroundStyle(.linearGradient(colors: [.blue, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing))
    }
    
    private var welcomeText: some View {
        VStack(spacing: 16) {
            Text("Welcome to")
                .font(.system(size: 24, weight: .medium))
                .foregroundColor(.secondary)
                .opacity(animateElements ? 1 : 0)
                .animation(.easeInOut(duration: 0.6).delay(0.4), value: animateElements)
            
            Text("FreeWhisper")
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundStyle(.linearGradient(colors: [.primary, .secondary], startPoint: .leading, endPoint: .trailing))
                .opacity(animateElements ? 1 : 0)
                .animation(.easeInOut(duration: 0.6).delay(0.6), value: animateElements)
        }
    }
    
    private var featuresList: some View {
        VStack(spacing: 20) {
            FeatureRow(
                icon: "mic.circle.fill",
                title: "Voice Transcription",
                subtitle: "Convert speech to text with AI precision",
                delay: 0.8
            )
            
            FeatureRow(
                icon: "command.circle.fill",
                title: "Global Shortcuts",
                subtitle: "Record from anywhere with hotkeys",
                delay: 1.0
            )
            
            FeatureRow(
                icon: "brain.head.profile.fill",
                title: "Powered by Whisper AI",
                subtitle: "State-of-the-art speech recognition",
                delay: 1.2
            )
        }
        .padding(.horizontal, 40)
    }
}

struct LanguageStepView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    
    var body: some View {
        VStack(spacing: 40) {
            Spacer()
            
            OnboardingCard(
                icon: "globe.fill",
                iconColor: .green,
                title: "Choose Your Language",
                subtitle: "Select the primary language you'll be speaking"
            ) {
                languageSelector
            }
            
            Spacer()
        }
        .padding(.horizontal, 60)
    }
    
    private var languageSelector: some View {
        VStack(spacing: 20) {
            languagePicker
            
            Text("You can change this later in settings")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
        }
    }
    
    private var languagePicker: some View {
        HStack(spacing: 12) {
            // Globe icon in a green circle
            ZStack {
                Circle()
                    .fill(.green.opacity(0.1))
                    .frame(width: 40, height: 40)
                
                Image(systemName: "globe")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.green)
            }
            
            Text("Language")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.primary)
            
            Spacer()
            
            Picker("", selection: $viewModel.selectedLanguage) {
                ForEach(LanguageUtil.availableLanguages, id: \.self) { code in
                    Text(LanguageUtil.languageNames[code] ?? code)
                        .tag(code)
                }
            }
            .pickerStyle(.menu)
            .frame(minWidth: 120, maxWidth: 120)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.controlBackgroundColor).opacity(0.8))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                )
        )
        .frame(width: 320)
    }
}

struct ModelStepView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(.blue.opacity(0.1))
                        .frame(width: 60, height: 60)
                    
                    Image(systemName: "cpu")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(.blue)
                }
                
                VStack(spacing: 8) {
                    Text("Select AI Model")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    
                    Text("Choose the transcription model that best fits your needs")
                        .font(.system(size: 15))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.top, 40)
            .padding(.horizontal, 40)
            
            // Compact model list with proper spacing
            ScrollView {
                VStack(spacing: 12) {
                    ForEach($viewModel.models) { $model in
                        CompactModelCard(model: $model, viewModel: viewModel)
                    }
                }
                .padding(.horizontal, 40)
                .padding(.top, 32)
            }
            .frame(maxHeight: 360) // Constrain height to prevent covering buttons
            
            Spacer()
        }
    }
}

struct CompactModelCard: View {
    @Binding var model: DownloadableModel
    @ObservedObject var viewModel: OnboardingViewModel
    @State private var isHovered = false
    
    private var isSelected: Bool {
        viewModel.selectedModel?.name == model.name
    }
    
    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 16) {
                // Model info
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(model.name)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        if model.name == "Turbo V3 large" {
                            recommendedBadge
                        }
                        
                        Spacer()
                    }
                    
                    Text(model.sizeString)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                
                // Status indicator
                statusIndicator
            }
            
            // Performance bars
            HStack(spacing: 24) {
                CompactPerformanceBar(title: "Accuracy", value: model.accuracyRate, color: .mint)
                CompactPerformanceBar(title: "Speed", value: model.speedRate, color: .orange)
            }
        }
        .padding(16)
        .background(cardBackground)
        .contentShape(Rectangle())
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .onTapGesture {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                viewModel.selectedModel = model
            }
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
    }
    
    private var recommendedBadge: some View {
        Text("RECOMMENDED")
            .font(.system(size: 9, weight: .bold))
            .foregroundColor(.black)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                Capsule()
                    .fill(.mint)
            )
    }
    
    private var statusIndicator: some View {
        Group {
            if model.isDownloaded {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.mint)
            } else if model.downloadProgress > 0 && model.downloadProgress < 1 {
                progressCircle
            } else {
                Image(systemName: "arrow.down.circle")
                    .font(.system(size: 20))
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var progressCircle: some View {
        ZStack {
            Circle()
                .stroke(Color.gray.opacity(0.3), lineWidth: 2)
                .frame(width: 20, height: 20)
            
            Circle()
                .trim(from: 0, to: model.downloadProgress)
                .stroke(Color.mint, lineWidth: 2)
                .frame(width: 20, height: 20)
                .rotationEffect(.degrees(-90))
        }
    }
    
    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(isSelected ? Color.mint.opacity(0.08) : Color(.controlBackgroundColor).opacity(0.6))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.mint.opacity(0.5) : Color.gray.opacity(0.15), lineWidth: isSelected ? 1.5 : 1)
            )
            .shadow(color: isSelected ? Color.mint.opacity(0.1) : Color.clear, radius: 8, x: 0, y: 2)
    }
}

struct CompactPerformanceBar: View {
    let title: String
    let value: Int
    let color: Color
    
    var body: some View {
        VStack(spacing: 6) {
            Text(title)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.secondary)
            
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 50, height: 3)
                
                RoundedRectangle(cornerRadius: 2)
                    .fill(color)
                    .frame(width: 50 * Double(value) / 100, height: 3)
            }
            
            Text("\(value)%")
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Components

struct OnboardingHeader: View {
    let currentStep: OnboardingStep
    
    var body: some View {
        VStack(spacing: 20) {
            progressIndicator
            headerText
        }
    }
    
    private var progressIndicator: some View {
        HStack(spacing: 12) {
            ForEach(OnboardingStep.allCases, id: \.self) { step in
                Circle()
                    .fill(step.rawValue <= currentStep.rawValue ? Color.accentColor : Color.gray.opacity(0.3))
                    .frame(width: 10, height: 10)
                    .scaleEffect(step == currentStep ? 1.2 : 1.0)
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: currentStep)
            }
        }
        .padding(.top, 30)
    }
    
    private var headerText: some View {
        Text("Setup FreeWhisper")
            .font(.system(size: 16, weight: .medium))
            .foregroundColor(.secondary)
    }
}

struct OnboardingFooter: View {
    @ObservedObject var viewModel: OnboardingViewModel
    let onNext: () -> Void
    let onPrevious: () -> Void
    
    private var canProceed: Bool {
        switch viewModel.currentStep {
        case .welcome, .language:
            return true
        case .model:
            return viewModel.selectedModel != nil && !viewModel.isDownloadingAny
        }
    }
    
    private var nextButtonText: String {
        switch viewModel.currentStep {
        case .welcome, .language:
            return "Continue"
        case .model:
            if let model = viewModel.selectedModel {
                return model.isDownloaded ? "Get Started" : "Download & Continue"
            }
            return "Continue"
        }
    }
    
    var body: some View {
        VStack(spacing: 20) {
            Divider()
                .padding(.horizontal, 40)
            
            buttonRow
        }
    }
    
    private var buttonRow: some View {
        HStack {
            backButton
            Spacer()
            nextButton
        }
        .padding(.horizontal, 40)
        .padding(.bottom, 30)
    }
    
    private var backButton: some View {
        Group {
            if viewModel.currentStep != .welcome {
                Button("Back") {
                    onPrevious()
                }
                .buttonStyle(OnboardingSecondaryButtonStyle())
            } else {
                Button("") { }
                    .buttonStyle(OnboardingSecondaryButtonStyle())
                    .opacity(0)
                    .disabled(true)
            }
        }
    }
    
    private var nextButton: some View {
        Button(nextButtonText) {
            onNext()
        }
        .buttonStyle(OnboardingPrimaryButtonStyle())
        .disabled(!canProceed)
    }
}

struct OnboardingCard<Content: View>: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    let content: Content
    
    init(icon: String, iconColor: Color, title: String, subtitle: String, @ViewBuilder content: () -> Content) {
        self.icon = icon
        self.iconColor = iconColor
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }
    
    var body: some View {
        VStack(spacing: 24) {
            cardHeader
            content
        }
        .padding(32)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }
    
    private var cardHeader: some View {
        VStack(spacing: 16) {
            cardIcon
            cardText
        }
    }
    
    private var cardIcon: some View {
        ZStack {
            Circle()
                .fill(.ultraThinMaterial)
                .frame(width: 60, height: 60)
                .overlay(
                    Circle()
                        .stroke(iconColor.opacity(0.3), lineWidth: 2)
                )
            
            Image(systemName: "translate")
                .font(.system(size: 24, weight: .medium))
                .foregroundColor(iconColor)
        }
    }
    
    private var cardText: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
            
            Text(subtitle)
                .font(.system(size: 15))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let delay: Double
    @State private var animateElements = false
    
    var body: some View {
        HStack(spacing: 16) {
            featureIcon
            featureText
            Spacer()
        }
        .opacity(animateElements ? 1 : 0)
        .offset(x: animateElements ? 0 : -50)
        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(delay), value: animateElements)
        .onAppear {
            animateElements = true
        }
    }
    
    private var featureIcon: some View {
        Image(systemName: icon)
            .font(.system(size: 20, weight: .medium))
            .foregroundStyle(.linearGradient(colors: [.blue, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing))
            .frame(width: 32, height: 32)
    }
    
    private var featureText: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.primary)
            
            Text(subtitle)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Button Styles

struct OnboardingPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 28)
            .padding(.vertical, 10)
            .background(primaryButtonBackground)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.8), value: configuration.isPressed)
    }
    
    private var primaryButtonBackground: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(
                LinearGradient(
                    colors: [.blue, .cyan.opacity(0.8)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .shadow(color: .mint.opacity(0.3), radius: 6, x: 0, y: 3)
    }
}

struct OnboardingSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .medium))
            .foregroundColor(.secondary)
            .padding(.horizontal, 28)
            .padding(.vertical, 10)
            .background(secondaryButtonBackground)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.8), value: configuration.isPressed)
    }
    
    private var secondaryButtonBackground: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(Color(.controlBackgroundColor).opacity(0.8))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.gray.opacity(0.15), lineWidth: 1)
            )
    }
}

// MARK: - Existing Models (keeping the same data structure)

struct DownloadableModel: Identifiable {
    let id = UUID()
    let name: String
    var isDownloaded: Bool
    let url: URL
    let size: Int
    var speedRate: Int
    var accuracyRate: Int
    var downloadProgress: Double = 0.0

    var sizeString: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useGB]
        formatter.countStyle = .file
        formatter.includesUnit = true
        formatter.isAdaptive = true
        return formatter.string(fromByteCount: Int64(size) * 1000000)
    }

    init(name: String, isDownloaded: Bool, url: URL, size: Int, speedRate: Int, accuracyRate: Int) {
        self.name = name
        self.isDownloaded = isDownloaded
        self.url = url
        self.size = size
        self.speedRate = speedRate
        self.accuracyRate = accuracyRate
    }
}

let availableModels = [
    DownloadableModel(
        name: "Turbo V3 large",
        isDownloaded: false,
        url: URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v3-turbo.bin?download=true")!,
        size: 1624,
        speedRate: 60,
        accuracyRate: 100
    ),
    DownloadableModel(
        name: "Turbo V3 medium",
        isDownloaded: false,
        url: URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v3-turbo-q8_0.bin?download=true")!,
        size: 874,
        speedRate: 70,
        accuracyRate: 70
    ),
    DownloadableModel(
        name: "Turbo V3 small",
        isDownloaded: false,
        url: URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v3-turbo-q5_0.bin?download=true")!,
        size: 574,
        speedRate: 100,
        accuracyRate: 60
    )
]

#Preview {
    OnboardingView()
}
