//
//  NativeAudioPlayer.swift
//  Sparvel
//
//  Created by Dmitriy Sidukov on 15.05.2026.
//

import Observation

@Observable
class NativeAudioPlayer : AudioPlayer {
    
    var isPlaying: Bool = false
    var currentPosition: Double = 0.0
    var currentSong: Song? = nil
    
    let audioEngine = NativeAudioEngine()
    
    func play(song: Song) {
        
        guard let bookmarkData = song.bookmarkData else {
            return
        }
        var isStale = true

        guard let url = try? URL(
            resolvingBookmarkData: bookmarkData,
            options: [],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        ) else {
            isPlaying = false
            return
        }
        
        audioEngine.play(url)
    }
    
    func pause() {
        audioEngine.pause()
    }
    
    func release() {
        // TODO: use ARC release overload?
        audioEngine.releasePlayer()
    }
    
    func seek(position: Double) {
        guard let currentSong = currentSong else { return }
        let positionMs = Int64((position / 100.0) * Double(currentSong.duration))
        audioEngine.seek(positionMs)
    }
    
    
}
