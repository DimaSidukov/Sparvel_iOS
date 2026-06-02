//
//  ContentViewState.swift
//  Sparvel
//
//  Created by Dmitriy Sidukov on 13.05.2026.
//

struct ContentViewState {
    let currentSong: Song?
    let isPlayerExpanded: Bool
    let isPlaying: Bool
    
    func copy(
        currentSong: Song? = nil,
        isPlayerExpanded: Bool? = nil,
        isPlaying: Bool? = nil
    ) -> ContentViewState {
        return ContentViewState(
            currentSong: currentSong ?? self.currentSong,
            isPlayerExpanded: isPlayerExpanded ?? self.isPlayerExpanded,
            isPlaying: isPlaying ?? self.isPlaying
        )
    }
}

