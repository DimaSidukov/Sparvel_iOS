//
//  SongsView.swift
//  Sparvel
//
//  Created by Dmitriy Sidukov on 28.04.2026.
//

import SwiftUI
internal import UniformTypeIdentifiers
internal import AVFoundation

struct SongsView : View {
    
    let onSongSelected: (Song) -> Void
    
    @State
    private var viewModel = SongsViewViewModel()
    
    @State var isShowing = false
    
    var body: some View {
        VStack {
            switch viewModel.uiState {
            case .NoData:
                NoDataView(
                    isFileImporterVisible: $isShowing,
                    onIntent: { intent in
                        viewModel.onIntent(intent: intent)
                    },
                    onFileSelectToggleChange: { isVisible in
                        isShowing = isVisible
                    }
                    
                )
            case .Data(let loadedSongsViewState):
                DataView(
                    uiState: loadedSongsViewState,
                    isFileImporterVisible: $isShowing,
                    onIntent: { intent in
                        viewModel.onIntent(intent: intent)
                    },
                    onFileSelectToggleChange: { isVisible in
                        isShowing = isVisible
                    },
                    onSongSelected: { song in
                        onSongSelected(song)
                    }
                )
            case .Error(let errorViewState):
                ErrorView(uiState: errorViewState)
            case .Loading:
                LoadingView()
            }
        }
    }
}

fileprivate struct NoDataView: View {
    
    let isFileImporterVisible: Binding<Bool>
    let onIntent: (SongsIntent) -> Void
    let onFileSelectToggleChange : (Bool  ) -> Void
    
    var buttonStyle : some PrimitiveButtonStyle {
        if #available(iOS 26.0, *) {
            return .glass
        } else {
            return .automatic
        }
    }
    
    var body: some View {
        Text("Click on the button below to load songs")
        
        Button {
            onFileSelectToggleChange(true)
        } label: {
            Image(systemName: "plus")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 20, height: 20)
                .padding(.horizontal, 4)
                .padding(.vertical, 8)
                .clipShape(Circle())
        }
        .buttonStyle(buttonStyle)
        .fileImporter(
            isPresented: isFileImporterVisible,
            allowedContentTypes: [.folder, .audio],
            allowsMultipleSelection: true
        ) { result in
            switch result {
            case .success(let urls):
                onIntent(SongsIntent.LoadSongs(urls))
            case .failure(let error):
                print(error)
                onIntent(SongsIntent.RequestErrorState)
            }
        }
    }
}

fileprivate struct ErrorView: View {
    
    let uiState: String
    
    var body: some View {
        Text(uiState)
            .multilineTextAlignment(.center)
    }
}

fileprivate struct LoadingView : View {
    var body: some View {
        ProgressView()
    }
}

fileprivate struct DataView: View {
    
    let uiState: LoadedSongsViewState
    @State var text: String = ""
    
    let isFileImporterVisible: Binding<Bool>
    let onIntent: (SongsIntent) -> Void
    let onFileSelectToggleChange : (Bool  ) -> Void
    let onSongSelected: (Song) -> Void
    
    var body: some View {
        NavigationStack {
            List(uiState.songs, id: \.self.id) { song in
                SongItem(
                    title: song.title,
                    artist: song.artist,
                    bookmarkData: song.bookmarkData
                ).listRowBackground(Color.clear)
                    .onTapGesture {
                        onSongSelected(song)
                    }
            }.toolbar {
                ToolbarItem(placement: .automatic) {
                    TextField("Search", text: $text)
                        .textFieldStyle(.plain)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .padding(.leading, 16)
                }
                if #available(iOS 26.0, *) {
                    ToolbarSpacer()
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        onFileSelectToggleChange(true)
                    } label: {
                        Image(systemName: "plus")
                    }.fileImporter(
                        isPresented: isFileImporterVisible,
                        allowedContentTypes: [.folder, .audio],
                        allowsMultipleSelection: true
                    ) { result in
                        switch result {
                        case .success(let urls):
                            onIntent(SongsIntent.LoadSongs(urls))
                        case .failure(let error):
                            print(error)
                            onIntent(SongsIntent.RequestErrorState)
                        }
                    }
                }
            }
        }
    }
}

fileprivate struct SongItem: View {
    
    let title: String
    let artist: String
    let bookmarkData: Data?
    
    @State var placeholderColor = Color.random
    @State var artwork: UIImage? = nil
    
    var body: some View {
        HStack {
            ZStack {
                placeholderColor.opacity(artwork == nil ? 1 : 0)
                
                Image(uiImage: artwork ?? UIImage())
                    .resizable()
                    .scaledToFill()
                    .opacity(artwork == nil ? 0 : 1)
            }
            .frame(width: 50, height: 50)
            .clipShape(
                RoundedRectangle(
                    cornerSize: CGSize(width: 16, height: 16),
                    style: .continuous
                )
            )
            .clipped()
            .animation(.easeInOut(duration: 0.5), value: artwork != nil)
            
            VStack(alignment: .leading) {
                Text(title).lineLimit(1).truncationMode(.tail)
                Text(artist).lineLimit(1).truncationMode(.tail)
            }
            .padding(.leading, 8)
        }
        .task {
            guard artwork == nil else { return }
            
            if let data = bookmarkData,
               let image = await loadArtwork(bookmarkData: data) {
                artwork = image
            }
        }
    }
}

extension Color {
    static var random: Color {
        return Color(
            red: .random(in: 0...1),
            green: .random(in: 0...1),
            blue: .random(in: 0...1)
        )
    }
}

#Preview {
    SongsView { song in
        
    }
}

