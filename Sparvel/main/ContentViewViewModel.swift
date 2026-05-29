//
//  ContentViewViewModel.swift
//  Sparvel
//
//  Created by Dmitriy Sidukov on 07.05.2026.
//

import Combine

class ContentViewViewModel : ObservableObject {
    
    private let player : AudioPlayer = NativeAudioPlayer()
    
    @Published private(set) var uiState: ContentViewState = ContentViewState(
        currentSong: nil,
        isPlayerExpanded: false,
        isPlaying: false
    )
    
    @Published private(set) var currentPosition : Double = 0.0

    private var currentSongSubscriber: AnyCancellable?
    private var isPlayingSubscriber: AnyCancellable?
    private var currentPositionSubsriber: AnyCancellable?
    
    init() {
        subscribeToEvents()
    }
    
    func onIntent(intent: ContentIntent) {
        switch intent {
        case .TogglePlayback:
            togglePlayback()
        case .TogglePlayerSheetState:
            togglePlayerSheetState()
        case .SelectSong(let song):
            selectSong(song: song)
        case .UpdateSliderPosition(let position):
            seekTo(position: position)
        }
        
    }
    
    private func subscribeToEvents() {
        currentSongSubscriber = player.currentSongPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newValue in
                guard let self else { return }
                self.uiState = self.uiState.copy(currentSong: newValue)
            }
        isPlayingSubscriber = player.isPlayingPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newValue in
                guard let self else { return }
                self.uiState = self.uiState.copy(isPlaying: newValue)
            }
        currentPositionSubsriber = player.currentPositionPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newValue in
                guard let self else { return }
                self.currentPosition = newValue
            }
    }
    
    private func togglePlayback() {
        player.pause()
    }
    
    private func togglePlayerSheetState() {
        self.uiState = self.uiState.copy(isPlayerExpanded: !self.uiState.isPlayerExpanded)
    }
    
    private func selectSong(song: Song) {
        player.play(song: song)
    }
    
    private func seekTo(position: Double) {
        player.seek(position: position)
    }
    
}

