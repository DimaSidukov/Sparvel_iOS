//
//  AudioPlayer.h
//  Sparvel
//
//  Created by Dmitriy Sidukov on 15.05.2026.
//

#include "inttypes.h"
#include <atomic>
#include <AudioUnit/AudioUnit.h>
#include "../decoder/FFmpegDecoder.h"
#include "PlaybackCallback.h"


enum class ResumeStrategy {
    PLAY_TO_PAUSE,
    PAUSE_TO_PLAY,
};

class AudioPlayer {
private:
    
    const char* filePath;
    PlaybackCallback* callback;
    std::unique_ptr<FFmpegDecoder> decoder;
    std::shared_ptr<CircularAudioBuffer> audioBuffer;
    std::thread decoding_thread;
    
    int channelCount = -1;
    int sampleRate = -1;
    int64_t fadeOutInSamples = 0;
    int64_t currentPositionInFrames = 0;
    int64_t currentFadeOutPosition = 0;
    
    int64_t previousCallbackPosition = 0;
    int64_t callbackStepInMs = 300;
    
    std::atomic<bool> isPlaying { false };
    std::atomic<bool> isToggleTransitionInProgress { false };
    ResumeStrategy resumeStrategy = ResumeStrategy::PLAY_TO_PAUSE;
    
    OSStatus status;
    AudioComponentInstance audioUnit;
    static int kOutputBus;
    static int kEnableOutput;
    static int64_t fadeOutLength;
    
    void init();
    void decode();
    void stop();
    
public:
    AudioPlayer(const char* filePath, PlaybackCallback* callback) : filePath(filePath), callback(callback) {
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
