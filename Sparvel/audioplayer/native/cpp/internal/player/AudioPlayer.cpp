//
//  AudioPlayer.m
//  Sparvel
//
//  Created by Dmitriy Sidukov on 15.05.2026.
//

#import "AudioPlayer.h"
#import "stdio.h"
#include <cstring>

int AudioPlayer::kOutputBus = 0;
int AudioPlayer::kEnableOutput = 1;

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
    int sampleRate;
    int channelCount;
    size_t arraySize;
    
    decoder = std::make_unique<FFmpegDecoder>(sampleRate, channelCount, file_path, arraySize);
    if (sampleRate == -1 || channelCount == -1) {
        printf("Failed to read data from the file");
        callback->on_data_loaded(-1);
        return;
    }
    channel_count = channelCount;
    
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
    
    audio_buffer = std::make_shared<CircularAudioBuffer>(arraySize);
    
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
    
    callback->on_data_loaded(status);
}

void AudioPlayer::decode() {
    decoder->decode_packet(audio_buffer.get());
}

OSStatus AudioPlayer::render(UInt32 inNumberFrames, AudioBufferList *ioData) {
    if (ioData == nullptr || ioData->mNumberBuffers == 0 || audio_buffer == nullptr) {
        return noErr;
    }
    
    AudioBuffer* outputBuffer = &ioData->mBuffers[0];
    auto outputBufferData = static_cast<float*>(outputBuffer->mData);
    UInt32 channels = static_cast<UInt32>(channel_count);
    
    UInt32 requestedSamples = inNumberFrames * channels;
    UInt32 requestedBytes = requestedSamples * static_cast<UInt32>(sizeof(float));
    size_t samplesRead = 0;
    if (outputBufferData != nullptr) {
        samplesRead = audio_buffer->read(outputBufferData, requestedSamples);
    }
    
    if (samplesRead < requestedSamples) {
        memset(outputBufferData + samplesRead, 0, requestedSamples - samplesRead * sizeof(float));
    }
    
    outputBuffer->mDataByteSize = requestedBytes;
    outputBuffer->mNumberChannels = channels;
    
    return noErr;
}
    
void AudioPlayer::stop() {
    status = AudioOutputUnitStop(audioUnit);
    if (status != 0) {
        printf("Failed to stop audio unit, exit with status %d\n", status);
        return;
    }
    audio_buffer.reset();
}

void AudioPlayer::pause() {
    // https://stackoverflow.com/questions/12055058/how-to-implement-pause-function-for-audio-units
//    fade out (~10ms) the AUs' output, feed the output silence after the fade
//    remember the position you stopped reading your input signal
//    reset the AUs before you resume
//    resume from the position you recorded above (here, a fade in of the input signal to the AUs would be also be good)
}

void AudioPlayer::seek(int64_t positionMs) {
    
}

void AudioPlayer::releasePlayer() {
    stop();
}
