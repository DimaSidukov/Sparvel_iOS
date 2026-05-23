//
//  ContentViewViewModel.swift
//  Sparvel
//
//  Created by Dmitriy Sidukov on 07.05.2026.
//

import Observation

@Observable
class ContentViewViewModel {
    
    private let player : AudioPlayer = NativeAudioPlayer()
    private(set) var isPlayerExpanded = false
    
    var uiState: ContentViewState {
        ContentViewState(
            currentSong: player.currentSong,
            isPlayerExpanded: isPlayerExpanded,
            isPlaying: player.isPlaying
        )
    }
    var currentPosition : Double {
        player.currentPosition
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
    
    private func togglePlayback() {
        player.pause()
    }
    
    private func togglePlayerSheetState() {
        isPlayerExpanded = !isPlayerExpanded
    }
    
    private func selectSong(song: Song) {
        player.play(song: song)
    }
    
    private func seekTo(position: Double) {
        player.seek(position: position)
    }
    
}

