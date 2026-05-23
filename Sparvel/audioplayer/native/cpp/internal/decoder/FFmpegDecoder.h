//
// Created by siduk on 08.05.2023.
//

#pragma once

#include <cstdio>
#include <string>
#include <memory>
#include "ffmpeg_headers_wrapper.h"
#include "Logger.h"
#include "audiobuffer/AudioBuffer.h"
#include "Helpers.h"
#include "../effects/pipeline/AudioEffectsPipeline.h"

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
    std::unique_ptr<AudioEffectsPipeline> audioEffectsPipeline;

    static void print_error(const char *prefix, int error_code);

    int receive_and_handle(AudioBuffer *output);

    void handle_frame(AudioBuffer *output);

    static int find_audio_stream(const AVFormatContext *format_context);

    static void print_stream_information(const AVCodec *codec, const AVCodecContext *codec_context,
                                       int audio_stream_index);

    static float get_sample(const AVCodecContext *codec_context, const uint8_t *buffer, int sample_index);

    void drain_decoder(AudioBuffer *output);

public:

    FFmpegDecoder(
        int &sample_rate,
        int &channel_count,
        const char *path,
        size_t &array_size,
        std::unique_ptr<AudioEffectsPipeline> audioEffectsPipeline
    );

    ~FFmpegDecoder();

    void decode_packet(AudioBuffer *output_packet);

    void seek_to(int64_t timestamp_ms);

    void stop_execution();

};
