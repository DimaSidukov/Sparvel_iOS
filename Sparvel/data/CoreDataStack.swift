//
//  CoreDataStack.swift
//  Sparvel
//
//  Created by Dmitriy Sidukov on 28.05.2026.
//
import CoreData
internal import Foundation

class CoreDataStack {
    
    
    static let shared = CoreDataStack()
    
    lazy private var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "SongModel")
        
        container.loadPersistentStores { _, error in
            container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
            if let error {
                // TODO: replace with error message or smth
                fatalError("Failed to load persistent stores: \(error.localizedDescription)")
            }
            
        }
        
        return container
    }()
    
    private init() {
        
    }
    
    func saveSongs(songs: [Song]) {
        for song in songs {
            let songModel = SongModel(context: persistentContainer.viewContext)
            song.toModel(modelObject: songModel)
        }
        do {
            try persistentContainer.viewContext.save()
        } catch {
            print("Failed to save: \(error.localizedDescription)")
        }
    }
    
    func loadSongs() -> [Song] {
        let request = SongModel.fetchRequest()
        
        do {
            let songModels = try persistentContainer.viewContext.fetch(request)
            return songModels.map { $0.toSong() }
        } catch {
            print("Failed to fetch songs: \(error.localizedDescription)")
            return []
        }
    }
    
}

fileprivate extension Song {
    func toModel(modelObject: SongModel) {
        modelObject.id = self.id
        modelObject.artist = self.artist
        modelObject.title = self.title
        modelObject.duration = self.duration
        modelObject.bookmarkData = self.bookmarkData
    }
}

fileprivate extension SongModel {
    func toSong() -> Song {
        return Song(
            id: self.id ?? "",
            title: self.title ?? "",
            artist: self.artist ?? "",
            duration: self.duration,
            bookmarkData: self.bookmarkData
        )
    }
}
