//
//  LocalStorage.swift
//  Sparvel
//
//  Created by Dmitriy Sidukov on 07.05.2026.
//

import SwiftData

let modelContainer = try? ModelContainer(
    for: Song.self,
    configurations: ModelConfiguration(isStoredInMemoryOnly: false, allowsSave: true)
)
