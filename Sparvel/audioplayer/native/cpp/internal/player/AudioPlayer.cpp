//
//  AudioPlayer.m
//  Sparvel
//
//  Created by Dmitriy Sidukov on 15.05.2026.
//

#import "AudioPlayer.h"
#import "stdio.h"
#include <cstring>
#include "../helpers/Helpers.h"

int AudioPlayer::kOutputBus = 0;
int AudioPlayer::kEnableOutput = 1;
int64_t AudioPlayer::fadeOutLength = 10;

static OSStatus AuduioRenderPaybackCallback(void *inRefCon,
                                  AudioUnitRenderActionFlags *ioActionFlags,
                                  const AudioTimeStamp *inTimeStamp,
                                  UInt32 inBusNumber,
                                  UInt32 inNumberFrames,
                                  AudioBufferList *ioData) {
    auto *player = static_cast<AudioPlayer *>(inRefCon);
    if (player == nullptr) {
        return noErr;
    }
    return player->render(inNumberFrames, ioData);
}

void AudioPlayer::init() {
    
    // Prepare output properties
    AudioComponentDescription description;
    description.componentType = kAudioUnitType_Output;
    description.componentSubType = kAudioUnitSubType_RemoteIO;
    description.componentFlags = 0;
    description.componentFlagsMask = 0;
    description.componentManufacturer = kAudioUnitManufacturer_Apple;
    
    AudioComponent inputComponent = AudioComponentFindNext(nullptr, &description);
    
    status = AudioComponentInstanceNew(inputComponent, &audioUnit);
    if (status != 0) {
        printf("Error preparing output properties, exit with status %d\n", status);
        callback->on_data_loaded(status);
        return;
    }
    
    status = AudioUnitSetProperty(
                         audioUnit,
                         kAudioOutputUnitProperty_EnableIO,
                         kAudioUnitScope_Output,
                         kOutputBus,
                         &kEnableOutput,
                         sizeof(kEnableOutput));
    if (status != 0) {
        printf("Error enabling IO, exit with status %d\n", status);
        callback->on_data_loaded(status);
        return;
    }
    
    // Read file, extract metadata for playback
    size_t arraySize;
    
    decoder = std::make_unique<FFmpegDecoder>(sampleRate, channelCount, filePath, arraySize);
    if (sampleRate == -1 || channelCount == -1) {
        printf("Failed to read data from the file");
        callback->on_data_loaded(-1);
        return;
    }
    
    fadeOutInSamples = convert_millis_to_frames(fadeOutLength, sampleRate) * channelCount;
    
    AudioStreamBasicDescription audioFormat = {};
    audioFormat.mSampleRate = sampleRate;
    audioFormat.mFormatID =kAudioFormatLinearPCM;
    audioFormat.mFormatFlags = kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked;
    audioFormat.mFramesPerPacket = 1;
    audioFormat.mChannelsPerFrame = channelCount;
    audioFormat.mBitsPerChannel = 32;
    audioFormat.mBytesPerPacket = sizeof(float) * channelCount;
    audioFormat.mBytesPerFrame = sizeof(float) * channelCount;
    
    status = AudioUnitSetProperty(
                                  audioUnit,
                                  kAudioUnitProperty_StreamFormat,
                                  kAudioUnitScope_Input,
                                  kOutputBus,
                                  &audioFormat,
                                  sizeof(audioFormat));
    
    audioBuffer = std::make_shared<CircularAudioBuffer>(arraySize);
    
    if (status != 0) {
        printf("Failed to set audio format for output, exit with status %d\n", status);
        callback->on_data_loaded(status);
        return;
    }
    
    // Set callback for playback
    AURenderCallbackStruct callbackStruct;
    callbackStruct.inputProc = AuduioRenderPaybackCallback;
    callbackStruct.inputProcRefCon = this;
    // TODO: probably add AudioUnitAddRenderNotify for notification API
    status = AudioUnitSetProperty(audioUnit,
                                  kAudioUnitProperty_SetRenderCallback,
                                  kAudioUnitScope_Global,
                                  kOutputBus,
                                  &callbackStruct,
                                  sizeof(callbackStruct));
    
    decoding_thread = std::thread(&AudioPlayer::decode, this);
    
    // Initialize audio unit
    status = AudioUnitInitialize(audioUnit);
    if (status != 0) {
        printf("Failed to initialize audio unit, exit with status %d\n", status);
        callback->on_data_loaded(status);
        return;
    }
    
    status = AudioOutputUnitStart(audioUnit);
    if (status != 0) {
        printf("Failed to start audio unit, exit with status %d\n", status);
        callback->on_data_loaded(status);
        return;
    }
    
    isPlaying.store(true);
    callback->on_data_loaded(status);
    callback->on_state_update(isPlaying.load());
}

void AudioPlayer::decode() {
    decoder->decode_packet(audioBuffer.get());
}

OSStatus AudioPlayer::render(UInt32 inNumberFrames, AudioBufferList *ioData) {
    
    if (ioData == nullptr || ioData->mNumberBuffers == 0 || audioBuffer == nullptr) {
        return noErr;
    }
    
    if (!isPlaying.load() && !isToggleTransitionInProgress.load()) {
        for (UInt32 i = 0; i < ioData->mNumberBuffers; i++) {
            UInt32 channels = static_cast<UInt32>(channelCount);
            UInt32 requestedSamples = inNumberFrames * channels;
            UInt32 requestedBytes = requestedSamples * static_cast<UInt32>(sizeof(float));
            AudioBuffer* outputBuffer = &ioData->mBuffers[i];
            
            memset(outputBuffer->mData, 0, requestedBytes);
            outputBuffer->mDataByteSize = requestedBytes;
            outputBuffer->mNumberChannels = channels;
        }
        return noErr;
    }
    
    AudioBuffer* outputBuffer = &ioData->mBuffers[0];
    auto outputBufferData = static_cast<float*>(outputBuffer->mData);
    UInt32 channels = static_cast<UInt32>(channelCount);
    UInt32 requestedSamples = inNumberFrames * channels;
    UInt32 requestedBytes = requestedSamples * static_cast<UInt32>(sizeof(float));
    size_t samplesRead = 0;
    if (outputBufferData != nullptr) {
        samplesRead = audioBuffer->read(outputBufferData, requestedSamples);
    }
    
    if (isToggleTransitionInProgress.load()) {
        size_t transitionSamplesTotal =
            samplesRead > currentFadeOutPosition ?
            currentFadeOutPosition :
            samplesRead;
        for(size_t i = 0; i < transitionSamplesTotal; i++) {
            float multiplier = (float)(currentFadeOutPosition - i) / float(fadeOutInSamples);
            float actualMultiplier = resumeStrategy == ResumeStrategy::PLAY_TO_PAUSE ? multiplier : 1.0f - multiplier;
            for(UInt32 channel = 0; channel < channels; channel++) {
                outputBufferData[i * channels + channel] *= actualMultiplier;
            }
        }
        
        currentFadeOutPosition -= transitionSamplesTotal;
        if (currentFadeOutPosition < 0) {
            currentFadeOutPosition = 0;
        }
        
        if (transitionSamplesTotal < samplesRead && resumeStrategy == ResumeStrategy::PLAY_TO_PAUSE) {
            samplesRead = transitionSamplesTotal;
        }
        
        if (currentFadeOutPosition == 0) {
            isToggleTransitionInProgress.store(false);
        }
    }
    
    if (samplesRead < requestedSamples) {
        memset(outputBufferData + samplesRead, 0, (requestedSamples - samplesRead) * sizeof(float));
    }
    
    outputBuffer->mDataByteSize = requestedBytes;
    outputBuffer->mNumberChannels = channels;
    
    size_t readFrames = samplesRead / channels;
    currentPositionInFrames += readFrames;
    
    size_t currentPositionInMs = convert_frames_to_millis(currentPositionInFrames, sampleRate);
    if (currentPositionInMs - previousCallbackPosition > callbackStepInMs) {
        callback->on_position_update(currentPositionInMs, 0);
        previousCallbackPosition = currentPositionInMs;
    }
    
    return noErr;
}
    
void AudioPlayer::stop() {
    
    if (audioUnit) {
        status = AudioOutputUnitStop(audioUnit);
        AudioUnitUninitialize(audioUnit);
        AudioComponentInstanceDispose(audioUnit);
    }
    
    if (status != 0) {
        printf("Failed to stop audio unit, exit with status %d\n", status);
        return;
    }
    
    if (decoder) {
        decoder->stop_execution();
    }
    
    if (decoding_thread.joinable()) {
        decoding_thread.join();
    }
    
    decoder.reset();
    audioBuffer.reset();
    
    previousCallbackPosition = 0;
    callback->on_position_update(0, 0);
    currentPositionInFrames = 0;
}

void AudioPlayer::pause() {
    
    currentFadeOutPosition = fadeOutInSamples;
    
    bool currentIsPlaying = isPlaying.load();
    
    resumeStrategy = currentIsPlaying ? ResumeStrategy::PLAY_TO_PAUSE : ResumeStrategy::PAUSE_TO_PLAY;
    if (!currentIsPlaying) {
        AudioUnitReset(audioUnit, kAudioUnitScope_Global, 0);
    }
    
    while(isPlaying.compare_exchange_weak(currentIsPlaying, !currentIsPlaying)) { }
    callback->on_state_update(isPlaying.load());
    isToggleTransitionInProgress.store(true);
}

void AudioPlayer::seek(int64_t positionMs) {
    currentPositionInFrames = convert_millis_to_frames(positionMs, sampleRate);
    if (!decoder || !audioBuffer) {
        return;
    }
    
    decoder->stop_execution();
    if (decoding_thread.joinable()) {
        decoding_thread.join();
    }
    
    audioBuffer->reset();
    decoder->seek_to(positionMs);
    
    decoding_thread = std::thread(&AudioPlayer::decode, this);

    previousCallbackPosition = positionMs;
    callback->on_position_update(positionMs, 1);
}

void AudioPlayer::releasePlayer() {
    stop();
}
