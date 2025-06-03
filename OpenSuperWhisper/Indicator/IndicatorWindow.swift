import Cocoa
import SwiftUI

enum RecordingState {
    case idle
    case recording
    case decoding
}

@MainActor
protocol IndicatorViewDelegate: AnyObject {
    func didFinishDecoding()
}

@MainActor
class IndicatorViewModel: ObservableObject {
    @Published var state: RecordingState = .idle
    @Published var isBlinking = false
    @Published var recorder: AudioRecorder = .shared
    @Published var isVisible = false
    
    var delegate: IndicatorViewDelegate?
    private var blinkTimer: Timer?
    
    // Get a reference to the RecordingStore at initialization time
    private let recordingStore: RecordingStore
    
    init() {
        print("IndicatorViewModel initialized")
        self.recordingStore = RecordingStore.shared
        
        // Make sure the window is visible by default
        DispatchQueue.main.async {
            self.isVisible = true
        }
    }
    
    func startRecording() {
        print("IndicatorViewModel: startRecording called")
        state = .recording
        startBlinking()
        recorder.startRecording()
    }
    
    func startDecoding() {
        state = .decoding
        stopBlinking()
        
        if let tempURL = recorder.stopRecording() {
            // Get a reference to the transcription service
            let transcription = TranscriptionService.shared
            
            Task { [weak self] in
                guard let self = self else { return }
                
                do {
                    print("start decoding...")
                    let text = try await transcription.transcribeAudio(url: tempURL, settings: Settings())
                    
                    // Create a new Recording instance
                    let timestamp = Date()
                    let fileName = "\(Int(timestamp.timeIntervalSince1970)).wav"
                    let finalURL = Recording(
                        id: UUID(),
                        timestamp: timestamp,
                        fileName: fileName,
                        transcription: text,
                        duration: 0 // TODO: Get actual duration
                    ).url
                    
                    // Move the temporary recording to final location
                    try recorder.moveTemporaryRecording(from: tempURL, to: finalURL)
                    
                    // Save the recording to store
                    await MainActor.run {
                        self.recordingStore.addRecording(Recording(
                            id: UUID(),
                            timestamp: timestamp,
                            fileName: fileName,
                            transcription: text,
                            duration: 0 // TODO: Get actual duration
                        ))
                    }
                    
                    insertTextUsingPasteboard(text)
                    print("Transcription result: \(text)")
                } catch {
                    print("Error transcribing audio: \(error)")
                    try? FileManager.default.removeItem(at: tempURL)
                }
                
                await MainActor.run {
                    self.delegate?.didFinishDecoding()
                }
            }
        } else {
            
            print("!!! Not found record url !!!")
            
            Task {
                await MainActor.run {
                    self.delegate?.didFinishDecoding()
                }
            }
        }
    }
    
    func insertTextUsingPasteboard(_ text: String) {
        ClipboardUtil.insertTextUsingPasteboard(text)
    }
    
    private func startBlinking() {
        blinkTimer = Timer.scheduledTimer(withTimeInterval: 0.8, repeats: true) { [weak self] _ in
            // Update UI on the main thread
            Task { @MainActor in
                guard let self = self else { return }
                self.isBlinking.toggle()
            }
        }
    }
    
    private func stopBlinking() {
        blinkTimer?.invalidate()
        blinkTimer = nil
        isBlinking = false
    }

    func cancelRecording() {
        recorder.cancelRecording()
    }

    @MainActor
    func hideWithAnimation() async {
        await withCheckedContinuation { continuation in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                self.isVisible = false
            } completion: {
                continuation.resume()
            }
        }
    }
}

// Redesigned Recording Indicator
struct RecordingIndicator: View {
    let isBlinking: Bool
    
    var body: some View {
        ZStack {
            // Pulsating background for better visibility
            Circle()
                .fill(Color.red.opacity(0.3))
                .frame(width: 16, height: 16)
                .scaleEffect(isBlinking ? 1.5 : 1.0)
                .opacity(isBlinking ? 0.3 : 0.5)
                .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: isBlinking)
            
            // Main indicator dot
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.red.opacity(0.9),
                            Color.red
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 10, height: 10)
                .shadow(color: .red.opacity(0.6), radius: 4)
        }
    }
}

// Redesigned Transcription Indicator
struct TranscriptionIndicator: View {
    @State private var rotation = 0.0
    
    var body: some View {
        ZStack {
            // Background glow
            Circle()
                .fill(Color.blue.opacity(0.2))
                .frame(width: 16, height: 16)
            
            // Custom animated spinner
            Circle()
                .trim(from: 0.2, to: 0.8)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.blue.opacity(0.6),
                            Color.blue,
                            Color.blue.opacity(0.6)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    style: StrokeStyle(lineWidth: 2, lineCap: .round)
                )
                .frame(width: 12, height: 12)
                .rotationEffect(.degrees(rotation))
                .onAppear {
                    withAnimation(.linear(duration: 1.0).repeatForever(autoreverses: false)) {
                        rotation = 360.0
                    }
                }
        }
    }
}

struct IndicatorWindow: View {
    @ObservedObject var viewModel: IndicatorViewModel
    @Environment(\.colorScheme) private var colorScheme
    
    // Dynamic colors based on recording state
    private var accentColor: Color {
        switch viewModel.state {
        case .recording:
            return .red
        case .decoding:
            return .blue
        case .idle:
            return .gray
        }
    }
    
    private var backgroundColor: Color {
        colorScheme == .dark
            ? Color.black.opacity(0.16)
            : Color.white.opacity(0.16)
    }
    
    @State private var isHovering = false
    @State private var showContextMenu = false
    @State private var showTooltip = false
    
    var body: some View {
        let rect = RoundedRectangle(cornerRadius: 100)
        
        VStack(spacing: 0) {
            // Subtle drag handle at the top
            Rectangle()
                .fill(Color.primary.opacity(0.2))
                .frame(width: 36, height: 3)
                .cornerRadius(1.5)
                .padding(.top, 6)
                .padding(.bottom, -8)
                .opacity(isHovering ? 0.8 : 0.3)
            
            // Content area with properly centered elements
            HStack(alignment: .center, spacing: 10) {
                // Indicator icon aligned in the center vertically
                switch viewModel.state {
                case .recording:
                    RecordingIndicator(isBlinking: viewModel.isBlinking)
                        .frame(width: 16, height: 16)
                        
                case .decoding:
                    TranscriptionIndicator()
                        .frame(width: 16, height: 16)
                        
                case .idle:
                    EmptyView()
                }
                
                // Text label with vertical center alignment
                switch viewModel.state {
                case .recording:
                    Text("Recording...")
                        .font(.system(size: 12, weight: .light))
                        .foregroundStyle(Color.primary)
                        
                case .decoding:
                    Text("Transcribing...")
                        .font(.system(size: 12, weight: .light))
                        .foregroundStyle(Color.primary)
                        
                case .idle:
                    EmptyView()
                }
                
                Spacer(minLength: 0)
            }
            .frame(height: 40)
            .padding(.horizontal, 18)
        }
        .background {
            ZStack {
                // Blurred background
                rect
                    .fill(Material.ultraThinMaterial)
                
                // Border glow effect based on state
                rect
                    .stroke(accentColor.opacity(0.4), lineWidth: 1.5)
                    .blur(radius: 2)
                    .opacity(0.7)
                
                // Inner shadow for depth
                rect
                    .stroke(
                        LinearGradient(
                            colors: [
                                colorScheme == .dark 
                                    ? .white.opacity(0.08) 
                                    : .black.opacity(0.03),
                                .clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
            .compositingGroup()
            .shadow(
                color: accentColor.opacity(colorScheme == .dark ? 0.15 : 0.1), 
                radius: 8, 
                x: 0, 
                y: 4
            )
        }
        .clipShape(rect)
        .frame(width: 152)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovering = hovering
            }
            
            // Show tooltip briefly when hovering for the first time
            if hovering && !UserDefaults.standard.bool(forKey: "indicatorTooltipShown") {
                showTooltip = true
                UserDefaults.standard.set(true, forKey: "indicatorTooltipShown")
                
                // Hide tooltip after 4 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                    showTooltip = false
                }
            }
        }
        // Tooltip for instructions
        .overlay(alignment: .top) {
            if showTooltip {
                VStack(spacing: 4) {
                    Text("Drag to move")
                        .font(.system(size: 12, weight: .medium))
                    Text("Right-click for options")
                        .font(.system(size: 12, weight: .medium))
                    Text("Double-tap to reset position")
                        .font(.system(size: 12, weight: .medium))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.black.opacity(0.7))
                )
                .foregroundColor(.white)
                .offset(y: -60)
                .transition(.opacity)
                .zIndex(100)
            }
        }
        // Context menu for options
        .contextMenu {
            Button {
                IndicatorWindowManager.shared.resetPositionToDefault()
            } label: {
                Label("Reset Position", systemImage: "arrow.up.left.and.arrow.down.right")
            }
            
            Button {
                if viewModel.state == .recording {
                    viewModel.startDecoding()
                } else {
                    IndicatorWindowManager.shared.hide()
                }
            } label: {
                Label(
                    viewModel.state == .recording ? "Stop Recording" : "Close",
                    systemImage: viewModel.state == .recording ? "stop.circle" : "xmark.circle"
                )
            }
        }
        // Appearance animations
        .scaleEffect(viewModel.isVisible ? 1 : 0.5)
        .offset(y: viewModel.isVisible ? 0 : 20)
        .opacity(viewModel.isVisible ? 1 : 0)
        .animation(
            .spring(
                response: 0.3, 
                dampingFraction: 0.7, 
                blendDuration: 0.2
            ), 
            value: viewModel.isVisible
        )
        // State change animations
        .animation(
            .spring(
                response: 0.4, 
                dampingFraction: 0.8, 
                blendDuration: 0.2
            ), 
            value: viewModel.state
        )
        .onAppear {
            print("IndicatorWindow appeared")
            viewModel.isVisible = true
        }
    }
}

struct IndicatorWindowPreview: View {
    @StateObject private var recordingVM = {
        let vm = IndicatorViewModel()
        vm.startRecording()
        return vm
    }()
    
    @StateObject private var decodingVM = {
        let vm = IndicatorViewModel()
        vm.startDecoding()
        return vm
    }()
    
    var body: some View {
        VStack(spacing: 20) {
            IndicatorWindow(viewModel: recordingVM)
            IndicatorWindow(viewModel: decodingVM)
        }
        .padding()
        .frame(height: 200)
        .background(Color(.windowBackgroundColor))
    }
}

#Preview {
    IndicatorWindowPreview()
}
