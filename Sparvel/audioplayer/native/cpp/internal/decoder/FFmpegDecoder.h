//
// Created by siduk on 08.05.2023.
//

#pragma once

#ifndef __STDC_FORMAT_MACROS
#define __STDC_FORMAT_MACROS
#endif

#include <inttypes.h>
#include <cstdio>
#include <string>
#include <memory>

extern "C" {
#include "FFmpeg/timestamp.h"
#include "FFmpeg/avformat.h"
#include "FFmpeg/display.h"
#include "FFmpeg/error.h"
#include "FFmpeg/avcodec.h"
}

// #include "Logger.h"
#include "../audiobuffer/CircularAudioBuffer.h"
// #include "Helpers.h"
// #include "../effects/pipeline/AudioEffectsPipeline.h"

constexpr double buffer_duration_seconds = 2.0;

class FFmpegDecoder {
private:
    const char *path;
    FILE *in_file;
    AVFormatContext *format_context;
    AVCodecContext *codec_context;
    const AVCodec *codec;
    AVFrame *frame;
    int audio_stream_index;
    std::atomic<bool> should_stop_execution = false;
    std::vector<float> frame_buffer;
    // std::unique_ptr<AudioEffectsPipeline> audioEffectsPipeline;

    static void print_error(const char *prefix, int error_code);

    int receive_and_handle(CircularAudioBuffer *output);

    void handle_frame(CircularAudioBuffer *output);

    static int find_audio_stream(const AVFormatContext *format_context);

    static void print_stream_information(const AVCodec *codec, const AVCodecContext *codec_context,
                                       int audio_stream_index);

    static float get_sample(const AVCodecContext *codec_context, const uint8_t *buffer, int sample_index);

    void drain_decoder(CircularAudioBuffer *output);

public:

    FFmpegDecoder(
        int &sample_rate,
        int &channel_count,
        const char *path,
        size_t &array_size
        // std::unique_ptr<AudioEffectsPipeline> audioEffectsPipeline
    );

    ~FFmpegDecoder();

    void decode_packet(CircularAudioBuffer *output_packet);

    void seek_to(int64_t timestamp_ms);

    void stop_execution();

};
