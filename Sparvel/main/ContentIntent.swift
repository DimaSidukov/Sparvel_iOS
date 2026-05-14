//
//  ContentIntent.swift
//  Sparvel
//
//  Created by Dmitriy Sidukov on 13.05.2026.
//

enum ContentIntent {
    case TogglePlayback
    case TogglePlayerSheetState
    case SelectSong(Song)
    case UpdateSliderPosition(Double)
}

