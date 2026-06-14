//
//  NativeAudioPlayer.swift
//  Sparvel
//
//  Created by Dmitriy Sidukov on 15.05.2026.
//

import Observation
import AVFAudio
import MediaPlayer
import Synchronization

// TODO: smeared and confusing logic with percents, milliseconds, seconds - unify
// TODO: extract duration in milliseconds - more precise for calculations
@Observable
class NativeAudioPlayer : AudioPlayer {
    
    var isPlaying: Bool = false
    var currentPositionInPercents: Double = 0.0
    var currentSong: Song? = nil
    
    private var selectedSong: Song? = nil
    private var currentPositionInSeconds: Int32 = 0
    private let isSeekInProgress = Atomic<Bool>(false)
    private var isSessionActive: Bool = false
    private var nowPlayingInfo = [String: Any]()
    
    private var audioEngine : NativeAudioEngine?
    private let imageCache = ImageCache.shared
    
    init() {
        self.audioEngine = NativeAudioEngine(
            position: { newPosition, force in
                DispatchQueue.main.async {
                    guard let currentSong = self.currentSong else { return }
                    self.currentPositionInSeconds = Int32(newPosition / 1000)
                    let positionInPercents = (Double(self.currentPositionInSeconds) / Double(currentSong.duration)) * 100.0
                    self.currentPositionInPercents = positionInPercents
                    
                    
                    if (self.isSeekInProgress.load(ordering: .acquiring)) {
                        self.updateNotificationView(
                            isCurrentlyPlaying: true,
                            positionInSeconds: self.currentPositionInSeconds
                        )
                        self.isSeekInProgress.compareExchange(
                            expected: true,
                            desired: false,
                            ordering: .acquiringAndReleasing
                        )
                    }
                }
            },
            state: { isCurrentlyPlaying in
                DispatchQueue.main.async {
                    self.isPlaying = isCurrentlyPlaying == 1
                    self.updateNotificationView(
                        isCurrentlyPlaying: self.isPlaying,
                        positionInSeconds: self.currentPositionInSeconds
                    )
                }
            },
            initialization: { isSuccess in
                DispatchQueue.main.async {
                    if isSuccess == 0 {
                        self.currentSong = self.selectedSong
                        self.setupMediaPlayerNotificationView()
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
        
        if !isSessionActive {
            do {
                try AVAudioSession.sharedInstance().setCategory(.playback, options: [])
                try AVAudioSession.sharedInstance().setActive(true)
            } catch {
                print("Error received when initialising AVAudioSession \(error)")
            }
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
        
        updateNotificationView(isCurrentlyPlaying: false, positionInSeconds: self.currentPositionInSeconds)
        isSeekInProgress.compareExchange(
            expected: false,
            desired: true,
            ordering: .acquiringAndReleasing
        )
        
        audioEngine?.seek(positionMs)
    }
    
    private func setupMediaPlayerNotificationView() {
        let commandCenter = MPRemoteCommandCenter.shared()
        
        // TODO: should change unowned to weak?
        commandCenter.playCommand.addTarget { [unowned self] event in
            self.pause()
            return .success
        }
        commandCenter.pauseCommand.addTarget { [unowned self] event in
            self.pause()
            return .success
        }
        commandCenter.previousTrackCommand.addTarget { [unowned self] event in
            return .success
        }
        commandCenter.nextTrackCommand.addTarget { [unowned self] event in
            return .success
        }
        commandCenter.changePlaybackPositionCommand.addTarget { [unowned self] event in
            guard let positionEvent = event as? MPChangePlaybackPositionCommandEvent else {
                return .commandFailed
            }
            guard let currentSong = self.currentSong else {
                return .commandFailed
            }
            
            let positionInMillis = positionEvent.positionTime
            let positionInPercents = (positionInMillis / Double(currentSong.duration)) * 100.0
            
            // print("values \(positionEvent.positionTime)")
            
            // TODO: don't switch to is playing false before seeking for this case, otherwise visual jump in the seekbar of the control center
            seek(position: positionInPercents)
            return .success
        }
        
        setupNotificationView()
        
    }
    
    private func setupNotificationView() {
       Task {
            self.nowPlayingInfo = [String: Any]()
            guard let song = self.currentSong else { return }
            
            self.nowPlayingInfo[MPMediaItemPropertyTitle] = song.title
            self.nowPlayingInfo[MPMediaItemPropertyArtist] = song.artist
            self.nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = song.duration
            
            if let bookmarkData = song.bookmarkData {
                if let artwork = await loadArtwork(id: song.id, bookmarkData: bookmarkData, cacheStrategy: .none) {
                    nowPlayingInfo[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(
                        boundsSize: artwork.size,
                        requestHandler: { (size) -> UIImage in artwork }
                    )
                }
            }
           
           MPNowPlayingInfoCenter.default().nowPlayingInfo = self.nowPlayingInfo
        }
    }
    
    private func updateNotificationView(isCurrentlyPlaying: Bool, positionInSeconds: Int32) {
        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = Float64(positionInSeconds)
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = isCurrentlyPlaying ? 1 : 0
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }
    
    
}
