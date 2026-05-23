//
//  AudioEngine.h
//  Sparvel
//
//  Created by Dmitriy Sidukov on 15.05.2026.
//

#import <Foundation/Foundation.h>

#ifdef __cplusplus
class AudioPlayer;
#else
typedef struct AudioPlayer AudioPlayer;
#endif

@interface NativeAudioEngine : NSObject

@property (nonatomic, assign) AudioPlayer* audioPlayer;

- (void)play:(NSURL*) url;
- (void)pause;
- (void)seek:(int64_t) positionMs;
- (void)releasePlayer;

@end
