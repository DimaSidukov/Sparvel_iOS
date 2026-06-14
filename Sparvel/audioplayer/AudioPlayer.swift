//
//  AudioPlayer.swift
//  Sparvel
//
//  Created by Dmitriy Sidukov on 13.05.2026.
//


protocol AudioPlayer {
    
    var isPlaying: Bool { get }
    
    // 0-100 range
    var currentPositionInPercents: Double { get }
    
    var currentSong: Song? { get }
    
    func play(song: Song)
    
    func pause()
    
    func release()
    
    // 0-100 range
    func seek(position: Double)
    
}
