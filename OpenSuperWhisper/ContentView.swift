//
//  ContentView.swift
//  OpenSuperWhisper
//
//  Created by user on 05.02.2025.
//

import AVFoundation
import KeyboardShortcuts
import SwiftUI
import UniformTypeIdentifiers
import AppKit

@MainActor
class ContentViewModel: ObservableObject {
    @Published var state: RecordingState = .idle
    @Published var isBlinking = false
    @Published var recorder: AudioRecorder = .shared
    @Published var transcriptionService = TranscriptionService.shared
    @Published var recordingStore = RecordingStore.shared
    @Published var recordingDuration: TimeInterval = 0

    private var blinkTimer: Timer?
    private var recordingStartTime: Date?
    private var durationTimer: Timer?

    var isRecording: Bool {
        recorder.isRecording
    }
    
    func startRecording() {
        state = .recording
        startBlinking()
        recordingStartTime = Date()
        recordingDuration = 0
        
        // Start timer to track recording duration
        durationTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            // Capture the start time in a local variable to avoid actor isolation issues
            let startTime = Date()
            
            // Update duration on the main thread
            Task { @MainActor in
                if let recordingStartTime = self.recordingStartTime {
                    self.recordingDuration = startTime.timeIntervalSince(recordingStartTime)
                }
            }
        }
        RunLoop.current.add(durationTimer!, forMode: .common)
        
        recorder.startRecording()
    }

    func startDecoding() {
        state = .decoding
        stopBlinking()
        stopDurationTimer()

        if let tempURL = recorder.stopRecording() {
            Task { [weak self] in
                guard let self = self else { return }

                do {
                    print("start decoding...")
                    let text = try await transcriptionService.transcribeAudio(url: tempURL, settings: Settings())

                    // Capture the current recording duration
                    let duration = await MainActor.run { self.recordingDuration }
                    
                    // Create a new Recording instance
                    let timestamp = Date()
                    let fileName = "\(Int(timestamp.timeIntervalSince1970)).wav"
                    let finalURL = Recording(
                        id: UUID(),
                        timestamp: timestamp,
                        fileName: fileName,
                        transcription: text,
                        duration: duration // Use tracked duration
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
                            duration: self.recordingDuration // Use tracked duration
                        ))
                    }

                    print("Transcription result: \(text)")
                } catch {
                    print("Error transcribing audio: \(error)")
                    try? FileManager.default.removeItem(at: tempURL)
                }

                await MainActor.run {
                    self.state = .idle
                    self.recordingDuration = 0
                }
            }
        }
    }

    private func stopDurationTimer() {
        durationTimer?.invalidate()
        durationTimer = nil
        recordingStartTime = nil
    }

    private func startBlinking() {
        blinkTimer = Timer.scheduledTimer(withTimeInterval: 0.8, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.isBlinking.toggle()
            }
        }
        RunLoop.current.add(blinkTimer!, forMode: .common)
    }

    private func stopBlinking() {
        blinkTimer?.invalidate()
        blinkTimer = nil
        isBlinking = false
    }
}

struct ContentView: View {
    @StateObject private var viewModel = ContentViewModel()
    @StateObject private var permissionsManager = PermissionsManager()
    @State private var isSettingsPresented = false
    @State private var searchText = ""
    @State private var showDeleteConfirmation = false

    private var filteredRecordings: [Recording] {
        let baseRecordings = viewModel.recordingStore.recordings
        
        // Filter by search
        let searchFiltered = searchText.isEmpty ? baseRecordings : 
            baseRecordings.filter { $0.transcription.localizedCaseInsensitiveContains(searchText) }
        
        return searchFiltered
    }

    var body: some View {
        ZStack {
            if !permissionsManager.isMicrophonePermissionGranted || !permissionsManager.isAccessibilityPermissionGranted {
                PermissionsView(permissionsManager: permissionsManager)
            } else {
                VStack(spacing: 0) {
                    // Elegant minimal header
                    AppHeader(
                        searchText: $searchText,
                        isSettingsPresented: $isSettingsPresented,
                        recordingCount: filteredRecordings.count
                    )
                    
                    // Full height workspace
                    NotesWorkspace(
                        recordings: filteredRecordings,
                        searchText: searchText,
                        viewModel: viewModel,
                        onClearAll: { showDeleteConfirmation = true }
                    )
                }
                
                // Overlay recording control with blur effect
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        FloatingRecordingControl(viewModel: viewModel)
                        Spacer()
                    }
                    .padding(.bottom, 32)
                }
            }
        }
        .frame(minWidth: 800, minHeight: 600)
        .background(Color(.windowBackgroundColor))
        .overlay {
            if viewModel.transcriptionService.isLoading && 
               permissionsManager.isMicrophonePermissionGranted && 
               permissionsManager.isAccessibilityPermissionGranted {
                Color.black.opacity(0.5)
                    .overlay {
                        VStack(spacing: 20) {
                            ProgressView()
                                .scaleEffect(1.8)
                                .tint(.white)
                            
                            Text("Loading Whisper Model...")
                                .foregroundColor(.white)
                                .font(.title3)
                                .fontWeight(.medium)
                        }
                        .padding(32)
                        .background(Color.black.opacity(0.8))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    .ignoresSafeArea()
            }
        }
        .fileDropHandler()
        .sheet(isPresented: $isSettingsPresented) {
            SettingsView()
        }
        .confirmationDialog("Delete All Recordings", isPresented: $showDeleteConfirmation) {
            Button("Delete All", role: .destructive) {
                viewModel.recordingStore.deleteAllRecordings()
            }
        } message: {
            Text("This will permanently delete all recordings from your workspace.")
        }
    }
}

// Elegant minimal header
struct AppHeader: View {
    @Binding var searchText: String
    @Binding var isSettingsPresented: Bool
    let recordingCount: Int
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                // Left section - Title and count
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Voice Notes")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                        
                        if recordingCount > 0 {
                            Text("\(recordingCount) note\(recordingCount == 1 ? "" : "s")")
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundColor(.secondary)
                        } else {
                            Text("No notes yet")
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Spacer()
                
                // Right section - Search and controls
                HStack(spacing: 16) {
                    Spacer()
                    // Search field
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                            .font(.system(size: 14, weight: .medium))
                        
                        TextField("Search", text: $searchText)
                            .textFieldStyle(.plain)
                            .font(.system(size: 15, weight: .regular, design: .rounded))
                        
                        if !searchText.isEmpty {
                            Button {
                                searchText = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                                    .font(.system(size: 14))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical,8)
                    .background(Color(.controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 24))
                    .frame(width: 320)
                    
                    Spacer()
                    
                    // Settings
                    Button {
                        isSettingsPresented = true
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.secondary)
                            .frame(width: 32, height: 32)
                            .background(Color(.controlBackgroundColor))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 20)
            
            // Subtle divider
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [.clear, .secondary.opacity(0.15), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 1)
        }
    }
}

// Main workspace area
struct NotesWorkspace: View {
    let recordings: [Recording]
    let searchText: String
    @ObservedObject var viewModel: ContentViewModel
    let onClearAll: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            if recordings.isEmpty {
                EmptyNotesState(searchText: searchText)
            } else {
                // Revolutionary timeline notes feed
                GroupedNotesView(recordings: recordings)
            }
        }
    }
}

// Revolutionary timeline notes view
struct GroupedNotesView: View {
    let recordings: [Recording]
    
    // Group recordings by date
    private var groupedRecordings: [(String, [Recording])] {
        let grouped = Dictionary(grouping: recordings) { recording in
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .none
            return formatter.string(from: recording.timestamp)
        }
        
        return grouped.sorted { $0.key > $1.key }
    }
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 24) {
                ForEach(groupedRecordings, id: \.0) { dateString, dayRecordings in
                    NotesDateSection(
                        dateString: dateString,
                        recordings: dayRecordings
                    )
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
        }
    }
}

// Timeline section for each day
struct NotesDateSection: View {
    let dateString: String
    let recordings: [Recording]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Date header with line
            HStack {
                Text(dateString)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(.primary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color(.controlBackgroundColor))
                    )
                
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [.gray.opacity(0.3), .clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(height: 1)
            
                Spacer()
            }
            
            // Notes list
            VStack(spacing: 12) {
                ForEach(recordings) { recording in
                    CleanNoteCard(recording: recording)
                }
            }
        }
    }
}

// Clean note card without timeline dots
struct CleanNoteCard: View {
    let recording: Recording
    @StateObject private var audioRecorder = AudioRecorder.shared
    @StateObject private var recordingStore = RecordingStore.shared
    @State private var isHovered = false
    @State private var isExpanded = false
    @State private var showActions = false
    
    private var isPlaying: Bool {
        audioRecorder.isPlaying && audioRecorder.currentlyPlayingURL == recording.url
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: -15) {
            // Header with time, duration, and actions
            HStack {
                Text(recording.timestamp, style: .time)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
                
                if recording.duration > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "waveform")
                            .font(.system(size: 10))
                        Text(formatDuration(recording.duration))
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color.secondary.opacity(0.1))
                    )
                }
                
                Spacer()
                
                // Playing indicator
                if isPlaying {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(.red)
                            .frame(width: 6, height: 6)
                            .scaleEffect(1.2)
                            .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: isPlaying)
                        
                        Text("Playing")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundColor(.red)
                    }
                }
                
                // Action buttons (inside card)
                CleanActionBar(
                    recording: recording,
                    isPlaying: isPlaying,
                    onPlay: {
                        if isPlaying {
                            audioRecorder.stopPlaying()
                        } else {
                            audioRecorder.playRecording(url: recording.url)
                        }
                    },
                    onCopy: {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(recording.transcription, forType: .string)
                    },
                    onDelete: {
                        if isPlaying { audioRecorder.stopPlaying() }
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                            recordingStore.deleteRecording(recording)
                        }
                    }
                )
                .opacity(showActions ? 1.0 : 0.0)
                .offset(y: showActions ? 10 : -10)
                .animation(.easeInOut(duration: 0.3), value: showActions)
            }
            .offset(y: -10)
            
            // Note text - Always use expanded behavior
            Text(recording.transcription)
                .font(.system(size: 13, weight: .regular, design: .default))
                .lineLimit(isExpanded ? nil : 4)
                .foregroundColor(.primary)
                .textSelection(.enabled)
                .lineSpacing(2)
            
            // Expand/collapse if content is long
            if recording.transcription.count > 200 {
                Button {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        isExpanded.toggle()
                    }
                } label: {
                    Text(isExpanded ? "Show less" : "Show more")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(.accentColor)
                }
                .buttonStyle(.plain)
                .padding(.top, 0)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.textBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(isHovered ? .accentColor.opacity(0.2) : Color(.separatorColor).opacity(0.3), lineWidth: 1)
                )
        )
        .shadow(
            color: .black.opacity(0.05),
            radius: 8,
            x: 0,
            y: 4
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
                showActions = hovering
            }
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// Clean action bar for note cards
struct CleanActionBar: View {
    let recording: Recording
    let isPlaying: Bool
    let onPlay: () -> Void
    let onCopy: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 8) {
            CleanActionButton(
                icon: isPlaying ? "pause.fill" : "play.fill",
                color: isPlaying ? .red : .accentColor,
                action: onPlay
            )
            
            CleanActionButton(
                icon: "doc.on.doc.fill",
                color: .secondary,
                action: onCopy
            )
            
            CleanActionButton(
                icon: "trash.fill",
                color: .red,
                action: onDelete
            )
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 200)
                .fill(Color(.windowBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 200)
                        .stroke(Color(.separatorColor).opacity(0.3), lineWidth: 0.5)
                )
        )
    }
}

// Clean action button
struct CleanActionButton: View {
    let icon: String
    let color: Color
    let action: () -> Void
    @State private var isPressed = false
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(color)
                .frame(width: 28, height: 28)
                .background(
                    Circle()
                        .fill(color.opacity(isPressed ? 0.2 : 0.1))
                )
                .scaleEffect(isPressed ? 0.95 : 1.0)
        }
        .buttonStyle(.plain)
        .pressEvents {
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = true
            }
        } onRelease: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                isPressed = false
            }
        }
    }
}

// Custom press events view modifier
extension View {
    func pressEvents(onPress: @escaping () -> Void, onRelease: @escaping () -> Void) -> some View {
        self.simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in onPress() }
                .onEnded { _ in onRelease() }
        )
    }
}

// Empty state
struct EmptyNotesState: View {
    let searchText: String
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            if !searchText.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary.opacity(0.4))
                    
                    Text("No matching notes")
                        .font(.title3)
                        .fontWeight(.medium)
                    
                    Text("Try adjusting your search terms")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
            } else {
                VStack(spacing: 20) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary.opacity(0.4))
                    
                    Text("No notes yet")
                        .font(.title3)
                        .fontWeight(.medium)
                    
                    Text("Start recording to create your first voice note")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

// Floating recording control (restored better design)
struct FloatingRecordingControl: View {
    @ObservedObject var viewModel: ContentViewModel
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: 0) {
            // Recording status indicator
            ZStack {
                // Outer pulsing ring
                Circle()
                    .stroke(statusColor.opacity(0.2), lineWidth: 1)
                    .frame(width: 48, height: 48)
                    .scaleEffect(viewModel.isRecording ? 1.3 : 1.0)
                    .opacity(viewModel.isRecording ? 0.4 : 0.0)
                    .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: viewModel.isRecording)
                
                // Main record button
                Button {
                    if viewModel.isRecording {
                        viewModel.startDecoding()
                    } else {
                        viewModel.startRecording()
                    }
                } label: {
                    ZStack {
                        Circle()
                            .fill(statusColor)
                            .frame(width: 44, height: 44)
                        
                        if viewModel.state == .decoding {
                            ProgressView()
                                .scaleEffect(0.8)
                                .tint(.white)
                        } else {
                            Image(systemName: viewModel.isRecording ? "stop.fill" : "mic.fill")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white)
                        }
                    }
                }
                .buttonStyle(.plain)
                .scaleEffect(isHovered ? 1.1 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
                .disabled(viewModel.transcriptionService.isLoading)
                .onHover { hovering in
                    isHovered = hovering
                }
            }
            
            // Status text (only when recording/processing)
            if viewModel.isRecording || viewModel.state == .decoding {
                HStack(spacing: 8) {
                    Rectangle()
                        .fill(Color.white.opacity(0.3))
                        .frame(width: 1, height: 20)
                        .padding(.leading, 16)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(statusText)
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundColor(.white)
                        
                        if viewModel.isRecording {
                            Text(formatDuration(viewModel.recordingDuration))
                                .font(.system(size: 11, weight: .regular, design: .rounded))
                                .foregroundColor(.white.opacity(0.8))
                        }
                    }
                    .padding(.trailing, 16)
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .leading).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
            }
        }
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .environment(\.colorScheme, .dark)
        )
        .overlay(
            Capsule()
                .stroke(
                    LinearGradient(
                        colors: [.white.opacity(0.2), .white.opacity(0.05)],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 0.5
                )
        )
        .shadow(color: .black.opacity(0.15), radius: 12, x: 0, y: 6)
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: viewModel.isRecording)
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: viewModel.state)
    }
    
    private var statusColor: Color {
        switch viewModel.state {
        case .recording: return .red
        case .decoding: return .orange
        case .idle: return Color(red: 0.2, green: 0.6, blue: 1.0)
        }
    }
    
    private var statusText: String {
        switch viewModel.state {
        case .recording: return "Recording"
        case .decoding: return "Processing"
        case .idle: return ""
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

struct PermissionsView: View {
    @ObservedObject var permissionsManager: PermissionsManager
    @State private var showingRestartAlert = false
    @State private var isVisible = false
    @State private var currentPermissionIndex = 0
    
    private let permissions = [
        PermissionItem(
            icon: "mic",
            title: "Microphone",
            description: "We'll use this to capture your voice notes",
            details: "Your audio stays private and is processed locally on your device"
        ),
        PermissionItem(
            icon: "keyboard",
            title: "Accessibility",
            description: "For quick access with keyboard shortcuts",
            details: "Record voice notes instantly from anywhere with ⌥ + `"
        )
    ]
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Clean background
                Color(.windowBackgroundColor)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    Spacer()
                    
                    // Main content
                    VStack(spacing: 48) {
                        // Welcome header
                        WelcomeHeader()
                            .opacity(isVisible ? 1 : 0)
                            .offset(y: isVisible ? 0 : 20)
                            .animation(.spring(response: 0.8, dampingFraction: 0.8).delay(0.1), value: isVisible)
                        
                        // Permission cards
                        VStack(spacing: 20) {
                            MinimalPermissionCard(
                                permission: permissions[0],
                                isGranted: permissionsManager.isMicrophonePermissionGranted,
                                action: {
                                    permissionsManager.requestMicrophonePermissionOrOpenSystemPreferences()
                                }
                            )
                            .opacity(isVisible ? 1 : 0)
                            .offset(y: isVisible ? 0 : 30)
                            .animation(.spring(response: 0.8, dampingFraction: 0.8).delay(0.3), value: isVisible)
                            
                            MinimalPermissionCard(
                                permission: permissions[1],
                                isGranted: permissionsManager.isAccessibilityPermissionGranted,
                                action: {
                                    permissionsManager.openSystemPreferences(for: .accessibility)
                                }
                            )
                            .opacity(isVisible ? 1 : 0)
                            .offset(y: isVisible ? 0 : 30)
                            .animation(.spring(response: 0.8, dampingFraction: 0.8).delay(0.5), value: isVisible)
                        }
                        .frame(maxWidth: 400)
                        
                        // Progress indicator
                        ProgressIndicator(
                            total: 2,
                            completed: completedPermissionsCount
                        )
                        .opacity(isVisible ? 1 : 0)
                        .animation(.spring(response: 0.8, dampingFraction: 0.8).delay(0.7), value: isVisible)
                        
                        // Help section (only show if needed)
                        if completedPermissionsCount < 2 {
                            HelpSection(
                                showingRestartAlert: $showingRestartAlert,
                                permissionsManager: permissionsManager
                            )
                            .opacity(isVisible ? 1 : 0)
                            .animation(.spring(response: 0.8, dampingFraction: 0.8).delay(0.9), value: isVisible)
                        }
                    }
                    
                    Spacer()
                    Spacer() // Extra space at bottom
                }
                .padding(.horizontal, 40)
            }
        }
        .onAppear {
            isVisible = true
        }
    }
    
    private var completedPermissionsCount: Int {
        var count = 0
        if permissionsManager.isMicrophonePermissionGranted { count += 1 }
        if permissionsManager.isAccessibilityPermissionGranted { count += 1 }
        return count
    }
}

struct PermissionItem {
    let icon: String
    let title: String
    let description: String
    let details: String
}

// Welcome header component
struct WelcomeHeader: View {
    var body: some View {
        VStack(spacing: 16) {
            // App icon
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
                .frame(width: 64, height: 64)
                .overlay(
                    Image(systemName: "waveform")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(.primary)
                )
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
            
            VStack(spacing: 8) {
                Text("Welcome to OpenSuperWhisper")
                    .font(.system(size: 24, weight: .semibold, design: .rounded))
                    .foregroundColor(.primary)
                
                Text("Let's set up a couple of permissions to get you started")
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }
}

// Modern button component
struct ModernButton: View {
    let title: String
    let action: () -> Void
    let style: ButtonStyle
    @State private var isPressed = false
    @State private var isHovered = false
    
    enum ButtonStyle {
        case primary
        case secondary
        case accent
        
        var backgroundColor: Color {
            switch self {
            case .primary: return Color.accentColor
            case .secondary: return Color(.controlBackgroundColor)
            case .accent: return Color.blue
            }
        }
        
        var foregroundColor: Color {
            switch self {
            case .primary: return .white
            case .secondary: return .primary
            case .accent: return .white
            }
        }
    }
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundColor(style.foregroundColor)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(style.backgroundColor)
                        .shadow(
                            color: style.backgroundColor.opacity(0.3),
                            radius: isPressed ? 2 : 8,
                            x: 0,
                            y: isPressed ? 2 : 4
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(
                                    LinearGradient(
                                        colors: [
                                            Color.white.opacity(isHovered ? 0.4 : 0.2),
                                            Color.clear
                                        ],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    ),
                                    lineWidth: 1
                                )
                        )
                )
                .scaleEffect(isPressed ? 0.96 : (isHovered ? 1.02 : 1.0))
                .animation(.spring(response: 0.2, dampingFraction: 0.8), value: isPressed)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
        .pressEvents {
            isPressed = true
        } onRelease: {
            isPressed = false
        }
    }
}

// Minimal permission card with improved buttons
struct MinimalPermissionCard: View {
    let permission: PermissionItem
    let isGranted: Bool
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 16) {
                // Icon
                ZStack {
                    Circle()
                        .fill(isGranted ? Color.green.opacity(0.1) : Color.blue.opacity(0.08))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: isGranted ? "checkmark" : permission.icon)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(isGranted ? .green : .blue)
                }
                .padding(.top, 2)
                
                // Content - Allow it to expand
                VStack(alignment: .leading, spacing: 6) {
                    Text(permission.title)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    Text(permission.description)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .lineLimit(nil)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                // Action button or status
                VStack {
                    if isGranted {
                        HStack(spacing: 8) {
                            ZStack {
                                Circle()
                                    .fill(Color.green.opacity(0.1))
                                    .frame(width: 24, height: 24)
                                
                                Image(systemName: "checkmark")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.green)
                            }
                            
                            Text("Granted")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundColor(.green)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(Color.green.opacity(0.05))
                                .overlay(
                                    Capsule()
                                        .stroke(Color.green.opacity(0.2), lineWidth: 1)
                                )
                        )
                    } else {
                        ModernButton(
                            title: "Allow",
                            action: action,
                            style: .accent
                        )
                    }
                }
            }
            .padding(.vertical, 20)
            .padding(.horizontal, 24)
            
            // Details section (only show for non-granted permissions)
            if !isGranted {
                VStack(spacing: 0) {
                    Divider()
                        .padding(.horizontal, 24)
                    
                    HStack(alignment: .center, spacing: 12) {
                        Image(systemName: "info.circle")
                            .font(.system(size: 14))
                            .foregroundColor(.blue.opacity(0.8))
                            .padding(.top, 2)
                        
                        Text(permission.details)
                            .font(.system(size: 12, weight: .light))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                            .lineLimit(nil)
                        
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 16)
                    .background(Color.blue.opacity(0.02))
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.textBackgroundColor))
                .shadow(
                    color: .black.opacity(isHovered ? 0.08 : 0.04),
                    radius: isHovered ? 12 : 8,
                    x: 0,
                    y: isHovered ? 6 : 2
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            isHovered ? Color.blue.opacity(0.1) : Color.gray.opacity(0.08),
                            lineWidth: 1
                        )
                )
        )
        .scaleEffect(isHovered ? 1.005 : 1.0) // Much more subtle scale effect
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// Progress indicator
struct ProgressIndicator: View {
    let total: Int
    let completed: Int
    
    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                ForEach(0..<total, id: \.self) { index in
                    Circle()
                        .fill(index < completed ? Color.primary : Color.gray.opacity(0.2))
                        .frame(width: 8, height: 8)
                        .scaleEffect(index < completed ? 1.2 : 1.0)
                        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: completed)
                }
            }
            
            Text("\(completed) of \(total) permissions granted")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundColor(.secondary)
        }
    }
}

// Help section for troubleshooting
struct HelpSection: View {
    @Binding var showingRestartAlert: Bool
    let permissionsManager: PermissionsManager
    @State private var isExpanded = false
    
    var body: some View {
        VStack(spacing: 16) {
            Button {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 8) {
                    Text("Need help?")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(.plain)
            
            if isExpanded {
                VStack(spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Permissions not working?")
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundColor(.primary)
                            
                            Text("Sometimes a restart helps refresh the permission status")
                                .font(.system(size: 13, weight: .regular))
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Button("Restart") {
                            showingRestartAlert = true
                        }
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.gray.opacity(0.08))
                        .clipShape(Capsule())
                    }
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.04))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray.opacity(0.1), lineWidth: 1)
                        )
                )
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .scale(scale: 0.95)),
                    removal: .opacity.combined(with: .scale(scale: 0.95))
                ))
            }
        }
        .alert("Restart Application", isPresented: $showingRestartAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Restart") {
                permissionsManager.restartAppToRefreshPermissions()
            }
        } message: {
            Text("The app will restart to refresh permission status.")
        }
    }
}

// Keep the original PermissionRow for reference (can be removed)
struct PermissionRow: View {
    let isGranted: Bool
    let title: String
    let description: String
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: isGranted ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundColor(isGranted ? .green : .red)

                Text(title)
                    .font(.headline)

                Spacer()

                if !isGranted {
                    Button("Grant Access") {
                        action()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }

            Text(description)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(10)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
