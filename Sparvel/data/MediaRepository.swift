//
//  MediaRepository.swift
//  Sparvel
//
//  Created by Dmitriy Sidukov on 03.05.2026.
//

internal import UIKit
internal import UniformTypeIdentifiers
internal import AVFoundation
internal import Foundation
import SwiftData

@Observable
class MediaRepository {
    
    var state: MediaState = .Idle
    
    init() {
        querySongs()
    }
    
    enum MediaState {
        case Loaded([Song])
        case Error
        case Idle
    }
    
    func addMusicFiles(urls: [URL]) async {
        if urls.count == 1 && urls.first!.hasDirectoryPath {
            await loadSongsFromDirectory(url: urls.first!)
        } else {
            await loadSongsFromList(urls: urls)
        }
    }
    
    private func querySongs() {
        guard let context = modelContainer?.mainContext else {
            return
        }
        if let songs = try? context.fetch(FetchDescriptor<Song>()) {
            if !songs.isEmpty {
                state = MediaState.Loaded(songs)
            }
        }
    }
    
    private func loadSongsFromDirectory(url: URL) async {
        let fileManager = FileManager.default
        
        guard url.startAccessingSecurityScopedResource() else {
            state = .Error
            return
        }
        
        defer {
            url.stopAccessingSecurityScopedResource()
        }
        
        guard let fileUrls = try? fileManager.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.contentTypeKey],
            options: [.skipsHiddenFiles]
        ) else {
            state = .Error
            return
        }
        
        await loadSongsFromList(urls: fileUrls)
    }
    
    private func loadSongsFromList(urls: [URL]) async {
        
        let audioUrls = urls.filter { url in
            let ext = url.pathExtension.lowercased()
            return Self.ALL_AUDIO_EXTENSIONS.contains(ext)
        }
        
        var songs: [Song] = []
        
        // TODO: look how to handle isDataStale
        for url in audioUrls {
            
            let asset = AVURLAsset(url: url)
            let metadata = try? await asset.load(.commonMetadata)
        
            // ID
            let id = url.standardizedFileURL.path
            
            // TITLE
            var isDefaultTitle = true
            var title = url.deletingPathExtension().lastPathComponent
            
            if let meta = metadata {
                let items = AVMetadataItem.metadataItems(
                    from: meta,
                    filteredByIdentifier: .commonIdentifierTitle
                )
                
                if let value = try? await items.first?.load(.stringValue) {
                    title = value
                    isDefaultTitle = false
                }
            }
            
            // ARTIST
            var isDefaultArtist = true
            var artist = "Unknown artist"
            
            if let meta = metadata {
                let items = AVMetadataItem.metadataItems(
                    from: meta,
                    filteredByIdentifier: .commonIdentifierArtist
                )
                
                if let value = try? await items.first?.load(.stringValue) {
                    artist = value
                    isDefaultArtist = false
                }
            }
            
            // DURATION
            var duration: Int64 = 0
            
            if let d = try? await asset.load(.duration) {
                duration = Int64(CMTimeGetSeconds(d))
            } else if let track = try? await asset.loadTracks(withMediaType: .audio).first {
                if let timeRangeDuration = try? await track.load(.timeRange) {
                    duration = Int64(CMTimeGetSeconds(timeRangeDuration.duration))
                }
            }
            
            // BOOKMARK
            let bookmarkData = try? url.bookmarkData(
                options: [],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            
            if isDefaultTitle || isDefaultArtist {
                let formats = (try? await asset.load(.availableMetadataFormats)) ?? []
                    
                for format in formats {
                    if let metadata = try? await asset.loadMetadata(for: format) {
                        for item in metadata {
                            if let commonKey = item.commonKey {
                                if commonKey.rawValue == "title" && isDefaultTitle {
                                    if let keyValue = try? await item.load(.value),
                                       let keyedTitle = (keyValue as? String) {
                                        artist = keyedTitle
                                    }
                                }
                                if commonKey.rawValue == "artist" && isDefaultArtist {
                                    if let keyValue = try? await item.load(.value),
                                       let keyedArtist = (keyValue as? String) {
                                        artist = keyedArtist
                                    }
                                }
                            }
                        }
                    }
                }
            }
            
            songs.append(
                Song(
                    id: id,
                    title: title,
                    artist: artist,
                    duration: duration,
                    bookmarkData: bookmarkData
                )
            )
        }
        
        if songs.isEmpty {
            state = .Error
        } else {
            saveSongs(songs: songs)
            querySongs()
        }
    }
    
    private func saveSongs(songs: [Song]) {
        guard let context = modelContainer?.mainContext else {
            return
        }
        for song in songs {
            context.insert(song)
        }
        try? context.save()
    }
    
    static let LOSSY_AUDIO_EXTENSIONS: Set<String> = [
        // MP3
        "mp3",
        
        // AAC
        "aac",
        "m4a",
        
        // OGG / Opus
        "ogg",
        "opus",
        
        // WMA
        "wma",
        "wax",
        "asf",
        
        // AMR
        "amr",
        "3gp",
        "3gpp",
        
        // MP2
        "mp2",
        "m2a"
    ]
    
    static let MP4_AUDIO_EXTENSIONS: Set<String> = [
        "mp4",
        "m4a"
    ]
    
    static let LOSSLESS_AUDIO_EXTENSIONS: Set<String> = [
        // FLAC
        "flac",
        
        // WAV
        "wav",
        
        // AIFF
        "aiff",
        "aif",
        "aifc"
    ]
    
    static let ALL_AUDIO_EXTENSIONS: Set<String> =
    LOSSY_AUDIO_EXTENSIONS
        .union(LOSSLESS_AUDIO_EXTENSIONS)
        .union(MP4_AUDIO_EXTENSIONS)
    
}
