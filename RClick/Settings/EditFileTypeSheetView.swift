//
//  EditFileTypeSheetView.swift
//  RightSight
//
//  Created by Claude on 2026/06/28.
//

import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct EditFileTypeSheetView: View {
    let file: NewFile
    let appState: AppState

    var isAdding: Bool { file.ext.isEmpty && file.name.isEmpty }

    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var ext: String
    @State private var icon: String
    @State private var openApp: URL?
    @State private var template: URL?

    @State private var showSelectApp = false
    @State private var showSelectTemplate = false

    private let iconToSF: [String: String] = [
        "icon-file-json": "curlybraces",
        "icon-file-txt": "doc.text",
        "icon-file-md": "doc.richtext",
        "icon-file-docx": "doc.richtext.fill",
        "icon-file-pptx": "rectangle.on.rectangle.fill",
        "icon-file-xlsx": "tablecells",
    ]

    let templatesDir: URL? = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
        .appendingPathComponent("RightSight/Templates")

    init(file: NewFile, appState: AppState) {
        self.file = file
        self.appState = appState
        _name = State(initialValue: file.name)
        _ext = State(initialValue: file.ext)
        _icon = State(initialValue: file.icon)
        _openApp = State(initialValue: file.openApp)
        _template = State(initialValue: file.template)
    }

    var body: some View {
        VStack(spacing: 0) {
            SettingsSheetHeader(
                title: isAdding ? "Add File Type" : "Edit File Type",
                subtitle: "Choose a name, extension, and optional template.",
                systemImage: "doc.badge.plus"
            )

            Divider()

            Form {
                Section {
                    TextField(AppLocalization.localized("Display Name"), text: $name)
                        .textFieldStyle(.roundedBorder)
                } header: {
                    Text(appLocalized: "Name")
                }

                Section {
                    TextField(AppLocalization.localized("File Extension"), text: $ext)
                        .textFieldStyle(.roundedBorder)
                } header: {
                    Text(appLocalized: "File Extension")
                } footer: {
                    Text(appLocalized: "For example: txt, md, json")
                        .foregroundColor(.secondary)
                }

                Section {
                    HStack {
                        if let templateUrl = template {
                            Text(templateUrl.lastPathComponent)
                            Button {
                                template = nil
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                            }
                            .buttonStyle(.plain)
                        }
                        Button {
                            showSelectTemplate = true
                        } label: {
                            Text(appLocalized: template == nil ? "Choose Template File" : "Change Template")
                        }
                        .fileImporter(
                            isPresented: $showSelectTemplate,
                            allowedContentTypes: [.content],
                            allowsMultipleSelection: false
                        ) { result in
                            switch result {
                            case .success(let files):
                                if let url = files.first {
                                    template = url
                                }
                            case .failure:
                                break
                            }
                        }
                    }
                } header: {
                    Text(appLocalized: "Template")
                }

                Section {
                    TextField(AppLocalization.localized("SF Symbol Name"), text: $icon)
                        .textFieldStyle(.roundedBorder)

                    if !icon.isEmpty {
                        HStack {
                            Text(appLocalized: "Preview:")
                            if let preview = FileTypeIconProvider.shared.icon(for: ext, fallbackSymbol: icon) {
                                Image(nsImage: preview)
                                    .resizable()
                                    .frame(width: 20, height: 20)
                            } else {
                                Image(systemName: "doc")
                                    .resizable()
                                    .frame(width: 20, height: 20)
                            }
                        }
                    }
                } header: {
                    Text(appLocalized: "Icon")
                } footer: {
                    Text(appLocalized: "Enter an SF Symbol name, for example doc.text or curlybraces")
                        .foregroundColor(.secondary)
                }

                Section {
                    HStack {
                        if let appUrl = openApp {
                            Image(nsImage: IconCache.shared.icon(for: appUrl))
                                .resizable()
                                .frame(width: 20, height: 20)
                            Text(appUrl.lastPathComponent)
                        }

                        Button {
                            showSelectApp = true
                        } label: {
                            Text(appLocalized: openApp == nil ? "Choose Default App" : "Change App")
                        }
                        .fileImporter(
                            isPresented: $showSelectApp,
                            allowedContentTypes: [.application],
                            allowsMultipleSelection: false
                        ) { result in
                            switch result {
                            case .success(let files):
                                if let url = files.first {
                                    openApp = url
                                }
                            case .failure:
                                break
                            }
                        }

                        if openApp != nil {
                            Button {
                                openApp = nil
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                            }
                            .buttonStyle(.plain)
                        }
                    }
                } header: {
                    Text(appLocalized: "Default Open App")
                }
            }
            .formStyle(.grouped)

            HStack {
                Button(AppLocalization.localized("Cancel")) {
                    dismiss()
                }
                .keyboardShortcut(.escape)

                Spacer()

                Button(AppLocalization.localized(isAdding ? "Add" : "Save")) {
                    saveChanges()
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.return)
                .disabled(normalizedName.isEmpty || normalizedExtension.isEmpty)
            }
            .padding(20)
        }
        .frame(width: 480, height: 620)
    }

    private func saveChanges() {
        name = normalizedName
        ext = normalizedExtension.hasPrefix(".") ? normalizedExtension : ".\(normalizedExtension)"

        if isAdding {
            var newFile = NewFile(
                ext: ext,
                name: name,
                idx: appState.newFiles.count,
                icon: icon
            )
            if let app = openApp {
                newFile.openApp = app
            }
            if let templateUrl = template {
                newFile.template = saveTemplateFile(from: templateUrl)
            }
            appState.addNewFile(newFile)
        } else {
            if let index = appState.newFiles.firstIndex(where: { $0.id == file.id }) {
                var updatedFile = file
                updatedFile.name = name
                updatedFile.ext = ext
                updatedFile.icon = icon
                updatedFile.openApp = openApp
                if let templateUrl = template {
                    updatedFile.template = saveTemplateFile(from: templateUrl)
                } else {
                    updatedFile.template = nil
                }
                appState.newFiles[index] = updatedFile
            }
        }
        Task { @MainActor in
            appState.sync()
        }
    }

    private func saveTemplateFile(from sourceUrl: URL) -> URL? {
        guard let templateDir = templatesDir else { return nil }
        let fm = FileManager.default
        try? fm.createDirectory(at: templateDir, withIntermediateDirectories: true)
        let destUrl = templateDir.appendingPathComponent(sourceUrl.lastPathComponent)
        if destUrl.standardized.path == sourceUrl.standardized.path {
            return destUrl
        }
        if fm.fileExists(atPath: destUrl.path) {
            try? fm.removeItem(at: destUrl)
        }
        do {
            try fm.copyItem(at: sourceUrl, to: destUrl)
            return destUrl
        } catch {
            return nil
        }
    }

    private var normalizedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var normalizedExtension: String {
        ext.trimmingCharacters(in: CharacterSet(charactersIn: ". ").union(.newlines))
    }
}
