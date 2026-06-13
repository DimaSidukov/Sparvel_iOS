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
    
    private var selectedSong: Song? = nil
    
    private var audioEngine : NativeAudioEngine?
    
    init() {
        self.audioEngine = NativeAudioEngine(
            position: { newPosition, force in
                DispatchQueue.main.async {
                    guard let currentSong = self.currentSong else { return }
                    let positionInSeconds = ((Double(newPosition) / 1000) / Double(currentSong.duration)) * 100.0
                    self.currentPosition = positionInSeconds
                }
            },
            state: { isCurrentlyPlaying in
                DispatchQueue.main.async {
                    self.isPlaying = isCurrentlyPlaying == 1
                }
            },
            initialization: { isSuccess in
                DispatchQueue.main.async {
                    if isSuccess == 0 {
                        self.currentSong = self.selectedSong
                    }
                }
            }
        )
    }
    
    func play(song: Song) {
        
        self.selectedSong = song
        
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
        
        audioEngine?.play(url)
    }
    
    func pause() {
        audioEngine?.pause()
    }
    
    func release() {
        // TODO: use ARC release overload?
        audioEngine?.releasePlayer()
    }
    
    func seek(position: Double) {
        guard let currentSong = currentSong else { return }
        let positionMs = Int64((position / 100.0) * Double(currentSong.duration * 1000))
        audioEngine?.seek(positionMs)
    }
    
    
}
