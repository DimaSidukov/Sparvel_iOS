//
//  ContentView.swift
//  Sparvel
//
//  Created by Dmitriy Sidukov on 27.04.2026.
//

import SwiftUI

let collapsedPlayerImageSize = 40.0
let collapsedPlayerImageVerticalPadding = 8.0

struct ContentView: View {
    
    @State
    private var viewModel = ContentViewViewModel()
    
    private var state: ContentViewState {
        viewModel.uiState
    }
    
    private let uiTabBarController = UITabBarController()
    
    var body: some View {
        ZStack {
            TabView {
                SongsView(
                    bottomContentMargin: state.currentSong == nil
                        ? 0
                        : collapsedPlayerImageSize + (collapsedPlayerImageVerticalPadding * 2) +
                            16.0
                ) { song in
                    viewModel.onIntent(intent: ContentIntent.SelectSong(song))
                }.tabItem {
                    Label("Songs", systemImage: "music.note")
                }
                SimpleView()
                    .tabItem {
                        Label("Albums", systemImage: "music.pages")
                    }
                SimpleView()
                    .tabItem {
                        Label("Playlists", systemImage: "music.note.list")
                    }
                SimpleView()
                    .tabItem {
                        Label("Settings", systemImage: "gear")
                    }
            }
            .overlay(alignment: .bottom) {
                ZStack {
                    let song = state.currentSong
                    if song != nil {
                        CollapsedPlayerView(
                            song: song!,
                            isPlaying: state.isPlaying,
                            onIntent: { intent in
                                viewModel.onIntent(intent: intent)
                            }
                        )
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: 100)
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: 26,
                        style: .continuous
                    )
                )
                .padding(.bottom, uiTabBarController.height)
                .padding(.top, 16)
                .padding(.leading, 16)
                .padding(.trailing, 16)
                
            }.ignoresSafeArea()
            if (state.isPlayerExpanded) {
                ExpandedPlayerView(
                    song: state.currentSong!,
                    isPlaying: state.isPlaying,
                    currentPosition: viewModel.currentPosition,
                    onIntent: { intent in
                        viewModel.onIntent(intent: intent)
                    }
                )
                .transition(
                    .asymmetric(
                        insertion: .move(edge: .bottom),
                        removal: .move(edge: .top)
                    ))
            }
        }
    }
}

struct CollapsedPlayerView: View {
    
    let song: Song
    let isPlaying: Bool
    let onIntent: (ContentIntent) -> Void
    
    var image : String {
        if (isPlaying) {
            "pause.fill"
        } else {
            "play.fill"
        }
    }
    
    var body: some View {
        if #available(iOS 26.0, *) {
            CollapsedPlayerContentView(
                song: song,
                isPlaying: isPlaying,
                onIntent: onIntent
            ).glassEffect()
            
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.35)) {
                    onIntent(ContentIntent.TogglePlayerSheetState)
                }
            }
        } else {
            CollapsedPlayerContentView(
                song: song,
                isPlaying: isPlaying,
                onIntent: onIntent
            ).background(.background)
            
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.35)) {
                    onIntent(ContentIntent.TogglePlayerSheetState)
                }
            }
        }
    }
}

struct CollapsedPlayerContentView : View {
    
    let song: Song
    let isPlaying: Bool
    let onIntent: (ContentIntent) -> Void
    
    @State var artwork: UIImage? = nil
    @State var placeholderColor = Color.random
    
    var image : String {
        if (isPlaying) {
            "pause.fill"
        } else {
            "play.fill"
        }
    }
    
    var body: some View {
        HStack {
            ZStack {
                placeholderColor
                    .opacity(artwork == nil ? 1 : 0)
                
                Image(uiImage: artwork ?? UIImage())
                    .resizable()
                    .scaledToFill()
                    .opacity(artwork == nil ? 0 : 1)
            }
            .frame(
                width: collapsedPlayerImageSize,
                height: collapsedPlayerImageSize
            )
            .clipShape(
                RoundedRectangle(
                    cornerSize: CGSize(width: 16, height: 16),
                    style: .continuous
                )
            )
            .padding(.vertical, collapsedPlayerImageVerticalPadding)
            .animation(.easeInOut(duration: 0.5), value: artwork != nil)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(song.title)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Text(song.artist)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            
            Spacer(minLength: 0)
            
            Button {
                onIntent(ContentIntent.TogglePlayback)
            } label: {
                Image(systemName: image)
                    .font(.title3)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .padding(.leading, 16)
        .task(id: song.id) {
            if let data = song.bookmarkData,
               let image = await loadArtwork(bookmarkData: data) {
                withAnimation(.easeInOut(duration: 0.5)) {
                    artwork = image
                }
            } else {
                artwork = nil
            }
        }
    }
}


struct ExpandedPlayerView : View {
    
    let song: Song
    let isPlaying: Bool
    let currentPosition: Double
    let onIntent: (ContentIntent) -> Void
    
    @State var placeholderColor = Color.random
    @State var artwork: UIImage? = nil
    
    @State private var sliderPosition = 0.0
    @State private var isEditing = false
    
    var playButtonImage : String {
        if (isPlaying) {
            "pause.fill"
        } else {
            "play.fill"
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading) {
                ZStack {
                    placeholderColor
                        .opacity(artwork == nil ? 1 : 0)
                    
                    Image(uiImage: artwork ?? UIImage())
                        .resizable()
                        .scaledToFill()
                        .opacity(artwork == nil ? 0 : 1)
                }
                .aspectRatio(1, contentMode: .fit)
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: 32,
                        style: .continuous
                    )
                )
                .padding(.horizontal, 16)
                .clipped()
                .animation(.easeInOut(duration: 0.5), value: artwork != nil)
                
                VStack(alignment: .leading) {
                    Text(song.title)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .font(.largeTitle)
                    Text(song.artist)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .font(.title3)
                }
                .padding(.leading, 16)
                .padding(.top, 32)
                
                Slider(
                    value: $sliderPosition,
                    in: 0.0...100.0,
                    onEditingChanged: { editing in
                        isEditing = editing
                        
                        if !editing {
                            onIntent(ContentIntent.UpdateSliderPosition(sliderPosition))
                        }
                    }
                )
                .onAppear {
                    sliderPosition = currentPosition
                }
                .onChange(of: currentPosition) { _, newValue in
                    guard !isEditing else {
                        return
                    }
                    
                    sliderPosition = newValue
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                
                HStack {
                    Text(
                        formatProgress(
                            progress: sliderPosition,
                            duration: song.duration
                        )
                    )
                    .font(.subheadline)
                    
                    Spacer()
                    
                    Text(formatDuration(duration: song.duration))
                        .font(.subheadline)
                }.padding(.horizontal, 16)
                
                HStack {
                    Button {
                        // Shuffle
                    } label: {
                        Image(systemName: "shuffle")
                            .font(.title2)
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity)
                    }
                    
                    Button {
                        // Previous track
                    } label: {
                        Image(systemName: "backward.fill")
                            .font(.title)
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity)
                    }
                    
                    Button {
                        onIntent(ContentIntent.TogglePlayback)
                    } label: {
                        Image(systemName: playButtonImage)
                            .font(.largeTitle)
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity)
                    }
                    
                    Button {
                        // Next track
                    } label: {
                        Image(systemName: "forward.fill")
                            .font(.title)
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity)
                    }
                    
                    Button {
                        // Repeat
                    } label: {
                        Image(systemName: "repeat")
                            .font(.title2)
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.35)) {
                            onIntent(ContentIntent.TogglePlayerSheetState)
                        }
                    } label: {
                        Image(systemName: "chevron.down")
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        
                    } label: {
                        Image(systemName: "slider.vertical.3")
                    }
                }
            }
            .task {
                guard artwork == nil else { return }
                
                if let data = song.bookmarkData,
                   let image = await loadArtwork(bookmarkData: data) {
                    withAnimation(.easeInOut(duration: 0.5)) {
                        artwork = image
                    }
                }
            }
        }
    }
}

struct SimpleView : View {
    var body: some View {
        Text("Hello world")
    }
}

fileprivate func formatProgress(progress: Double, duration: Int64) -> String {
    // TODO: for some songs duration is zero, compute differently
    let progressInMillis = Int64((progress / 100) * Double(duration))
    return formatDuration(duration: progressInMillis)
}

fileprivate func formatDuration(duration: Int64) -> String {
    let hours = duration / 3600
    let minutes = (duration % 3600) / 60
    let seconds = duration % 60
    
    if hours > 0 {
        return String(
            format: "%02lld:%02lld:%02lld",
            hours,
            minutes,
            seconds
        )
    }
    
    return String(
        format: "%02lld:%02lld",
        minutes,
        seconds
    )
}

extension UITabBarController {
    var height: CGFloat {
        return self.tabBar.frame.size.height
    }
    var width: CGFloat {
        return self.tabBar.frame.size.width
    }
}

#Preview {
    ExpandedPlayerView(song: Song(id: "sdf", title: "sdfd", artist: "sdf", duration: 327000), isPlaying: false, currentPosition: 30) { intent in
        
    }
}
