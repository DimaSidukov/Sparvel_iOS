//
//  LocalStorage.swift
//  Sparvel
//
//  Created by Dmitriy Sidukov on 07.05.2026.
//

internal import Foundation
import CoreData

class LocalStorage {
    
    private let coreDataStack = CoreDataStack.shared
    
    func saveSongs(songs: [Song]) {
        coreDataStack.saveSongs(songs: songs)
    }
    
    func loadSongs() -> [Song] {
        return coreDataStack.loadSongs()
    }
    
}


