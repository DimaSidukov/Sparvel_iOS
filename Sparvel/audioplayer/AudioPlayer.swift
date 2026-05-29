//
//  AudioPlayer.swift
//  Sparvel
//
//  Created by Dmitriy Sidukov on 13.05.2026.
//

import Combine

protocol AudioPlayer {
    
    var isPlayingPublisher: Published<Bool>.Publisher { get }
    
    // 0-100 range
    var currentPositionPublisher: Published<Double>.Publisher { get }
    
    var currentSongPublisher: Published<Song?>.Publisher { get }
    
    func play(song: Song)
    
    func pause()
    
    func release()
    
    // 0-100 range
    func seek(position: Double)
    
}
