//
//  Song.swift
//  Sparvel
//
//  Created by Dmitriy Sidukov on 03.05.2026.
//

internal import Foundation

// TODO: probably inherit Hashable and Identifiable?
class Song {
    var id: String
    var title: String
    var artist: String
    var duration: Int64
    var bookmarkData: Data?
    
    init(id: String, title: String, artist: String, duration: Int64, bookmarkData: Data? = nil) {
        self.id = id
        self.title = title
        self.artist = artist
        self.duration = duration
        self.bookmarkData = bookmarkData
    }
}

