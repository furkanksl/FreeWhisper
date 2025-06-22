import SwiftUI

struct ModelContent: View {
    @ObservedObject var viewModel: SettingsViewModel
    @State private var showModelDownloadSheet = false
    
    var body: some View {
        VStack(spacing: 20) {
            GlassCard(
                title: "Active Model",
                subtitle: "Choose your transcription model",
                icon: "brain.head.profile.fill"
            ) {
                VStack(spacing: 16) {
                    SettingRow(
                        title: "Current Model",
                        subtitle: "Selected Whisper model",
                        icon: "cpu"
                    ) {
                        Picker("", selection: $viewModel.selectedModelURL) {
                            ForEach(viewModel.availableModels, id: \.self) { url in
                                Text(url.lastPathComponent)
                                    .tag(url as URL?)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(width: 160)
                    }
                    
                    SettingRow(
                        title: "Models Folder",
                        subtitle: "Open models directory",
                        icon: "folder"
                    ) {
                        Button("Open") {
                            NSWorkspace.shared.open(WhisperModelManager.shared.modelsDirectory)
                        }
                        .buttonStyle(GlassButtonStyle())
                        .controlSize(.small)
                    }
                }
            }
            
            GlassCard(
                title: "Download Models",
                subtitle: "Get additional Whisper models",
                icon: "arrow.down.circle.fill"
            ) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Choose from pre-configured models or add your own GGML format models.")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                    
                    HStack {
                        Button("Download Models") {
                            showModelDownloadSheet = true
                        }
                        .buttonStyle(GlassButtonStyle())
                        
                        Link("Browse HuggingFace", destination: URL(string: "https://huggingface.co/ggerganov/whisper.cpp/tree/main")!)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.accentColor)
                    }
                }
            }
        }
        .sheet(isPresented: $showModelDownloadSheet) {
            ModelDownloadView(onDismiss: {
                showModelDownloadSheet = false
                viewModel.loadAvailableModels() // Refresh models after download
            })
            .frame(width: 600, height: 500)
        }
    }
}

struct ModelDownloadView: View {
    let onDismiss: () -> Void
    @StateObject private var viewModel = ModelDownloadViewModel()
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Download Whisper Models")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Select a model to download")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button("Done") {
                    onDismiss()
                }
                .buttonStyle(GlassButtonStyle())
            }
            .padding(.horizontal)
            .padding(.top)
            
            // Model List
            ScrollView {
                VStack(spacing: 12) {
                    ForEach($viewModel.models) { $model in
                        ModelDownloadCard(model: $model, viewModel: viewModel)
                    }
                }
                .padding()
            }
        }
        .background(Color(.windowBackgroundColor))
    }
}

struct ModelDownloadCard: View {
    @Binding var model: DownloadableModel
    @ObservedObject var viewModel: ModelDownloadViewModel
    @State private var isHovered = false
    
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
                            Text("RECOMMENDED")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.black)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    Capsule()
                                        .fill(Color.mint)
                                )
                        }
                        
                        Spacer()
                    }
                    
                    Text(model.sizeString)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                
                // Status indicator
                Group {
                    if model.isDownloaded {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.mint)
                    } else if model.downloadProgress > 0 && model.downloadProgress < 1 {
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
                    } else {
                        Button(action: {
                            viewModel.downloadModel(model)
                        }) {
                            Image(systemName: "arrow.down.circle")
                                .font(.system(size: 20))
                                .foregroundColor(.accentColor)
                        }
                        .buttonStyle(.plain)
                        .disabled(viewModel.isDownloadingAny)
                    }
                }
            }
            
            // Performance bars
            HStack(spacing: 24) {
                PerformanceBar(title: "Accuracy", value: model.accuracyRate, color: .mint)
                PerformanceBar(title: "Speed", value: model.speedRate, color: .orange)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.controlBackgroundColor).opacity(0.6))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.gray.opacity(0.15), lineWidth: 1)
                )
        )
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

struct PerformanceBar: View {
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

class ModelDownloadViewModel: ObservableObject {
    @Published var models: [DownloadableModel] = []
    @Published var isDownloadingAny: Bool = false
    
    private let modelManager = WhisperModelManager.shared
    
    init() {
        initializeModels()
    }
    
    private func initializeModels() {
        // Initialize models with their actual download status
        models = availableModels.map { model in
            var updatedModel = model
            updatedModel.isDownloaded = modelManager.isModelDownloaded(name: model.url.lastPathComponent)
            return updatedModel
        }
    }
    
    func downloadModel(_ model: DownloadableModel) {
        guard !model.isDownloaded && !isDownloadingAny else { return }
        
        isDownloadingAny = true
        
        // Find the index of the model we're downloading
        guard let modelIndex = models.firstIndex(where: { $0.id == model.id }) else {
            isDownloadingAny = false
            return
        }
        
        Task {
            do {
                // Start the download with progress updates
                let filename = model.url.lastPathComponent
                
                try await modelManager.downloadModel(url: model.url, name: filename) { [weak self] progress in
                    DispatchQueue.main.async {
                        self?.models[modelIndex].downloadProgress = progress
                        if progress >= 1.0 {
                            self?.models[modelIndex].isDownloaded = true
                            self?.isDownloadingAny = false
                        }
                    }
                }
            } catch {
                print("Failed to download model: \(error)")
                DispatchQueue.main.async {
                    self.models[modelIndex].downloadProgress = 0
                    self.isDownloadingAny = false
                }
            }
        }
    }
} 