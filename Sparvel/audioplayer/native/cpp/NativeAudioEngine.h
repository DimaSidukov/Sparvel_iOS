//
//  AudioEngine.h
//  Sparvel
//
//  Created by Dmitriy Sidukov on 15.05.2026.
//

#import <Foundation/Foundation.h>

#ifdef __cplusplus
class AudioPlayer;
class PlaybackCallback;
#else
typedef struct AudioPlayer AudioPlayer;
typedef struct PlaybackCallback PlaybackCallback;
#endif

typedef void (^PositionBlock) (int64_t position, int force);
typedef void (^StateBlock) (int is_playing);
typedef void (^InitializationBlock) (int success);


@interface NativeAudioEngine : NSObject

@property (nonatomic, assign) AudioPlayer* audioPlayer;
@property (nonatomic, assign) PlaybackCallback* playbackCallback;

- (id)initWithPosition:(PositionBlock)position
    state:(StateBlock)state
    initialization:(InitializationBlock)initialization;
- (void)play:(NSURL*) url;
- (void)pause;
- (void)seek:(int64_t) positionMs;
- (void)releasePlayer;

@end
