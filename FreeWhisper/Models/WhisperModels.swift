import Foundation

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