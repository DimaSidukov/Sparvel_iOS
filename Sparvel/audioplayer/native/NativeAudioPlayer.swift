//
//  NativeAudioPlayer.swift
//  Sparvel
//
//  Created by Dmitriy Sidukov on 15.05.2026.
//

import Combine

class NativeAudioPlayer : AudioPlayer {
    
    @Published var isPlaying: Bool = false
    @Published var currentPosition: Double = 0.0
    @Published var currentSong: Song? = nil
    
    var isPlayingPublisher: Published<Bool>.Publisher { $isPlaying }
    var currentPositionPublisher: Published<Double>.Publisher { $currentPosition }
    var currentSongPublisher: Published<Song?>.Publisher { $currentSong }
    
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
