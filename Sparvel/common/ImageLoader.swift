//
//  ImageLoader.swift
//  Sparvel
//
//  Created by Dmitriy Sidukov on 08.05.2026.
//

internal import Foundation
internal import UIKit
internal import AVFoundation

func loadArtwork(bookmarkData: Data) async -> UIImage? {
    
    let imageCache = ImageCache.shared
    let currentDataImage = imageCache.image(for: bookmarkData)
    if currentDataImage  != nil {
        return currentDataImage
    }
    
    var isStale = true
    
    guard let url = try? URL(
        resolvingBookmarkData: bookmarkData,
        options: [],
        relativeTo: nil,
        bookmarkDataIsStale: &isStale
    ) else {
        return nil
    }
    
    let asset = AVURLAsset(url: url)
    
    let metadata = try? await asset.load(.commonMetadata)
    
    let items = metadata.flatMap { item in
        AVMetadataItem.metadataItems(
            from: item,
            filteredByIdentifier: .commonIdentifierArtwork
        )
    }
    
    if let item = items?.first {
        if let data = try? await item.load(.dataValue) {
            if let image = UIImage(data: data) {
                imageCache.insert(image, for: bookmarkData)
                return image
            }
        }
    }
    
    let formats = (try? await asset.load(.availableMetadataFormats)) ?? []
    
    for format in formats {
        if let metadata = try? await asset.loadMetadata(for: format) {
            for item in metadata {
                if let commonKey = item.commonKey {
                    if commonKey.rawValue == "artwork" {
                        if let keyValue = try? await item.load(.value),
                           let keyedArtwork = (keyValue as? Data) {
                            if let image = UIImage(data: keyedArtwork) {
                                imageCache.insert(image, for: bookmarkData)
                                return image
                            }
                        }
                    }
                }
            }
        }
    }
    
    return nil
}
