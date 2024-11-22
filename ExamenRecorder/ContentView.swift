//
//  ContentView.swift
//  ExamenRecorder
//
//  Created by admin on 21.11.24.
//

import SwiftUI
import CoreData
import AVFoundation

class AudioRecorder: NSObject, ObservableObject {
    @Published var isRecording = false
    private var audioRecorder: AVAudioRecorder?
    private var recordingSession: AVAudioSession?
    
    override init() {
        super.init()
        setupSession()
    }
    
    private func setupSession() {
        recordingSession = AVAudioSession.sharedInstance()
        do {
            try recordingSession?.setCategory(.playAndRecord, mode: .default)
            try recordingSession?.setActive(true)
        } catch {
            print("Failed to set up recording session: \(error.localizedDescription)")
        }
    }
    
    func startRecording(completion: @escaping (URL?) -> Void) {
        let audioFilename = FileManager.default.temporaryDirectory.appendingPathComponent("recording.m4a")
        
        let settings = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        do {
            audioRecorder = try AVAudioRecorder(url: audioFilename, settings: settings)
            audioRecorder?.record()
            isRecording = true
            completion(audioFilename)
        } catch {
            print("Could not start recording: \(error.localizedDescription)")
            completion(nil)
        }
    }
    
    func stopRecording() -> URL? {
        audioRecorder?.stop()
        let recordingURL = audioRecorder?.url
        audioRecorder = nil
        isRecording = false
        return recordingURL
    }
}

class AudioPlayer: NSObject, ObservableObject {
    @Published var isPlaying = false
    private var audioPlayer: AVAudioPlayer?
    
    func startPlayback(audioData: Data) {
        do {
            audioPlayer = try AVAudioPlayer(data: audioData)
            audioPlayer?.delegate = self
            audioPlayer?.play()
            isPlaying = true
        } catch {
            print("Failed to play recording: \(error.localizedDescription)")
        }
    }
    
    func stopPlayback() {
        audioPlayer?.stop()
        audioPlayer = nil
        isPlaying = false
    }
}

extension AudioPlayer: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        DispatchQueue.main.async {
            self.isPlaying = false
        }
    }
}

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var audioRecorder = AudioRecorder()
    @State private var showingPermissionAlert = false
    @State private var currentRecordingURL: URL?

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Item.timestamp, ascending: false)],
        animation: .default)
    private var recordings: FetchedResults<Item>

    var body: some View {
        NavigationView {
            VStack {
                // Recording Button
                Button(action: {
                    if audioRecorder.isRecording {
                        if let recordingURL = audioRecorder.stopRecording() {
                            saveRecording(from: recordingURL)
                        }
                    } else {
                        requestMicrophonePermission()
                    }
                }) {
                    ZStack {
                        Circle()
                            .fill(audioRecorder.isRecording ? Color.red : Color.blue)
                            .frame(width: 70, height: 70)
                        
                        Image(systemName: audioRecorder.isRecording ? "stop.fill" : "mic.fill")
                            .foregroundColor(.white)
                            .font(.system(size: 30))
                    }
                    .padding()
                }
                
                // Recordings List
                List {
                    ForEach(recordings) { recording in
                        NavigationLink {
                            RecordingDetailView(recording: recording)
                        } label: {
                            RecordingRowView(recording: recording)
                        }
                    }
                    .onDelete(perform: deleteItems)
                }
            }
            .navigationTitle("Recordings")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton()
                }
            }
            .alert("Microphone Access Required", isPresented: $showingPermissionAlert) {
                Button("Settings", action: openSettings)
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Please grant microphone access to record audio.")
            }
        }
    }
    
    private func requestMicrophonePermission() {
        if #available(iOS 17.0, *) {
            AVAudioApplication.requestRecordPermission { granted in
                DispatchQueue.main.async {
                    if granted {
                        audioRecorder.startRecording { url in
                            if let url = url {
                                currentRecordingURL = url
                            } else {
                                print("Failed to set up recording")
                            }
                        }
                    } else {
                        showingPermissionAlert = true
                    }
                }
            }
        } else {
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                DispatchQueue.main.async {
                    if granted {
                        audioRecorder.startRecording { url in
                            if let url = url {
                                currentRecordingURL = url
                            } else {
                                print("Failed to set up recording")
                            }
                        }
                    } else {
                        showingPermissionAlert = true
                    }
                }
            }
        }
    }
    
    private func openSettings() {
        if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settingsUrl)
        }
    }
    
    private func saveRecording(from url: URL) {
        do {
            let audioData = try Data(contentsOf: url)
            
            let newItem = Item(context: viewContext)
            newItem.timestamp = Date()
            newItem.candidateRecording = audioData
            
            try viewContext.save()
            
            // Clean up the temporary file
            try FileManager.default.removeItem(at: url)
            currentRecordingURL = nil
            
        } catch {
            print("Error saving recording: \(error.localizedDescription)")
        }
    }

    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            offsets.map { recordings[$0] }.forEach(viewContext.delete)

            do {
                try viewContext.save()
            } catch {
                let nsError = error as NSError
                print("Unresolved error \(nsError), \(nsError.userInfo)")
            }
        }
    }
}

struct RecordingRowView: View {
    let recording: Item
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(recording.timestamp!, formatter: itemFormatter)
                .font(.headline)
            Text("Recording #\(recording.objectID.uriRepresentation().lastPathComponent)")
                .font(.subheadline)
                .foregroundColor(.gray)
        }
        .padding(.vertical, 4)
    }
}

struct RecordingDetailView: View {
    let recording: Item
    @StateObject private var audioPlayer = AudioPlayer()
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Recording Details")
                .font(.title)
            
            VStack(alignment: .leading, spacing: 10) {
                DetailRow(title: "Date", value: recording.timestamp!, formatter: itemFormatter)
                DetailRow(title: "ID", value: recording.objectID.uriRepresentation().lastPathComponent)
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(10)
            
            if let audioData = recording.candidateRecording {
                Button(action: {
                    if audioPlayer.isPlaying {
                        audioPlayer.stopPlayback()
                    } else {
                        audioPlayer.startPlayback(audioData: audioData)
                    }
                }) {
                    ZStack {
                        Circle()
                            .fill(audioPlayer.isPlaying ? Color.red : Color.green)
                            .frame(width: 60, height: 60)
                        
                        Image(systemName: audioPlayer.isPlaying ? "stop.fill" : "play.fill")
                            .foregroundColor(.white)
                            .font(.system(size: 25))
                    }
                }
                .padding()
                
                if audioPlayer.isPlaying {
                    Text("Playing...")
                        .foregroundColor(.secondary)
                }
            } else {
                Text("No audio recording available")
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding()
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear {
            // Stop playback when leaving the view
            if audioPlayer.isPlaying {
                audioPlayer.stopPlayback()
            }
        }
    }
}

struct DetailRow: View {
    let title: String
    let value: Any
    var formatter: Formatter? = nil
    
    var body: some View {
        HStack {
            Text(title)
                .font(.headline)
            Spacer()
            if let formatter = formatter, let date = value as? Date {
                Text(formatter.string(for: date) ?? "")
                    .foregroundColor(.secondary)
            } else {
                Text("\(value)")
                    .foregroundColor(.secondary)
            }
        }
    }
}

private let itemFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .short
    formatter.timeStyle = .medium
    return formatter
}()

#Preview {
    ContentView().environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
