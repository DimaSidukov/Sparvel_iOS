//
//  AudioEngine.m
//  Sparvel
//
//  Created by Dmitriy Sidukov on 15.05.2026.
//

#import "NativeAudioEngine.h"
#import "internal/player/AudioPlayer.h"
#import "internal/player/PlaybackCallback.h"


class CppPlaybackCallback : public PlaybackCallback {
public:
    
    PositionBlock _positionBlock;
    StateBlock _stateBlock;
    InitializationBlock _initializationBlock;
    
    CppPlaybackCallback(PositionBlock positionBlock, StateBlock stateBlock, InitializationBlock initializationBlock) {
        _positionBlock = positionBlock;
        _stateBlock = stateBlock;
        _initializationBlock = initializationBlock;
    }
    
    void on_position_update(int64_t position, int force) override {
        _positionBlock(position, force);
        
    }
    virtual void on_state_update(int is_playing) override {
        _stateBlock(is_playing);
    }
    virtual void on_data_loaded(int success) override {
        _initializationBlock(success);
    }
};


@implementation NativeAudioEngine

- (id)initWithPosition:(PositionBlock)position
    state:(StateBlock)state
        initialization:(InitializationBlock)initialization {
    self = [super init];
    
    if (self) {
        _playbackCallback = new CppPlaybackCallback(position, state, initialization);
    }
    
    return self;
}

- (void)play:(NSURL*) url {
    NSString *path = url.path;

    const char *filePath = [[NSFileManager defaultManager] fileSystemRepresentationWithPath:path];
    
    if (_audioPlayer) {
        delete _audioPlayer;
        _audioPlayer = nullptr;
    }

    _audioPlayer = new AudioPlayer(filePath, _playbackCallback);
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

