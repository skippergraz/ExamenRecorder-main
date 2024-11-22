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
    @State private var showingInstituteForm = false
    @State private var selectedInstitute: Institution?
    
    @FetchRequest(
        entity: Institution.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \Institution.name, ascending: true)],
        animation: .default)
    private var institutes: FetchedResults<Institution>
    
    var body: some View {
        NavigationView {
            List {
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
    private var institutions: FetchedResults<Institution>
    
    private var selectedInstitution: Institution? {
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
                            RecordingDetailView(recording: recording)
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
                    List {
                        ForEach(institutions) { institution in
                            Button(action: {
                                selectedInstitutionId = institution.id
                                showingInstitutionPicker = false
                            }) {
                                VStack(alignment: .leading) {
                                    Text(institution.name ?? "")
                                        .font(.headline)
                                    Text("\(institution.street ?? ""), \(institution.city ?? "")")
                                        .font(.subheadline)
                                        .foregroundColor(.gray)
                                }
                            }
                            .foregroundColor(.primary)
                        }
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
            
            let newItem = Item(context: viewContext)
            newItem.timestamp = Date()
            newItem.id = UUID()
            newItem.candidateRecording = audioData
            newItem.institutionId = selectedInstitutionId
            
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
                print("Error deleting recording: \(error.localizedDescription)")
            }
        }
    }
}

struct RecordingRowView: View {
    let recording: Item
    let institutions: FetchedResults<Institution>
    
    private var institution: Institution? {
        institutions.first { $0.id == recording.institutionId }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(recording.timestamp!, formatter: itemFormatter)
                .font(.headline)
            HStack {
                Text("Recording #\(recording.objectID.uriRepresentation().lastPathComponent)")
                if let institution = institution {
                    Text("• \(institution.name ?? "")")
                }
            }
            .font(.subheadline)
            .foregroundColor(.gray)
        }
        .padding(.vertical, 4)
    }
}

struct RecordingDetailView: View {
    let recording: Item
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
    
    @FetchRequest(
        entity: Institution.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \Institution.name, ascending: true)],
        animation: .default)
    private var institutions: FetchedResults<Institution>
    
    private var institution: Institution? {
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
                
                if let institution = institution {
                    Section(header: Text("Institution")) {
                        VStack(alignment: .leading) {
                            Text(institution.name ?? "")
                                .font(.headline)
                            Text(institution.street ?? "")
                            Text("\(institution.city ?? ""), \(institution.postalCode ?? "")")
                            Text(institution.country ?? "")
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
            setupAudioPlayer()
        }
        .onDisappear {
            audioPlayer?.stop()
        }
        .sheet(isPresented: $showingImagePicker) {
            ImagePicker(image: $candidateImage)
                .onChange(of: candidateImage) { newImage in
                    if let image = newImage,
                       let imageData = image.jpegData(compressionQuality: 0.8) {
                        recording.candidatePicture = imageData
                        try? viewContext.save()
                    }
                }
        }
    }
    
    private func setupInitialValues() {
        candidateName = recording.candidateName ?? ""
        candidateLevel = recording.candidateLevel ?? ""
        examinerName1 = recording.examinerName1 ?? ""
        examinerName2 = recording.examinerName2 ?? ""
    }
    
    private func setupAudioPlayer() {
        if let audioData = recording.candidateRecording {
            do {
                audioPlayer = try AVAudioPlayer(data: audioData)
            } catch {
                print("Error setting up audio player: \(error.localizedDescription)")
            }
        }
    }
    
    private func togglePlayback() {
        if isPlaying {
            audioPlayer?.pause()
        } else {
            audioPlayer?.play()
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
