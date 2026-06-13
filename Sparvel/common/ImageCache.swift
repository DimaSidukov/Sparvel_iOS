//
//  ImageCache.swift
//  Sparvel
//
//  Created by Dmitriy Sidukov on 07.05.2026.
//

internal import Foundation
internal import UIKit

enum CacheStrategy {
    case none
    case songThumbnail(CGFloat)
    case albumThumbnail(CGFloat)
}

final class ImageCache {
    
    static let shared = ImageCache()
    
    private let cache = NSCache<NSString, UIImage>()
    
    func image(for key: NSString, cacheStrategy: CacheStrategy) -> UIImage? {
        let keyAsString = key as String
        let strategyName = String(describing: cacheStrategy)
        return cache.object(forKey: (keyAsString + strategyName) as NSString)
    }
    
    func insert(_ image: UIImage, for key: NSString, cacheStrategy: CacheStrategy) {
        
        let keyAsString = key as String
        let strategyName = String(describing: cacheStrategy)
        let completeKey = (keyAsString + strategyName) as NSString
        
        switch (cacheStrategy) {
            
        case .none, .albumThumbnail:
            cache.setObject(image, forKey: completeKey, cost: image.calculateCost())
        case .songThumbnail(let scale):
            
            let options = [
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceThumbnailMaxPixelSize: 40 * scale
            ] as CFDictionary
            
            guard let imageData = image.pngData() else { return }
            guard let imageSource = CGImageSourceCreateWithData(imageData as NSData, nil) else { return }
            guard let cgImage = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, options) else { return }
            let resizedUIImage = UIImage(cgImage: cgImage)
            
            cache.setObject(
                resizedUIImage,
                forKey: completeKey,
                cost: resizedUIImage.calculateCost()
            )
        }
    }
}

fileprivate extension UIImage {
    func calculateCost() -> Int {
        guard let cgImage = cgImage else{ return  0 }
        return cgImage.bytesPerRow * cgImage.height
    }
}
