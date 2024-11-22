//
//  ContentView.swift
//  ExamenRecorder
//
//  Created by admin on 21.11.24.
//

import SwiftUI
import CoreData
import AVFoundation
import UIKit

struct InstitutionModel: Identifiable {
    let id: UUID
    let name: String
    let street: String?
    let city: String?
    let postalCode: String?
    let country: String?
    
    init(entity: Institution) {
        self.id = entity.id ?? UUID()
        self.name = entity.name ?? ""
        self.street = entity.street
        self.city = entity.city
        self.postalCode = entity.postalCode
        self.country = entity.country
    }
}

extension InstitutionModel {
    var identifier: UUID {
        id
    }
}

class AudioRecorder: NSObject, ObservableObject {
    private var audioRecorder: AVAudioRecorder?
    @Published var isRecording = false
    
    func startRecording(completion: @escaping (URL?) -> Void) {
        let audioFilename = getDocumentsDirectory().appendingPathComponent("\(UUID().uuidString).m4a")
        
        let settings = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 2,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        do {
            try AVAudioSession.sharedInstance().setCategory(.playAndRecord, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            
            audioRecorder = try AVAudioRecorder(url: audioFilename, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.record()
            isRecording = true
            completion(audioFilename)
        } catch {
            print("Could not start recording: \(error.localizedDescription)")
            completion(nil)
        }
    }
    
    func stopRecording() -> URL? {
        guard let recorder = audioRecorder, recorder.isRecording else { return nil }
        
        recorder.stop()
        isRecording = false
        let url = recorder.url
        audioRecorder = nil
        return url
    }
    
    private func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
}

extension AudioRecorder: AVAudioRecorderDelegate {
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if !flag {
            print("Recording failed")
        }
        isRecording = false
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

struct InstitutionFormView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var instituteName: String
    @State private var street: String
    @State private var city: String
    @State private var country: String
    @State private var postalCode: String
    @State private var showAlert = false
    
    var institution: Institution?
    var isEditing: Bool
    
    init(institution: Institution? = nil) {
        self.institution = institution
        self.isEditing = institution != nil
        
        // Initialize state variables
        _instituteName = State(initialValue: institution?.name ?? "")
        _street = State(initialValue: institution?.street ?? "")
        _city = State(initialValue: institution?.city ?? "")
        _country = State(initialValue: institution?.country ?? "")
        _postalCode = State(initialValue: institution?.postalCode ?? "")
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Institution Details")) {
                    TextField("Institution Name", text: $instituteName)
                    TextField("Street", text: $street)
                    TextField("City", text: $city)
                    TextField("Country", text: $country)
                    TextField("Postal Code", text: $postalCode)
                }
            }
            .navigationTitle(isEditing ? "Edit Institution" : "New Institution")
            .navigationBarItems(
                leading: Button("Cancel") {
                    dismiss()
                },
                trailing: Button(isEditing ? "Save" : "Add") {
                    if isEditing {
                        updateInstitute()
                    } else {
                        saveNewInstitute()
                    }
                }
            )
            .alert("Error", isPresented: $showAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Failed to save institution. Please try again.")
            }
        }
    }
    
    private func updateInstitute() {
        guard let institute = institution else { return }
        
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
    @State private var showingInstituteForm = false
    @State private var selectedInstitute: Institution?
    
    @FetchRequest(
        entity: Institution.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \Institution.name, ascending: true)],
        animation: .default)
    private var institutions: FetchedResults<Institution>
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Institutes")) {
                    Button(action: {
                        showingInstituteForm = true
                    }) {
                        Label("Add Institute", systemImage: "plus")
                    }
                    
                    ForEach(institutions) { institution in
                        Button(action: {
                            selectedInstitute = institution
                            showingInstituteForm = true
                        }) {
                            VStack(alignment: .leading) {
                                Text(institution.name ?? "")
                                    .font(.headline)
                                if let street = institution.street,
                                   let city = institution.city {
                                    Text("\(street), \(city)")
                                        .font(.subheadline)
                                        .foregroundColor(.gray)
                                }
                            }
                        }
                        .foregroundColor(.primary)
                    }
                    .onDelete(perform: deleteInstitutes)
                }
            }
            .navigationTitle("Settings")
            .navigationBarItems(trailing: Button("Done") {
                dismiss()
            })
            .sheet(isPresented: $showingInstituteForm) {
                InstitutionFormView(institution: selectedInstitute)
                    .environment(\.managedObjectContext, viewContext)
            }
        }
    }
    
    private func deleteInstitutes(at offsets: IndexSet) {
        withAnimation {
            offsets.map { institutions[$0] }.forEach(viewContext.delete)
            
            do {
                try viewContext.save()
            } catch {
                print("Error deleting institution: \(error)")
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
    @State private var showingInstitutionPicker = false
    @State private var selectedInstitutionId: UUID?

    @FetchRequest(
        entity: Item.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \Item.timestamp, ascending: false)],
        animation: .default)
    private var recordings: FetchedResults<Item>
    
    @FetchRequest(
        entity: Institution.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \Institution.name, ascending: true)],
        animation: .default)
    private var institutionEntities: FetchedResults<Institution>
    
    private var institutions: [InstitutionModel] {
        institutionEntities.map { InstitutionModel(entity: $0) }
    }
    
    private var selectedInstitution: InstitutionModel? {
        institutions.first { $0.id == selectedInstitutionId }
    }

    var body: some View {
        NavigationView {
            VStack {
                // Institution Selection
                HStack {
                    Text("Selected Institution:")
                        .foregroundColor(.gray)
                    Button(action: {
                        showingInstitutionPicker = true
                    }) {
                        Text(selectedInstitution?.name ?? "Select Institution")
                            .foregroundColor(selectedInstitution != nil ? .primary : .blue)
                    }
                }
                .padding()
                
                // Recording Button
                Button(action: {
                    if audioRecorder.isRecording {
                        if let recordingURL = audioRecorder.stopRecording() {
                            saveRecording(from: recordingURL)
                        }
                    } else {
                        if selectedInstitutionId != nil {
                            requestMicrophonePermission()
                        } else {
                            showingInstitutionPicker = true
                        }
                    }
                }) {
                    ZStack {
                        Circle()
                            .fill(audioRecorder.isRecording ? Color.red : (selectedInstitutionId != nil ? Color.blue : Color.gray))
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
                            RecordingDetailView(recording: recording, institutions: institutions)
                        } label: {
                            RecordingRowView(recording: recording, institutions: institutions)
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
            .sheet(isPresented: $showingInstitutionPicker) {
                NavigationView {
                    List(institutions) { institution in
                        Button(action: {
                            selectedInstitutionId = institution.id
                            showingInstitutionPicker = false
                        }) {
                            VStack(alignment: .leading) {
                                Text(institution.name)
                                    .font(.headline)
                                if let street = institution.street,
                                   let city = institution.city {
                                    Text("\(street), \(city)")
                                        .font(.subheadline)
                                        .foregroundColor(.gray)
                                }
                            }
                        }
                        .foregroundColor(.primary)
                    }
                    .navigationTitle("Select Institution")
                    .navigationBarItems(trailing: Button("Cancel") {
                        showingInstitutionPicker = false
                    })
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
            print("Audio data size: \(audioData.count) bytes")
            
            let newItem = Item(context: viewContext)
            newItem.timestamp = Date()
            newItem.id = UUID()
            newItem.candidateRecording = audioData
            newItem.institutionId = selectedInstitutionId
            
            withAnimation {
                do {
                    try viewContext.save()
                    print("Recording saved successfully to Core Data")
                } catch {
                    print("Error saving context: \(error.localizedDescription)")
                }
            }
            
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
                print("Error deleting recording: \(error.localizedDescription)")
            }
        }
    }
}

struct RecordingRowView: View {
    let recording: Item
    let institutions: [InstitutionModel]
    @State private var duration: TimeInterval = 0
    
    private var institution: InstitutionModel? {
        institutions.first { $0.id == recording.institutionId }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(recording.timestamp!, formatter: itemFormatter)
                .font(.headline)
            HStack {
                Text("Recording #\(recording.objectID.uriRepresentation().lastPathComponent)")
                if let institution = institution {
                    Text("• \(institution.name)")
                }
                Spacer()
                Text(formatDuration(duration))
                    .foregroundColor(.gray)
            }
            .font(.subheadline)
            .foregroundColor(.gray)
        }
        .padding(.vertical, 4)
        .task {
            await calculateDuration()
        }
    }
    
    private func calculateDuration() async {
        guard let audioData = recording.candidateRecording else { return }
        
        // Create a temporary file URL in the cache directory
        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let tempURL = cacheDir.appendingPathComponent(UUID().uuidString + ".m4a")
        
        do {
            // Write audio data to temporary file
            try audioData.write(to: tempURL)
            
            // Get audio asset duration without playing
            let asset = AVURLAsset(url: tempURL)
            let duration = try await asset.load(.duration)
            
            // Update duration on main thread
            await MainActor.run {
                self.duration = duration.seconds
            }
            
            // Clean up temporary file
            try? FileManager.default.removeItem(at: tempURL)
        } catch {
            print("Error calculating duration: \(error)")
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

struct RecordingDetailView: View {
    let recording: Item
    let institutions: [InstitutionModel]
    @Environment(\.managedObjectContext) private var viewContext
    @State private var isPlaying = false
    @State private var audioPlayer: AVAudioPlayer?
    @State private var showingImagePicker = false
    @State private var candidateImage: UIImage?
    @State private var isEditing = false
    @State private var candidateName = ""
    @State private var candidateLevel = ""
    @State private var examinerName1 = ""
    @State private var examinerName2 = ""
    @State private var duration: TimeInterval = 0
    
    private var institution: InstitutionModel? {
        institutions.first { $0.id == recording.institutionId }
    }
    
    var body: some View {
        Form {
            Section(header: Text("Recording Details")) {
                HStack {
                    Text("Date")
                    Spacer()
                    Text(recording.timestamp!, formatter: itemFormatter)
                }
                
                HStack {
                    Text("Duration")
                    Spacer()
                    Text(formatDuration(duration))
                }
                
                if let institution = institution {
                    Section(header: Text("Institution")) {
                        VStack(alignment: .leading) {
                            Text(institution.name)
                                .font(.headline)
                            if let street = institution.street,
                               let city = institution.city {
                                Text("\(street), \(city)")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                            }
                            if let postalCode = institution.postalCode {
                                Text(postalCode)
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                            }
                            if let country = institution.country {
                                Text(country)
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                }
                
                Section(header: Text("Candidate Information")) {
                    if isEditing {
                        TextField("Candidate Name", text: $candidateName)
                        TextField("Level", text: $candidateLevel)
                    } else {
                        if let name = recording.candidateName {
                            HStack {
                                Text("Name")
                                Spacer()
                                Text(name)
                            }
                        }
                        if let level = recording.candidateLevel {
                            HStack {
                                Text("Level")
                                Spacer()
                                Text(level)
                            }
                        }
                    }
                    
                    if let imageData = recording.candidatePicture,
                       let uiImage = UIImage(data: imageData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFit()
                            .frame(height: 200)
                    }
                    
                    Button(action: {
                        showingImagePicker = true
                    }) {
                        Text(recording.candidatePicture == nil ? "Add Photo" : "Change Photo")
                    }
                }
                
                Section(header: Text("Examiner Information")) {
                    if isEditing {
                        TextField("Examiner 1", text: $examinerName1)
                        TextField("Examiner 2", text: $examinerName2)
                    } else {
                        if let name1 = recording.examinerName1 {
                            HStack {
                                Text("Examiner 1")
                                Spacer()
                                Text(name1)
                            }
                        }
                        if let name2 = recording.examinerName2 {
                            HStack {
                                Text("Examiner 2")
                                Spacer()
                                Text(name2)
                            }
                        }
                    }
                }
                
                Section(header: Text("Audio Recording")) {
                    Button(action: togglePlayback) {
                        HStack {
                            Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                .font(.system(size: 24))
                            Text(isPlaying ? "Pause" : "Play")
                        }
                    }
                }
            }
        }
        .navigationTitle("Recording Details")
        .navigationBarItems(trailing: Button(isEditing ? "Done" : "Edit") {
            if isEditing {
                saveChanges()
            }
            isEditing.toggle()
        })
        .onAppear {
            setupInitialValues()
        }
        .task {
            await calculateDuration()
        }
    }
    
    private func setupInitialValues() {
        candidateName = recording.candidateName ?? ""
        candidateLevel = recording.candidateLevel ?? ""
        examinerName1 = recording.examinerName1 ?? ""
        examinerName2 = recording.examinerName2 ?? ""
    }
    
    private func calculateDuration() async {
        guard let audioData = recording.candidateRecording else { return }
        
        // Create a temporary file URL in the cache directory
        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let tempURL = cacheDir.appendingPathComponent(UUID().uuidString + ".m4a")
        
        do {
            // Write audio data to temporary file
            try audioData.write(to: tempURL)
            
            // Get audio asset duration without playing
            let asset = AVURLAsset(url: tempURL)
            let duration = try await asset.load(.duration)
            
            // Update duration on main thread
            await MainActor.run {
                self.duration = duration.seconds
            }
            
            // Clean up temporary file
            try? FileManager.default.removeItem(at: tempURL)
        } catch {
            print("Error calculating duration: \(error)")
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    private func togglePlayback() {
        if isPlaying {
            audioPlayer?.pause()
        } else {
            if let player = audioPlayer {
                if player.currentTime >= player.duration {
                    player.currentTime = 0
                }
                player.play()
            }
        }
        isPlaying.toggle()
    }
    
    private func saveChanges() {
        recording.candidateName = candidateName
        recording.candidateLevel = candidateLevel
        recording.examinerName1 = examinerName1
        recording.examinerName2 = examinerName2
        
        try? viewContext.save()
    }
}

struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.presentationMode) private var presentationMode
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.image = image
            }
            parent.presentationMode.wrappedValue.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.presentationMode.wrappedValue.dismiss()
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
