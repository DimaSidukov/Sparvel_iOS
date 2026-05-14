internal import Foundation
import Observation
internal import AVFoundation

@Observable
class AVAudioPlayerImpl: AudioPlayer {

    var isPlaying: Bool = false
    var currentPosition: Double = 0.0   // 0...100
    var currentSong: Song?

    private var player: AVPlayer? = nil
    private var progressObserver: Any? = nil
    private var stateObserver: NSKeyValueObservation? = nil

    private var currentTrackDurationMs: Double = 0.0

    static let MILLIS_IN_SECONDS: Double = 1000.0

    // MARK: - Play

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
            return
        }

        currentSong = song

        let item = AVPlayerItem(url: url)
        player = AVPlayer(playerItem: item)

        guard let asset = player?.currentItem?.asset else {
            return
        }

        Task {
            guard let durationSeconds = try? await asset.load(.duration).seconds else {
                return
            }

            currentTrackDurationMs = durationSeconds * Self.MILLIS_IN_SECONDS

            observePlayerState()
            player?.play()
        }
    }

    // MARK: - Controls

    func pause() {
        guard let player = player else { return }
        if player.timeControlStatus == .playing {
            player.pause()
        } else {
            player.play()
        }
    }

    func release() {
        player?.pause()

        if let progressObserver {
            player?.removeTimeObserver(progressObserver)
        }

        progressObserver = nil
        stateObserver = nil
        player = nil
    }

    // MARK: - Seek (0...100)

    func seek(position: Double) {
        guard currentTrackDurationMs > 0 else {
            return
        }

        let positionMs = (position / 100.0) * currentTrackDurationMs

        let time = CMTime(
            value: Int64(positionMs),
            timescale: Int32(Self.MILLIS_IN_SECONDS)
        )

        player?.seek(
            to: time,
            toleranceBefore: .zero,
            toleranceAfter: .zero
        )
    }

    // MARK: - Observation

    private func observePlayerState() {

        let interval = CMTime(
            seconds: 1,
            preferredTimescale: 10
        )

        progressObserver = player?.addPeriodicTimeObserver(
            forInterval: interval,
            queue: .main
        ) { [weak self] time in

            guard let self else { return }
            guard self.currentTrackDurationMs > 0 else { return }

            let currentMs = time.seconds * Self.MILLIS_IN_SECONDS

            let percent = (currentMs / self.currentTrackDurationMs) * 100.0

            self.currentPosition = min(max(percent, 0), 100)
        }

        stateObserver = player?.observe(\.timeControlStatus) { [weak self] player, _ in
            DispatchQueue.main.async {
                self?.isPlaying = (player.timeControlStatus == .playing)
            }
        }
    }
}
