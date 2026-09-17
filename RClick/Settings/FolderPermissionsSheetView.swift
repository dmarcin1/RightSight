//
//  FolderPermissionsSheetView.swift
//  RightSight
//
//  Created by Claude on 2026/07/12.
//

import SwiftUI

struct FolderPermissionsSheetView: View {
    @ObservedObject var bookmarkManager: BookmarkManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            SettingsSheetHeader(
                title: "Folder Permissions",
                subtitle: "Choose where RightSight may manage files.",
                systemImage: "folder.badge.person.crop"
            )

            Divider()

            if bookmarkManager.authorizedDirectories.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "folder.badge.questionmark")
                        .font(.system(size: 34, weight: .light))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(Color.accentColor)
                    Text(AppLocalization.localized("No folders authorized"))
                        .font(.headline)
                    Text(AppLocalization.localized("Authorize folders to let RightSight create, delete, and manage files in them."))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding(.vertical, 40)
            } else {
                List {
                    ForEach(bookmarkManager.authorizedDirectories, id: \.path) { url in
                        HStack {
                            Image(systemName: "folder.fill")
                                .foregroundColor(.accentColor)
                            Text(url.path)
                                .font(.body)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Spacer()
                            Button {
                                bookmarkManager.removeDirectory(url)
                            } label: {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                            }
                            .buttonStyle(.borderless)
                            .help(AppLocalization.localized("Remove folder permission"))
                        }
                    }
                }
                .frame(minHeight: 200)
            }

            Divider()

            HStack {
                Button {
                    Task { @MainActor in
                        _ = await bookmarkManager.addDirectory()
                    }
                } label: {
                    Label(AppLocalization.localized("Add a Folder…"), systemImage: "plus")
                }

                Spacer()

                Button(AppLocalization.localized("Done")) {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.escape)
            }
            .padding()
        }
        .frame(width: 480, height: 360)
    }
}
