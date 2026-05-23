//
//  AudioEngine.m
//  Sparvel
//
//  Created by Dmitriy Sidukov on 15.05.2026.
//

#import "NativeAudioEngine.h"
#import "internal/player/AudioPlayer.h"

@implementation NativeAudioEngine

- (void)play:(NSString*) fileUrlPath {
    
    char* filePath = strdup([fileUrlPath UTF8String]);
    
    
    
    free(filePath);
}

@end

