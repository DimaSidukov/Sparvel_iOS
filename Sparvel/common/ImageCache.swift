//
//  ImageCache.swift
//  Sparvel
//
//  Created by Dmitriy Sidukov on 07.05.2026.
//

internal import Foundation
internal import UIKit

final class ImageCache {
    
    static let shared = ImageCache()
    
    private let cache = NSCache<NSData, UIImage>()
    
    private init() {}
    
    func image(for key: Data) -> UIImage? {
        cache.object(forKey: key as NSData)
    }
    
    func insert(_ image: UIImage, for key: Data) {
        cache.setObject(image, forKey: key as NSData)
    }
}
