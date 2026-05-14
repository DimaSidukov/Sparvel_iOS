//
//  SongsViewState.swift
//  Sparvel
//
//  Created by Dmitriy Sidukov on 03.05.2026.
//

enum SongsViewState {
    case Loading
    case NoData
    case Data(LoadedSongsViewState)
    case Error(String)
}

struct LoadedSongsViewState {
    let songs: Array<Song>
}
