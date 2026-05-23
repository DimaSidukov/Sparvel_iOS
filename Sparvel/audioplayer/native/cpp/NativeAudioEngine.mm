//
//  AudioEngine.m
//  Sparvel
//
//  Created by Dmitriy Sidukov on 15.05.2026.
//

#import "NativeAudioEngine.h"
#import "internal/player/AudioPlayer.h"

@implementation NativeAudioEngine

- (void)play:(NSURL*) url {
    NSString *path = url.path;

    const char *filePath = [[NSFileManager defaultManager] fileSystemRepresentationWithPath:path];

    _audioPlayer = new AudioPlayer(filePath, nullptr);
}

- (void)pause {
    _audioPlayer->pause();
}

- (void)seek:(int64_t) positionMs {
    _audioPlayer->seek(positionMs);
}

- (void)releasePlayer {
    _audioPlayer->releasePlayer();
}

@end

