//
//  SongsIntent.swift
//  Sparvel
//
//  Created by Dmitriy Sidukov on 03.05.2026.
//

internal import Foundation

enum SongsIntent {
    case LoadSongs([URL])
    case RequestErrorState
}
