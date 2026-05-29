//
//  AudioPlayer.h
//  Sparvel
//
//  Created by Dmitriy Sidukov on 15.05.2026.
//

#include "inttypes.h"
#import <AudioUnit/AudioUnit.h>
#import "../decoder/FFmpegDecoder.h"
#import "PlaybackCallback.h"

class AudioPlayer {
private:
    
    const char* file_path;
    PlaybackCallback* callback;
    std::unique_ptr<FFmpegDecoder> decoder;
    std::shared_ptr<CircularAudioBuffer> audio_buffer;
    std::thread decoding_thread;
    int channel_count = 0;
    
    OSStatus status;
    AudioComponentInstance audioUnit;
    static int kOutputBus;
    static int kEnableOutput;
    
    void init();
    void decode();
    void stop();
    
public:
    AudioPlayer(const char* file_path, PlaybackCallback* callback) : file_path(file_path), callback(callback) {
        init();
    }
    
    ~AudioPlayer() {
        stop();
    }
    
    void pause();
    void seek(int64_t positionMs);
    void releasePlayer();
    
    OSStatus render(UInt32 inNumberFrames, AudioBufferList *ioData);
};
