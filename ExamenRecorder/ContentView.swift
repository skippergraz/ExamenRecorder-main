//
//  ContentView.swift
//  ExamenRecorder
//
//  Created by admin on 21.11.24.
//

import SwiftUI
import AVFoundation
import CoreData

extension Institution {
    var identifier: UUID {
        id ?? UUID()
    }
}

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
        let uuid = UUID().uuidString
        let audioFilename = FileManager.default.temporaryDirectory.appendingPathComponent("\(uuid).m4a")
        
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

struct Level: Identifiable, Hashable {
    let id = UUID()
    var name: String
    
    static func == (lhs: Level, rhs: Level) -> Bool {
        return lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

struct Institute: Identifiable {
    let id = UUID()
    var name: String
    var street: String
    var city: String
    var country: String
    var postalCode: String
}

struct InstituteFormView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @State private var instituteName: String
    @State private var street: String
    @State private var city: String
    @State private var country: String
    @State private var postalCode: String
    @State private var showAlert = false
    
    var institute: Institution?
    var isEditing: Bool
    
    init(institute: Institution? = nil) {
        self.institute = institute
        self.isEditing = institute != nil
        
        // Initialize state variables
        _instituteName = State(initialValue: institute?.name ?? "")
        _street = State(initialValue: institute?.street ?? "")
        _city = State(initialValue: institute?.city ?? "")
        _country = State(initialValue: institute?.country ?? "")
        _postalCode = State(initialValue: institute?.postalCode ?? "")
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Institute Details")) {
                    TextField("Name", text: $instituteName)
                    TextField("Street", text: $street)
                    TextField("City", text: $city)
                    TextField("Country", text: $country)
                    TextField("Postal Code", text: $postalCode)
                }
            }
            .navigationTitle(isEditing ? "Edit Institute" : "Add Institute")
            .navigationBarItems(
                leading: Button("Cancel") {
                    dismiss()
                },
                trailing: Button(isEditing ? "Update" : "Save") {
                    if isEditing {
                        updateInstitute()
                    } else {
                        saveNewInstitute()
                    }
                }
                .disabled(instituteName.isEmpty)
            )
        }
        .alert("Error", isPresented: $showAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Failed to \(isEditing ? "update" : "save") institute")
        }
    }
    
    private func updateInstitute() {
        guard let institute = institute else { return }
        
        institute.name = instituteName
        institute.street = street
        institute.city = city
        institute.country = country
        institute.postalCode = postalCode
        
        do {
            try viewContext.save()
            dismiss()
        } catch {
            showAlert = true
        }
    }
    
    private func saveNewInstitute() {
        let newInstitute = Institution(context: viewContext)
        newInstitute.id = UUID()
        newInstitute.name = instituteName
        newInstitute.street = street
        newInstitute.city = city
        newInstitute.country = country
        newInstitute.postalCode = postalCode
        newInstitute.timestamp = Date()
        
        do {
            try viewContext.save()
            dismiss()
        } catch {
            showAlert = true
        }
    }
}

struct SettingsView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @State private var levels: [Level] = [
        Level(name: "A1"),
        Level(name: "A2"),
        Level(name: "B1"),
        Level(name: "B2"),
        Level(name: "C1"),
        Level(name: "C2")
    ]
    @State private var newLevelName = ""
    @State private var showingInstituteForm = false
    @State private var selectedInstitute: Institution?
    
    @FetchRequest(
        entity: Institution.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \Institution.timestamp, ascending: false)],
        animation: .default)
    private var institutes: FetchedResults<Institution>
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Add New Level")) {
                    HStack {
                        TextField("Level Name", text: $newLevelName)
                        Button(action: addLevel) {
                            Image(systemName: "plus.circle.fill")
                        }
                        .disabled(newLevelName.isEmpty)
                    }
                }
                
                Section(header: Text("Existing Levels")) {
                    ForEach(levels) { level in
                        Text(level.name)
                    }
                    .onDelete(perform: deleteLevels)
                }
                
                Section(header: Text("Institutes")) {
                    Button(action: {
                        selectedInstitute = nil
                        showingInstituteForm = true
                    }) {
                        Label("Add Institute", systemImage: "plus")
                    }
                    
                    ForEach(institutes) { institute in
                        Button(action: {
                            selectedInstitute = institute
                            showingInstituteForm = true
                        }) {
                            VStack(alignment: .leading) {
                                Text(institute.name ?? "")
                                    .font(.headline)
                                Text("\(institute.street ?? ""), \(institute.city ?? "")")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                            }
                        }
                        .foregroundColor(.primary)
                    }
                    .onDelete(perform: deleteInstitutes)
                }
            }
            .navigationTitle("Settings")
            .navigationBarItems(
                leading: Button("Done") {
                    dismiss()
                }
            )
        }
        .sheet(isPresented: $showingInstituteForm) {
            if let institute = selectedInstitute {
                InstituteFormView(institute: institute)
            } else {
                InstituteFormView()
            }
        }
    }
    
    private func addLevel() {
        let newLevel = Level(name: newLevelName)
        levels.append(newLevel)
        newLevelName = ""
    }
    
    private func deleteLevels(at offsets: IndexSet) {
        levels.remove(atOffsets: offsets)
    }
    
    private func deleteInstitutes(at offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                let institute = institutes[index]
                viewContext.delete(institute)
            }
            
            do {
                try viewContext.save()
            } catch {
                print("Error deleting institute: \(error.localizedDescription)")
            }
        }
    }
}

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var audioRecorder = AudioRecorder()
    @State private var showingPermissionAlert = false
    @State private var currentRecordingURL: URL?
    @State private var showingSettings = false

    @FetchRequest(
        entity: Item.entity(),
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
                    HStack {
                        EditButton()
                        Button(action: { showingSettings = true }) {
                            Image(systemName: "gear")
                        }
                    }
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
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
            newItem.id = UUID()
            newItem.candidateRecording = audioData
            
            withAnimation {
                do {
                    try viewContext.save()
                } catch {
                    print("Error saving context: \(error.localizedDescription)")
                }
            }
            
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
