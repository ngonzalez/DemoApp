/*
    Copyright (c) 2026 Nicolas GONZALEZ

    MIT License

    Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated
    documentation files (the “Software”), to deal in the Software without restriction, including without limitation
    the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software,
    and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

    The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

    THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
    OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLteDERS BE
    LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR
    IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/

import SwiftUI
import AVKit
import Gzip
import OSLog

// Upload's part of the window
extension ContentView {
    // Upload, middle column: the synced folders and the uploads' folders
    @ViewBuilder
    var uploadPanel: some View {
        if !self.identified {
            List {
                Section {
                    Spacer()

                    Text("You need to be identified. Please sign-in.")
                        .padding(10)

                    Spacer()
                }
            }
            .navigationSplitViewColumnWidth(min: .infinity, ideal: .infinity, max: .infinity)
        } else {
            /*
                Main Upload Panel
            */
            VStack(alignment: .leading, spacing: 4) {
            HStack {
                /* Browse Button */
                VStack {
                    Button(action: syncFolders) {
                        let folderNames = folders.map { String($0.path().split(separator: "/").last!) }
                        Image(systemName: "arrow.down.square")
                        Text("Import \(folderNames.joined(separator: ", "))")
                        ProgressView(value: progress)
                    }
                    .disabled(isSyncing)
                }

                /* Clear Button */
                VStack {
                    Button(action: clearFolders) {
                        Text("Clear")
                            .foregroundStyle(.gray.gradient)
                    }.buttonStyle(PlainButtonStyle())
                    .disabled(isSyncing)
                }

                /* Import Button */
                VStack {
                    Button(action: {
                        isImporting = true
                    }) {
                        if #available(macOS 15.0, *) {
                            Image(systemName: "square.grid.3x1.folder.badge.plus")
                                .font(.system(size: 11))
                                .buttonStyle(.plain)
                                .symbolEffect(.bounce, options: .repeat(1))
                        } else {
                            Image(systemName: "square.grid.3x1.folder.badge.plus")
                                .font(.system(size: 11))
                                .buttonStyle(.plain)
                        }
                    }
                    .fileImporter(
                        isPresented: $isImporting,
                        allowedContentTypes: [.folder],
                        allowsMultipleSelection: true
                    ) { result in
                        if case .success = result {
                            do {
                                let items = try result.get()
                                for url in items {
                                    if url.startAccessingSecurityScopedResource() {
                                        folders.append(url)
                                    }
                                }
                            } catch let error {
                                logger.error("[fileImporter] Error: \(error)")
                            }
                        }
                    }
                    .font(.system(size: 11))
                    .padding(5)
                    .opacity(0.9)
                    .glassEffect(.regular.tint(.clear).interactive(), in: .capsule)
                    .buttonStyle(.glassProminent)
                }
            }
            .padding(5)

            planSummary
            }
            .task(id: identified) {
                planUsage = identified ? await PlanUsage.fetch() : nil
            }
            .navigationTitle("Appshare \(self.signedInUser?.emailAddress! ?? "")")
            .toolbar {
                Button(action: refreshUploads) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 20))
                }
            }

            Section {
                Table(of: Folder.self,
                      selection: $folderSelection,
                      sortOrder: $folderSortOrder) {

                    TableColumn("Name", value: \.name) { folder in
                        Label {
                            Text("\(folder.name)")
                        } icon: {
                            Image(systemName: "folder")
                                .font(.system(size: 11))
                        }
                        .foregroundStyle(.primary)
                        .labelStyle(.titleAndIcon)
                        .font(.system(size: 11))
                    }
                    TableColumn("State", value: \.state) { folder in
                        Label {
                            Text("\(folder.state)")
                                .font(.system(size: 11))
                                .foregroundStyle(folder.state == "published" ? .white : .gray)
                        } icon: {
                            Rectangle()
                                .fill(folder.state == "published" ? .yellow : .gray)
                                .frame(width: 8, height: 8)
                        }
                    }
                } rows: {
                    ForEach(loadedFolders) { folder in
                        TableRow(folder)
                    }
                }
                .onChange(of: folderSortOrder) { _, folderSortOrder in
                    withAnimation {
                        loadedFolders.sort(using: folderSortOrder)
                    }
                }
                .onChange(of: folderSelection) {
                    DispatchQueue.main.async {
                        clearSelectedFiles()
                        self.selectedFolders = []
                        for selectedId in folderSelection {
                            loadedFolders.forEach { folder in
                                if folder.id == selectedId {
                                    self.selectedFolders.insert(folder.id)
                                }
                            }
                        }
                        if (self.selectedFolders.count == 0) {
                            self.searchText = ""
                        }
                        getSelectedUploads()
                    }
                }
                .tableStyle(.inset(alternatesRowBackgrounds: false))
                    .frame(height: 250)
            } header: {
                Text("Folders")
                    .searchable(text: $searchText, prompt: "Search Folders")
            }.onChange(of: searchText) {
                DispatchQueue.main.async {
                    fetchSearchResults(for: searchText)
                }
            }
        }
    }

    // Upload, middle column, under the panel: the selected folders' files
    @ViewBuilder
    var uploadFilesPanel: some View {
        if self.identified {
            if uploadImageFiles.isEmpty && uploadAudioFiles.isEmpty && uploadVideoFiles.isEmpty && uploadPdfFiles.isEmpty && uploadTextFiles.isEmpty {
                // nothing to list: no tab
                Text(self.selectedFolders.isEmpty ? "No folder selected" : "No files")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(10)
            } else {
                // only the tabs with files
                TabView {
                    if !uploadImageFiles.isEmpty {
                        VStack {
                            Section {
                                /* ImageFiles */
                                Table(of: ImageFile.self,
                                      selection: $imageFileSelection,
                                      sortOrder: $imageFileSortOrder) {

                                    TableColumn("fileName") { imageFile in
                                        Label(imageFile.fileName, systemImage: "doc")
                                            .labelStyle(.titleAndIcon)
                                            .font(.system(size: 11))
                                    }
                                    TableColumn("mimeType") { imageFile in
                                        let mimeType = imageFile.mimeType
                                        let mimeTypeUnwrapped = mimeType!
                                        Text(mimeTypeUnwrapped)
                                            .labelStyle(.titleAndIcon)
                                            .font(.system(size: 11))
                                    }
                                } rows: {
                                    ForEach(uploadImageFiles) { imageFile in
                                        TableRow(imageFile)
                                    }
                                }
                            } header: {
                                HStack {
                                    VStack {
                                        Text("Image Files")
                                    }
                                    VStack {
                                        if (selectedImageFiles.count > 0) {
                                            Button(action: deleteSelectedImages) {
                                                Image(systemName: "minus.circle")
                                                    .font(.system(size: 11))
                                                (self.selectedImageFiles.count > 1 ? Text("Delete selected Image Files") : Text("Delete selected Image File"))
                                                    .font(.system(size: 11))
                                            }
                                            .buttonStyle(.borderedProminent)
                                            .tint(.black)
                                        }
                                    }
                                }
                            }
                        }
                        .tableStyle(.inset(alternatesRowBackgrounds: false))
                        .onChange(of: imageFileSelection) {
                            self.selectedImageFiles = []
                            self.selectedFolders = Set()
                            for selectedId in imageFileSelection {
                                uploadImageFiles.forEach { imageFile in
                                    if imageFile.id == selectedId {
                                        self.selectedImageFiles.append(imageFile)
                                        if (!self.selectedFolders.contains(imageFile.folder.id)) {
                                            self.selectedFolders.insert(imageFile.folder.id)
                                        }
                                        var i = 0
                                        self.loadedFolders.forEach { folder in
                                            if (folder.id == imageFile.folder.id) {
                                                self.loadedFolders.remove(at: i)
                                            }
                                            i += 1
                                        }
                                        self.loadedFolders.append(imageFile.folder)
                                    }
                                }
                            }
                        }
                        .onChange(of: imageFileSortOrder) { _, imageFileSortOrder in
                            withAnimation {
                                uploadImageFiles.sort(using: imageFileSortOrder)
                            }
                        }
                        .tabItem {
                            Text("Image Files (\(uploadImageFiles.count))")
                        }
                    }

                    if !uploadAudioFiles.isEmpty {
                        VStack {
                            Section {
                                /* AudioFiles */
                                Table(of: AudioFile.self,
                                      selection: $audioFileSelection,
                                      sortOrder: $audioFileSortOrder) {

                                    TableColumn("fileName") { audioFile in
                                        Label(audioFile.fileName, systemImage: "doc")
                                            .labelStyle(.titleAndIcon)
                                            .font(.system(size: 11))
                                    }
                                    TableColumn("mimeType") { audioFile in
                                        let mimeType = audioFile.mimeType
                                        let mimeTypeUnwrapped = mimeType!
                                        Text(mimeTypeUnwrapped)
                                            .labelStyle(.titleAndIcon)
                                            .font(.system(size: 11))
                                    }
                                } rows: {
                                    ForEach(uploadAudioFiles) { audioFile in
                                        TableRow(audioFile)
                                    }
                                }
                            } header: {
                                HStack {
                                    VStack {
                                        Text("Audio Files")
                                    }
                                    VStack {
                                        if (selectedAudioFiles.count > 0) {
                                            Button(action: deleteSelectedAudioFiles) {
                                                Image(systemName: "minus.circle")
                                                    .font(.system(size: 11))
                                                (self.selectedAudioFiles.count > 1 ? Text("Delete selected Audio Files") : Text("Delete selected Audio File"))
                                                    .font(.system(size: 11))
                                            }
                                            .buttonStyle(.borderedProminent)
                                            .tint(.black)
                                        }
                                    }
                                }
                            }
                        }
                        .tableStyle(.inset(alternatesRowBackgrounds: false))
                        .onChange(of: audioFileSelection) { _, audioFileSelection in
                            self.selectedAudioFiles = []
                            self.selectedFolders = Set()
                            for selectedId in audioFileSelection {
                                uploadAudioFiles.forEach { audioFile in
                                    if audioFile.id == selectedId {
                                        self.selectedAudioFiles.append(audioFile)
                                        self.player = AVPlayer()
                                        displayAudio(audioFile: audioFile)
                                        DispatchQueue.main.async {
                                            getAudioStream(audioFile: audioFile)
                                        }
                                    }
                                }
                            }
                        }
                        .onChange(of: audioFileSelection) {
                            self.selectedAudioFiles = []
                            for selectedId in audioFileSelection {
                                uploadAudioFiles.forEach { audioFile in
                                    if audioFile.id == selectedId {
                                        self.selectedAudioFiles.append(audioFile)
                                        if (!self.selectedFolders.contains(audioFile.folder.id)) {
                                            self.selectedFolders.insert(audioFile.folder.id)
                                        }
                                        var i = 0
                                        self.loadedFolders.forEach { folder in
                                            if (folder.id == audioFile.folder.id) {
                                                self.loadedFolders.remove(at: i)
                                            }
                                            i += 1
                                        }
                                        self.loadedFolders.append(audioFile.folder)

                                        displayAudio(audioFile: audioFile)
                                    }
                                }
                            }
                        }
                        .onChange(of: audioFileSortOrder) { _, audioFileSortOrder in
                            uploadAudioFiles.sort(using: audioFileSortOrder)
                        }
                        .tabItem {
                            Text("Audio Files (\(uploadAudioFiles.count))")
                        }
                    }

                    if !uploadVideoFiles.isEmpty {
                        VStack {
                            Section {
                                /* VideoFiles */
                                Table(of: VideoFile.self,
                                      selection: $videoFileSelection,
                                      sortOrder: $videoFileSortOrder) {

                                    TableColumn("fileName") { videoFile in
                                        Label(videoFile.fileName, systemImage: "doc")
                                            .labelStyle(.titleAndIcon)
                                            .font(.system(size: 11))
                                    }
                                    TableColumn("mimeType") { videoFile in
                                        let mimeType = videoFile.mimeType
                                        let mimeTypeUnwrapped = mimeType!
                                        Text(mimeTypeUnwrapped)
                                            .labelStyle(.titleAndIcon)
                                            .font(.system(size: 11))
                                    }
                                } rows: {
                                    ForEach(uploadVideoFiles) { videoFile in
                                        TableRow(videoFile)
                                    }
                                }
                            } header: {
                                HStack {
                                    VStack {
                                        Text("Video Files")
                                    }
                                    VStack {
                                        if (selectedVideoFiles.count > 0) {
                                            Button(action: deleteSelectedVideoFiles) {
                                                Image(systemName: "minus.circle")
                                                    .font(.system(size: 11))
                                                (self.selectedVideoFiles.count > 1 ? Text("Delete selected Video Files") : Text("Delete selected Video File"))
                                                    .font(.system(size: 11))
                                            }
                                            .buttonStyle(.borderedProminent)
                                            .tint(.black)
                                        }
                                    }
                                }
                            }
                        }
                        .tableStyle(.inset(alternatesRowBackgrounds: false))
                        .onChange(of: videoFileSelection) {
                            self.selectedVideoFiles = []
                            self.selectedFolders = Set()
                            for selectedId in videoFileSelection {
                                uploadVideoFiles.forEach { videoFile in
                                    if videoFile.id == selectedId {
                                        self.selectedVideoFiles.append(videoFile)
                                        if (!self.selectedFolders.contains(videoFile.folder.id)) {
                                            self.selectedFolders.insert(videoFile.folder.id)
                                        }
                                        var i = 0
                                        self.loadedFolders.forEach { folder in
                                            if (folder.id == videoFile.folder.id) {
                                                self.loadedFolders.remove(at: i)
                                            }
                                            i += 1
                                        }
                                        self.loadedFolders.append(videoFile.folder)

                                        displayVideo(videoFile: videoFile)
                                    }
                                }
                            }
                        }
                        .onChange(of: videoFileSortOrder) { _, videoFileSortOrder in
                            uploadVideoFiles.sort(using: videoFileSortOrder)
                        }
                        .tabItem {
                            Text("Video Files (\(uploadVideoFiles.count))").colorMultiply(.cyan)
                        }
                    }

                    if !uploadPdfFiles.isEmpty {
                        VStack {
                            Section {
                                /* PdfFiles */
                                Table(of: PdfFile.self,
                                      selection: $pdfFileSelection,
                                      sortOrder: $pdfFileSortOrder) {

                                    TableColumn("fileName") { pdfFile in
                                        Label(pdfFile.fileName, systemImage: "doc")
                                            .labelStyle(.titleAndIcon)
                                            .font(.system(size: 11))
                                    }
                                    TableColumn("mimeType") { pdfFile in
                                        let mimeType = pdfFile.mimeType
                                        let mimeTypeUnwrapped = mimeType!
                                        Text(mimeTypeUnwrapped)
                                            .labelStyle(.titleAndIcon)
                                            .font(.system(size: 11))
                                    }
                                } rows: {
                                    ForEach(uploadPdfFiles) { pdfFile in
                                        TableRow(pdfFile)
                                    }
                                }
                            } header: {
                                HStack {
                                    VStack {
                                        Text("Pdf Files")
                                    }
                                    VStack {
                                        if (selectedPdfFiles.count > 0) {
                                            Button(action: deleteSelectedPdfs) {
                                                Image(systemName: "minus.circle")
                                                    .font(.system(size: 11))
                                                (self.selectedPdfFiles.count > 1 ? Text("Delete selected Pdf Files") : Text("Delete selected Pdf File"))
                                                    .font(.system(size: 11))
                                            }
                                            .buttonStyle(.borderedProminent)
                                            .tint(.black)
                                        }
                                    }
                                }
                            }
                        }
                        .tableStyle(.inset(alternatesRowBackgrounds: false))
                        .onChange(of: pdfFileSelection) {
                            self.selectedPdfFiles = []
                            self.selectedFolders = Set()
                            for selectedId in pdfFileSelection {
                                uploadPdfFiles.forEach { pdfFile in
                                    if pdfFile.id == selectedId {
                                        self.selectedPdfFiles.append(pdfFile)
                                        if (!self.selectedFolders.contains(pdfFile.folder.id)) {
                                            self.selectedFolders.insert(pdfFile.folder.id)
                                        }
                                        var i = 0
                                        self.loadedFolders.forEach { folder in
                                            if (folder.id == pdfFile.folder.id) {
                                                self.loadedFolders.remove(at: i)
                                            }
                                            i += 1
                                        }
                                        self.loadedFolders.append(pdfFile.folder)
                                    }
                                }
                            }
                        }
                        .onChange(of: pdfFileSortOrder) { _, pdfFileSortOrder in
                            uploadPdfFiles.sort(using: pdfFileSortOrder)
                        }
                        .tabItem {
                            Text("Pdf Files (\(uploadPdfFiles.count))")
                        }
                    }

                    if !uploadTextFiles.isEmpty {
                        VStack {
                            Section {
                                /* TextFiles */
                                Table(of: TextFile.self,
                                      selection: $textFileSelection,
                                      sortOrder: $textFileSortOrder) {

                                    TableColumn("fileName") { textFile in
                                        Label(textFile.fileName, systemImage: "doc")
                                            .labelStyle(.titleAndIcon)
                                            .font(.system(size: 11))
                                    }
                                    TableColumn("mimeType") { textFile in
                                        let mimeType = textFile.mimeType
                                        let mimeTypeUnwrapped = mimeType!
                                        Text(mimeTypeUnwrapped)
                                            .labelStyle(.titleAndIcon)
                                            .font(.system(size: 11))
                                    }
                                } rows: {
                                    ForEach(uploadTextFiles) { textFile in
                                        TableRow(textFile)
                                    }
                                }
                            } header: {
                                HStack {
                                    VStack {
                                        Text("Text Files")
                                    }
                                    VStack {
                                        if (selectedTextFiles.count > 0) {
                                            Button(action: deleteSelectedTextFiles) {
                                                Image(systemName: "minus.circle")
                                                    .font(.system(size: 11))
                                                (self.selectedTextFiles.count > 1 ? Text("Delete selected Text Files") : Text("Delete selected Text File"))
                                                    .font(.system(size: 11))
                                            }
                                            .buttonStyle(.borderedProminent)
                                            .tint(.black)
                                        }
                                    }
                                }
                            }
                        }
                        .tableStyle(.inset(alternatesRowBackgrounds: false))
                        .onChange(of: textFileSelection) {
                            self.selectedTextFiles = []
                            self.selectedFolders = Set()
                            for selectedId in textFileSelection {
                                uploadTextFiles.forEach { textFile in
                                    if textFile.id == selectedId {
                                        self.selectedTextFiles.append(textFile)
                                        if (!self.selectedFolders.contains(textFile.folder.id)) {
                                            self.selectedFolders.insert(textFile.folder.id)
                                        }
                                        var i = 0
                                        self.loadedFolders.forEach { folder in
                                            if (folder.id == textFile.folder.id) {
                                                self.loadedFolders.remove(at: i)
                                            }
                                            i += 1
                                        }
                                        self.loadedFolders.append(textFile.folder)
                                    }
                                }
                            }
                        }
                        .onChange(of: textFileSortOrder) { _, textFileSortOrder in
                            uploadTextFiles.sort(using: textFileSortOrder)
                        }
                        .tabItem {
                            Text("Text Files (\(uploadTextFiles.count))")
                        }
                    }
                }
                .padding(10)
            }
        }
    }

    // Detail column: the selected folders' actions and files (Upload)
    @ViewBuilder
    var detailColumn: some View {
        if self.identified {
            if (selectedSideBarItem == .upload) {
                HStack {
                    VStack(alignment: .leading, spacing: 0) {
                        if (self.selectedFolders.count > 0) {
                            HStack {
                                /*
                                 Folder Actions: Publish, Unpublish, Archive, Unarchive, Delete
                                 */
                                Picker("Folder actions", selection: $selectedFolderAction) {
                                    ForEach(FolderAction.allCases) { action in
                                        Text(action.title)
                                            .font(.system(size: 11))
                                    }
                                }
                                .font(.system(size: 11))
                                .padding(5)
                                .opacity(0.9)
                                .pickerStyle(MenuPickerStyle())
                                .tint(.blue)

                                Button(action: updateSelectedFolders) {
                                    Image(systemName: "chevron.right")
                                    (self.selectedFolders.count > 1 ? Text("Update Folders") : Text("Update Folder"))
                                }
                                .font(.system(size: 11))
                                .padding(5)
                                .opacity(0.9)
                                .glassEffect(.regular.tint(.clear).interactive(), in: .capsule)
                                .buttonStyle(.glassProminent)
                            }
                            .frame(height: 55)
                            .padding(5)
                        }

                        List {
                            /*
                             Selected Folders
                             */
                            Section {
                                VStack(alignment: .leading, spacing: 5){
                                    Text("\(self.selectedFolders.count) Folders selected")
                                        .font(.system(size: 11))
                                        .foregroundStyle(.gray)
                                        .truncationMode(.middle)
                                        .padding(5)

                                    ForEach(self.loadedFolders) { folder in
                                        if (self.selectedFolders.map { $0 }.contains(folder.id)) {
                                            Label {
                                                Link("\(folder.name)", destination: URL(string: folder.webUrl)!)
                                                    .font(.system(size: 11))
                                                    .truncationMode(.middle)
                                                    .tint(.blue)
                                            } icon: {
                                                Rectangle()
                                                    .fill(folder.state == "published" ? .yellow : .gray)
                                                    .frame(width: 8, height: 8)
                                            }
                                        }
                                    }
                                }
                            }

                            /*
                             ImageFile
                             */
                            ForEach(self.selectedImageFiles) { imageFile in
                                Section {
                                    VStack(alignment: .leading, spacing: 5) {
                                        Label {
                                            Link("\(imageFile.folder.name)", destination: URL(string: imageFile.folder.webUrl)!)
                                                .font(.system(size: 11))
                                                .truncationMode(.middle)
                                                .tint(.blue)

                                            Text(" / ")
                                                .foregroundStyle(.gray)

                                            Link("\(imageFile.fileName)", destination: URL(string: imageFile.webUrl)!)
                                                .font(.system(size: 11))
                                                .truncationMode(.middle)
                                                .tint(.blue)
                                        } icon: {
                                            Image(systemName: "doc.circle.fill")
                                                .font(.system(size: 11))
                                        }

                                        AsyncImage(url: URL(string: imageFile.fileUrl)) { result in
                                            result.image?
                                                .resizable()
                                                .scaledToFill()
                                        }
                                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                                        Label {
                                            Text("Mime/Type \(imageFile.mimeType ?? "")")
                                                .font(.system(size: 11))
                                                .foregroundStyle(.gray)
                                        } icon: {
                                            Rectangle()
                                                .fill(.gray)
                                                .frame(width: 8, height: 8)
                                        }

                                        Label {
                                            Text("Format \(imageFile.formatInfo ?? "")")
                                                .font(.system(size: 11))
                                                .foregroundStyle(.gray)
                                        } icon: {
                                            Rectangle()
                                                .fill(.gray)
                                                .frame(width: 8, height: 8)
                                        }

                                        Label {
                                            Text("File Size \(imageFile.fileSize ?? "")")
                                                .font(.system(size: 11))
                                                .foregroundStyle(.gray)
                                        } icon: {
                                            Rectangle()
                                                .fill(.gray)
                                                .frame(width: 8, height: 8)
                                        }

                                        Label {
                                            Text("Dimensions \(imageFile.dimensions ?? "")")
                                                .font(.system(size: 11))
                                                .foregroundStyle(.gray)
                                        } icon: {
                                            Rectangle()
                                                .fill(.gray)
                                                .frame(width: 8, height: 8)
                                        }

                                        Label {
                                            Text("Megapixels \(imageFile.megapixels ?? 0)")
                                                .font(.system(size: 11))
                                                .foregroundStyle(.gray)
                                        } icon: {
                                            Rectangle()
                                                .fill(.gray)
                                                .frame(width: 8, height: 8)
                                        }

                                        Label {
                                            Text("Width \(imageFile.width ?? 0)")
                                                .font(.system(size: 11))
                                                .foregroundStyle(.gray)
                                        } icon: {
                                            Rectangle()
                                                .fill(.gray)
                                                .frame(width: 8, height: 8)
                                        }

                                        Label {
                                            Text("Height \(imageFile.height ?? 0)")
                                                .font(.system(size: 11))
                                                .foregroundStyle(.gray)
                                        } icon: {
                                            Rectangle()
                                                .fill(.gray)
                                                .frame(width: 8, height: 8)
                                        }

                                        Label {
                                            Link("File URL", destination: URL(string: imageFile.fileUrl)!)
                                                .font(.system(size: 11))
                                                .tint(.blue)
                                        } icon: {
                                            Rectangle()
                                                .fill(.gray)
                                                .frame(width: 8, height: 8)
                                        }

                                        Spacer()
                                    }
                                    .frame(minWidth: 0, maxWidth: .infinity, alignment: .topLeading)
                                    .padding(5)

                                    Spacer()
                                }
                            }
                            .listRowSeparator(.hidden)
                            .listRowBackground(Ellipse()
                                .background(Color.black)
                                .foregroundColor(Color.clear)
                                .opacity(0.25)
                            )

                            /*
                             AudioFile
                             */
                            ForEach(self.selectedAudioFiles) { audioFile in
                                Section {
                                    VStack(alignment: .leading, spacing: 5) {
                                        Label {
                                            Link("\(audioFile.folder.name)", destination: URL(string: audioFile.folder.webUrl)!)
                                                .font(.system(size: 11))
                                                .truncationMode(.middle)
                                                .tint(.blue)

                                            Text(" / ")
                                                .foregroundStyle(.gray)

                                            Link("\(audioFile.fileName)", destination: URL(string: audioFile.webUrl)!)
                                                .font(.system(size: 11))
                                                .truncationMode(.middle)
                                                .tint(.blue)
                                        } icon: {
                                            Image(systemName: "doc.circle.fill")
                                                .font(.system(size: 11))
                                        }

                                        if (audioFile.aasmState == "created") {
                                            Text("Processing…")
                                                .font(.system(size: 11))
                                                .padding(10)
                                        } else if (audioFile.aasmState == "processed") {
                                            VideoPlayer(player: player)
                                                .frame(minWidth: 400, maxWidth: .infinity,
                                                       minHeight: 150, maxHeight: .infinity)
                                                .padding(10)
                                        }

                                        Label {
                                            Text("Format \(audioFile.formatInfo ?? "")")
                                                .font(.system(size: 11))
                                                .foregroundStyle(.gray)
                                        } icon: {
                                            Rectangle()
                                                .fill(.gray)
                                                .frame(width: 8, height: 8)
                                        }

                                        Label {
                                            Text("Mime/Type \(audioFile.mimeType ?? "")")
                                                .font(.system(size: 11))
                                                .foregroundStyle(.gray)
                                        } icon: {
                                            Rectangle()
                                                .fill(.gray)
                                                .frame(width: 8, height: 8)
                                        }

                                        Label {
                                            Text("File Size \(audioFile.fileSize ?? 0)")
                                                .font(.system(size: 11))
                                                .foregroundStyle(.gray)
                                        } icon: {
                                            Rectangle()
                                                .fill(.gray)
                                                .frame(width: 8, height: 8)
                                        }

                                        Label {
                                            Text("Title \(audioFile.title ?? "")")
                                                .font(.system(size: 11))
                                                .foregroundStyle(.gray)
                                        } icon: {
                                            Rectangle()
                                                .fill(.gray)
                                                .frame(width: 8, height: 8)
                                        }

                                        Label {
                                            Text("Bitrate \(audioFile.bitrate ?? 0)")
                                                .font(.system(size: 11))
                                                .foregroundStyle(.gray)
                                        } icon: {
                                            Rectangle()
                                                .fill(.gray)
                                                .frame(width: 8, height: 8)
                                        }

                                        Label {
                                            Text("Channels \(audioFile.channels ?? 0)")
                                                .font(.system(size: 11))
                                                .foregroundStyle(.gray)
                                        } icon: {
                                            Rectangle()
                                                .fill(.gray)
                                                .frame(width: 8, height: 8)
                                        }

                                        Label {
                                            Text("Length (ms) \(audioFile.length ?? 0)")
                                                .font(.system(size: 11))
                                                .foregroundStyle(.gray)
                                        } icon: {
                                            Rectangle()
                                                .fill(.gray)
                                                .frame(width: 8, height: 8)
                                        }

                                        Label {
                                            Text("Sample Rate \(audioFile.sampleRate ?? 0)")
                                                .font(.system(size: 11))
                                                .foregroundStyle(.gray)
                                        } icon: {
                                            Rectangle()
                                                .fill(.gray)
                                                .frame(width: 8, height: 8)
                                        }

                                        Label {
                                            Link("File URL", destination: URL(string: audioFile.fileUrl)!)
                                                .font(.system(size: 11))
                                                .tint(.blue)
                                        } icon: {
                                            Rectangle()
                                                .fill(.gray)
                                                .frame(width: 8, height: 8)
                                        }

                                        Label {
                                            Link("Web URL", destination: URL(string: audioFile.webUrl)!)
                                                .font(.system(size: 11))
                                                .tint(.blue)
                                        } icon: {
                                            Rectangle()
                                                .fill(.gray)
                                                .frame(width: 8, height: 8)
                                        }

                                        Spacer()
                                    }
                                    .frame(minWidth: 0, maxWidth: .infinity, alignment: .topLeading)
                                    .padding(5)

                                    Spacer()
                                }
                            }
                            .listRowSeparator(.hidden)
                            .listRowBackground(Ellipse()
                                .background(Color.black)
                                .foregroundColor(Color.clear)
                                .opacity(0.25)
                            )

                            /*
                             VideoFile
                             */
                            ForEach(self.selectedVideoFiles) { videoFile in
                                Section {
                                    VStack(alignment: .leading, spacing: 5) {
                                        Label {
                                            Link("\(videoFile.folder.name)", destination: URL(string: videoFile.folder.webUrl)!)
                                                .font(.system(size: 11))
                                                .truncationMode(.middle)
                                                .tint(.blue)

                                            Text(" / ")
                                                .foregroundStyle(.gray)

                                            Link("\(videoFile.fileName)", destination: URL(string: videoFile.webUrl)!)
                                                .font(.system(size: 11))
                                                .truncationMode(.middle)
                                                .tint(.blue)
                                        } icon: {
                                            Image(systemName: "doc.circle.fill")
                                                .font(.system(size: 11))
                                        }

                                        if (videoFile.aasmState == "created") {
                                            Text("Processing…")
                                                .font(.system(size: 11))
                                                .padding(10)
                                        } else if (videoFile.aasmState == "processed") {
                                            VideoPlayer(player: player)
                                                .frame(minWidth: 400, maxWidth: .infinity,
                                                       minHeight: 300, maxHeight: .infinity)
                                                .padding(10)
                                        }

                                        Label {
                                            Text("Format \(videoFile.formatInfo ?? "")")
                                                .font(.system(size: 11))
                                                .foregroundStyle(.gray)
                                        } icon: {
                                            Rectangle()
                                                .fill(.gray)
                                                .frame(width: 8, height: 8)
                                        }

                                        Label {
                                            Text("Mime/Type \(videoFile.mimeType ?? "")")
                                                .font(.system(size: 11))
                                                .foregroundStyle(.gray)
                                        } icon: {
                                            Rectangle()
                                                .fill(.gray)
                                                .frame(width: 8, height: 8)
                                        }

                                        Label {
                                            Text("File Size \(videoFile.fileSize ?? 0)")
                                                .font(.system(size: 11))
                                                .foregroundStyle(.gray)
                                        } icon: {
                                            Rectangle()
                                                .fill(.gray)
                                                .frame(width: 8, height: 8)
                                        }

                                        Label {
                                            Text("Title \(videoFile.title ?? "")")
                                                .font(.system(size: 11))
                                                .foregroundStyle(.gray)
                                        } icon: {
                                            Rectangle()
                                                .fill(.gray)
                                                .frame(width: 8, height: 8)
                                        }

                                        Label {
                                            Text("Bitrate \(videoFile.bitrate ?? 0)")
                                                .font(.system(size: 11))
                                                .foregroundStyle(.gray)
                                        } icon: {
                                            Rectangle()
                                                .fill(.gray)
                                                .frame(width: 8, height: 8)
                                        }

                                        Label {
                                            Text("FrameRate \(videoFile.frameRate ?? 0)")
                                                .font(.system(size: 11))
                                                .foregroundStyle(.gray)
                                        } icon: {
                                            Rectangle()
                                                .fill(.gray)
                                                .frame(width: 8, height: 8)
                                        }

                                        Label {
                                            Text("Length (s) \(videoFile.length ?? 0)")
                                                .font(.system(size: 11))
                                                .foregroundStyle(.gray)
                                        } icon: {
                                            Rectangle()
                                                .fill(.gray)
                                                .frame(width: 8, height: 8)
                                        }

                                        Label {
                                            Text("Width \(videoFile.width ?? 0)")
                                                .font(.system(size: 11))
                                                .foregroundStyle(.gray)
                                        } icon: {
                                            Rectangle()
                                                .fill(.gray)
                                                .frame(width: 8, height: 8)
                                        }

                                        Label {
                                            Text("Height \(videoFile.height ?? 0)")
                                                .font(.system(size: 11))
                                                .foregroundStyle(.gray)
                                        } icon: {
                                            Rectangle()
                                                .fill(.gray)
                                                .frame(width: 8, height: 8)
                                        }

                                        Label {
                                            Text("Aspect Ratio: \(videoFile.aspectRatio ?? 0)")
                                                .font(.system(size: 11))
                                                .foregroundStyle(.gray)
                                        } icon: {
                                            Rectangle()
                                                .fill(.gray)
                                                .frame(width: 8, height: 8)
                                        }

                                        Label {
                                            Link("File URL", destination: URL(string: videoFile.fileUrl)!)
                                                .font(.system(size: 11))
                                                .tint(.blue)
                                        } icon: {
                                            Rectangle()
                                                .fill(.gray)
                                                .frame(width: 8, height: 8)
                                        }

                                        Label {
                                            Link("Web URL", destination: URL(string: videoFile.webUrl)!)
                                                .font(.system(size: 11))
                                                .tint(.blue)
                                        } icon: {
                                            Rectangle()
                                                .fill(.gray)
                                                .frame(width: 8, height: 8)
                                        }

                                        Spacer()
                                    }
                                    .frame(minWidth: 0, maxWidth: .infinity, alignment: .topLeading)
                                    .padding(5)

                                    Spacer()
                                }
                            }
                            .listRowSeparator(.hidden)
                            .listRowBackground(Ellipse()
                                .background(Color.black)
                                .foregroundColor(Color.clear)
                                .opacity(0.25)
                            )

                            /*
                             PdfFile
                             */
                            ForEach(self.selectedPdfFiles) { pdfFile in
                                Section {
                                    VStack(alignment: .leading, spacing: 5) {
                                        Label {
                                            Link("\(pdfFile.folder.name)", destination: URL(string: pdfFile.folder.webUrl)!)
                                                .font(.system(size: 11))
                                                .truncationMode(.middle)
                                                .tint(.blue)

                                            Text(" / ")
                                                .foregroundStyle(.gray)

                                            Link("\(pdfFile.fileName)", destination: URL(string: pdfFile.webUrl)!)
                                                .font(.system(size: 11))
                                                .truncationMode(.middle)
                                                .tint(.blue)
                                        } icon: {
                                            Image(systemName: "doc.circle.fill")
                                                .font(.system(size: 11))
                                        }

                                        Image(systemName: "square.text.square")
                                            .font(.system(size: 40))
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .padding(10)

                                        Label {
                                            Text("Mime/Type \(pdfFile.mimeType ?? "")")
                                                .font(.system(size: 11))
                                                .foregroundStyle(.gray)
                                        } icon: {
                                            Rectangle()
                                                .fill(.gray)
                                                .frame(width: 8, height: 8)
                                        }

                                        Label {
                                            Text("Format \(pdfFile.formatInfo ?? "")")
                                                .font(.system(size: 11))
                                                .foregroundStyle(.gray)
                                        } icon: {
                                            Rectangle()
                                                .fill(.gray)
                                                .frame(width: 8, height: 8)
                                        }

                                        Label {
                                            Text("File Size \(pdfFile.fileSize ?? "")")
                                                .font(.system(size: 11))
                                                .foregroundStyle(.gray)
                                        } icon: {
                                            Rectangle()
                                                .fill(.gray)
                                                .frame(width: 8, height: 8)
                                        }

                                        Label {
                                            Link("File URL", destination: URL(string: pdfFile.fileUrl)!)
                                                .font(.system(size: 11))
                                                .tint(.blue)
                                        } icon: {
                                            Rectangle()
                                                .fill(.gray)
                                                .frame(width: 8, height: 8)
                                        }

                                        Label {
                                            Link("Web URL", destination: URL(string: pdfFile.webUrl)!)
                                                .font(.system(size: 11))
                                                .tint(.blue)
                                        } icon: {
                                            Rectangle()
                                                .fill(.gray)
                                                .frame(width: 8, height: 8)
                                        }

                                        Spacer()

                                        Divider()

                                        Spacer()

                                        Button(action: {
                                            if let url = URL(string: pdfFile.webViewUrl) {
                                                openURL(url)
                                            }
                                        }) {
                                            Image(systemName: "globe")
                                                .font(.system(size: 11))

                                            Text("Open in web view")
                                                .font(.system(size: 11))
                                        }
                                        .buttonStyle(.borderedProminent)
                                        .tint(.blue)
                                        .padding(5)
                                    }
                                    .frame(minWidth: 0, maxWidth: .infinity, alignment: .topLeading)
                                    .padding(5)

                                    Spacer()
                                }
                            }
                            .listRowSeparator(.hidden)
                            .listRowBackground(Ellipse()
                                .background(Color.black)
                                .foregroundColor(Color.clear)
                                .opacity(0.25)
                            )

                            /*
                             TextFile
                             */
                            ForEach(self.selectedTextFiles) { textFile in
                                Section {
                                    VStack(alignment: .leading, spacing: 5) {
                                        Label {
                                            Link("\(textFile.folder.name)", destination: URL(string: textFile.folder.webUrl)!)
                                                .font(.system(size: 11))
                                                .truncationMode(.middle)
                                                .tint(.blue)

                                            Text(" / ")
                                                .foregroundStyle(.gray)

                                            Link("\(textFile.fileName)", destination: URL(string: textFile.webUrl)!)
                                                .font(.system(size: 11))
                                                .truncationMode(.middle)
                                                .tint(.blue)
                                        } icon: {
                                            Image(systemName: "doc.circle.fill")
                                                .font(.system(size: 11))
                                        }

                                        Label {
                                            Link("\(textFile.fileName)", destination: URL(string: textFile.webUrl)!)
                                                .font(.system(size: 11))
                                                .truncationMode(.middle)
                                                .tint(.blue)
                                        } icon: {
                                            Image(systemName: "doc.circle")
                                                .font(.system(size: 11))
                                        }

                                        Label {
                                            Text("Mime/Type \(textFile.mimeType ?? "")")
                                                .font(.system(size: 11))
                                                .foregroundStyle(.gray)
                                        } icon: {
                                            Rectangle()
                                                .fill(.gray)
                                                .frame(width: 8, height: 8)
                                        }

                                        Label {
                                            Text("Format \(textFile.formatInfo ?? "")")
                                                .font(.system(size: 11))
                                                .foregroundStyle(.gray)
                                        } icon: {
                                            Rectangle()
                                                .fill(.gray)
                                                .frame(width: 8, height: 8)
                                        }

                                        Label {
                                            Text("File Size \(textFile.fileSize ?? "")")
                                                .font(.system(size: 11))
                                                .foregroundStyle(.gray)
                                        } icon: {
                                            Rectangle()
                                                .fill(.gray)
                                                .frame(width: 8, height: 8)
                                        }

                                        Label {
                                            Link("File URL", destination: URL(string: textFile.fileUrl)!)
                                                .font(.system(size: 11))
                                                .tint(.blue)
                                        } icon: {
                                            Rectangle()
                                                .fill(.gray)
                                                .frame(width: 8, height: 8)
                                        }

                                        Label {
                                            Link("Web URL", destination: URL(string: textFile.webUrl)!)
                                                .font(.system(size: 11))
                                                .tint(.blue)
                                        } icon: {
                                            Rectangle()
                                                .fill(.gray)
                                                .frame(width: 8, height: 8)
                                        }

                                        Spacer()

                                        Divider()

                                        Spacer()

                                        Button(action: {
                                            if let url = URL(string: textFile.webViewUrl) {
                                                openURL(url)
                                            }
                                        }) {
                                            Image(systemName: "globe")
                                                .font(.system(size: 11))

                                            Text("Open in web view")
                                                .font(.system(size: 11))
                                        }
                                        .buttonStyle(.borderedProminent)
                                        .tint(.blue)
                                        .padding(5)
                                    }
                                    .frame(minWidth: 0, maxWidth: .infinity, alignment: .topLeading)
                                    .padding(5)

                                    Spacer()
                                }
                            }
                            .listRowSeparator(.hidden)
                            .listRowBackground(Ellipse()
                                .background(Color.black)
                                .foregroundColor(Color.clear)
                                .opacity(0.25)
                            )
                        }

                        /*
                         Folders, Attachments: Clear selection
                         */
                        if (self.selectedImageFiles.count > 0 ||
                            self.selectedAudioFiles.count > 0 ||
                            self.selectedPdfFiles.count > 0 ||
                            self.selectedVideoFiles.count > 0 ||
                            self.selectedTextFiles.count > 0 ||
                            self.selectedFolders.count > 0) {
                            HStack {
                                Button(action: clearSelection) {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 9))
                                        .foregroundStyle(Color.primary)
                                    Text("Clear selection")
                                        .font(.system(size: 9))
                                        .foregroundStyle(Color.primary)
                                }
                                .font(.system(size: 11))
                                .padding(5)
                                .opacity(0.9)
                                .glassEffect(.regular.tint(.clear).interactive(), in: .capsule)
                                .buttonStyle(.glassProminent)
                            }
                            .frame(minWidth: 0, maxWidth: .infinity, alignment: .center)
                        }
                    }
                }
                .navigationSplitViewColumnWidth(
                    min: 350,
                    ideal: 350,
                    max: .infinity
                )
            } else {
                // default login panel
            }
        } else {
            // not identified
        }
    }

    // Under the Import button: the plan, what the files take of it, and why
    // files were refused during the last import
    @ViewBuilder
    var planSummary: some View {
        if let plan = planUsage {
            HStack(spacing: 8) {
                Text("\(plan.name) plan · \(PlanUsage.size(plan.storage.used)) of \(PlanUsage.size(plan.storage.limit)) · \(plan.users.count) of \(plan.users.limit) users")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                ProgressView(value: plan.storageFraction)
                    .tint(plan.storage.used >= plan.storage.limit ? .red : .accentColor)
                    .frame(maxWidth: 160)
            }
            .padding(.horizontal, 5)
        }
        ForEach(refusedUploads.keys.sorted(), id: \.self) { reason in
            Text("\(reason) (files not uploaded: \(refusedUploads[reason] ?? 0))")
                .font(.caption)
                .foregroundStyle(.red)
                .padding(.horizontal, 5)
        }
    }
}

