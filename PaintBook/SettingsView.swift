//
//  SettingsView.swift
//  PaintBook
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers
#if os(iOS)
import AVFoundation
#endif

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Paint.createdAt) private var paints: [Paint]
    @Query private var rooms: [Room]

    @AppStorage(SettingsKey.defaultSheen) private var defaultSheen: Sheen = .eggshell
    @AppStorage(SettingsKey.defaultBase) private var defaultBase: PaintBase = .water
    @AppStorage(SettingsKey.paintSort) private var paintSort: PaintSort = .newest
    @AppStorage(SettingsKey.paperSize) private var paperSize: PaperSize = .letter

    // Export
    @State private var exportFile: ExportFile?
    @State private var exportType: UTType = .json
    @State private var exportName = ""
    @State private var isExporting = false

    // Restore
    @State private var isImporting = false
    @State private var pendingRestore: Data?
    @State private var pendingSummary = ""
    @State private var showingRestoreChoice = false

    @State private var message: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Sheen", selection: $defaultSheen) {
                        ForEach(Sheen.allCases) { Text($0.rawValue).tag($0) }
                    }
                    Picker("Base", selection: $defaultBase) {
                        ForEach(PaintBase.allCases) { Text($0.rawValue).tag($0) }
                    }
                } header: {
                    Text("New Paints")
                } footer: {
                    Text("Pre-selected when you add a paint.")
                }

                Section("Paint List") {
                    Picker("Sort By", selection: $paintSort) {
                        ForEach(PaintSort.allCases) { Text($0.rawValue).tag($0) }
                    }
                }

                Section("PDF Export") {
                    Picker("Paper Size", selection: $paperSize) {
                        ForEach(PaperSize.allCases) { Text($0.rawValue).tag($0) }
                    }
                }

                dataSection
                aboutSection
            }
            .formStyle(.grouped)
            .navigationTitle("Settings")
            .fileExporter(isPresented: $isExporting,
                          document: exportFile,
                          contentType: exportType,
                          defaultFilename: exportName) { result in
                if case .failure(let error) = result {
                    message = "Couldn't save the file: \(error.localizedDescription)"
                }
                exportFile = nil
            }
            .fileImporter(isPresented: $isImporting, allowedContentTypes: [.json]) { result in
                handleImport(result)
            }
            .confirmationDialog("Restore Backup", isPresented: $showingRestoreChoice, titleVisibility: .visible) {
                Button("Add to My Library") { restore(replacing: false) }
                Button("Replace Everything", role: .destructive) { restore(replacing: true) }
                Button("Cancel", role: .cancel) { pendingRestore = nil }
            } message: {
                Text("\(pendingSummary)\n\n“Replace Everything” deletes your current paints and rooms first.")
            }
            .alert("PaintBook", isPresented: Binding(
                get: { message != nil },
                set: { if !$0 { message = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(message ?? "")
            }
        }
    }

    // MARK: Sections

    private var dataSection: some View {
        Section {
            Button("Back Up Library…", systemImage: "externaldrive.badge.plus", action: backUp)
            Button("Restore from Backup…", systemImage: "arrow.counterclockwise") { isImporting = true }
            Button("Export Spreadsheet (CSV)…", systemImage: "tablecells", action: exportCSV)
                .disabled(paints.isEmpty)
        } header: {
            Text("Your Data")
        } footer: {
            Text("A backup is a single file with every paint, room and photo. Save it to Files or iCloud Drive so you can restore it on a new device.")
        }
    }

    private var aboutSection: some View {
        Section("About") {
            LabeledContent("Version", value: appVersion)
            LabeledContent("Paints", value: paints.count.formatted())
            LabeledContent("Rooms", value: rooms.count.formatted())
#if os(iOS)
            LabeledContent("Camera Access", value: cameraStatus)
            if let url = URL(string: UIApplication.openSettingsURLString) {
                Link(destination: url) {
                    Label("Open iPhone Settings", systemImage: "gear")
                }
            }
#endif
        }
    }

    // MARK: Actions

    private func backUp() {
        do {
            exportFile = ExportFile(data: try LibraryBackup.makeBackup(from: modelContext))
            exportType = .json
            exportName = "PaintBook Backup \(Date.now.formatted(.iso8601.year().month().day()))"
            isExporting = true
        } catch {
            message = "Couldn't create the backup: \(error.localizedDescription)"
        }
    }

    private func exportCSV() {
        exportFile = ExportFile(data: Data(LibraryBackup.makeCSV(from: paints).utf8))
        exportType = .commaSeparatedText
        exportName = "PaintBook Paints"
        isExporting = true
    }

    private func handleImport(_ result: Result<URL, Error>) {
        do {
            let url = try result.get()
            let accessing = url.startAccessingSecurityScopedResource()
            defer { if accessing { url.stopAccessingSecurityScopedResource() } }

            let data = try Data(contentsOf: url)
            let counts = try LibraryBackup.inspect(data)
            pendingRestore = data
            pendingSummary = "This backup has \(counts.paints) paint\(counts.paints == 1 ? "" : "s") and \(counts.rooms) room\(counts.rooms == 1 ? "" : "s")."
            showingRestoreChoice = true
        } catch {
            message = error.localizedDescription
        }
    }

    private func restore(replacing: Bool) {
        guard let data = pendingRestore else { return }
        pendingRestore = nil
        do {
            let counts = try LibraryBackup.restore(data, into: modelContext, replacing: replacing)
            message = "Restored \(counts.paints) paint\(counts.paints == 1 ? "" : "s") and added \(counts.rooms) room\(counts.rooms == 1 ? "" : "s")."
        } catch {
            message = "Couldn't restore: \(error.localizedDescription)"
        }
    }

    // MARK: About

    private var appVersion: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "\(version) (\(build))"
    }

#if os(iOS)
    private var cameraStatus: String {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: "Allowed"
        case .denied: "Denied"
        case .restricted: "Restricted"
        case .notDetermined: "Not Asked Yet"
        @unknown default: "Unknown"
        }
    }
#endif
}

#Preview {
    SettingsView()
        .modelContainer(for: Paint.self, inMemory: true)
}
