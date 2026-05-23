//
// Created by siduk on 13.05.2023.
//

#include "FFmpegDecoder.h"
// TMP
//#include "../effects/pipeline/AudioEffectsPipeline.h"
//#include "../effects/pitchshifter/PitchShifterEffect.h"

void FFmpegDecoder::print_error(const char *prefix, int error_code) {
#ifdef NDEBUG
#else
    if (error_code != 0) {
        const size_t bufsize = 64;
        char buf[bufsize];

        if (av_strerror(error_code, buf, bufsize) != 0) {
            strcpy(buf, "UNKNOWN_ERROR");
        }
        printf("%s (%d: %s)\n", prefix, error_code, buf);
    }
#endif
}

/**
 * Find the first audio stream and returns its index. If there is no audio stream returns -1.
 */
int FFmpegDecoder::find_audio_stream(const AVFormatContext *format_context) {
    int computed_audio_stream_index = -1;
    for (size_t i = 0; i < format_context->nb_streams; ++i) {
        // Use the first audio stream we can find.
        // NOTE: There may be more than one, depending on the file.
        if (format_context->streams[i]->codecpar->codec_type == AVMEDIA_TYPE_AUDIO) {
            computed_audio_stream_index = static_cast<int>(i);
            break;
        }
    }
    return computed_audio_stream_index;
}

/*
 * Print information about the input file and the used codec.
 */
void FFmpegDecoder::print_stream_information(const AVCodec *codec, const AVCodecContext *codec_context, int audio_stream_index) {
    printf("Codec: %s\n", codec->long_name);
    if (codec->sample_fmts != nullptr) {
        printf("Supported sample formats: ");
        for (int i = 0; codec->sample_fmts[i] != -1; ++i) {
            printf("%s", av_get_sample_fmt_name(codec->sample_fmts[i]));
            if (codec->sample_fmts[i + 1] != -1) {
                printf(", ");
            }
        }
        printf("\n");
    }
    printf("---------\n");
    printf("Stream:        %7d\n", audio_stream_index);
    printf("Sample Format: %7s\n", av_get_sample_fmt_name(codec_context->sample_fmt));
    printf("Sample Rate:   %7d\n", codec_context->sample_rate);
    printf("Sample Size:   %7d\n", av_get_bytes_per_sample(codec_context->sample_fmt));
    printf("Channels:      %7d\n", codec_context->ch_layout.nb_channels);
    printf("Float Output:  %7s\n", av_sample_fmt_is_planar(codec_context->sample_fmt) ? "yes" : "no");
}

/**
 * Receive as many frames as available and handle them.
 */
int FFmpegDecoder::receive_and_handle(CircularAudioBuffer *output) {
    int err = 0;
    // Read the packets from the decoder.
    // NOTE: Each packet may generate more than one frame, depending on the codec.

    while ((err = avcodec_receive_frame(codec_context, frame)) == 0) {
        // Let's handle the frame in a function.
        handle_frame(output);
        // Free any buffers and reset the fields to default values.
        av_frame_unref(frame);
    }
    return err;
}

/**
 * Write the frame to an output file.
 */
void FFmpegDecoder::handle_frame(CircularAudioBuffer *output) {
    size_t frame_size = frame->nb_samples * codec_context->ch_layout.nb_channels;

    if (frame_buffer.size() < frame_size)
        frame_buffer.resize(frame_size);

    if (av_sample_fmt_is_planar(codec_context->sample_fmt)) {
        for (int s = 0; s < frame->nb_samples; ++s) {
            for (int c = 0; c < codec_context->ch_layout.nb_channels; ++c) {
                frame_buffer[s * codec_context->ch_layout.nb_channels + c] =
                        get_sample(codec_context, frame->extended_data[c], s);
            }
        }
    } else {
        for (int s = 0; s < frame->nb_samples; ++s) {
            for (int c = 0; c < codec_context->ch_layout.nb_channels; ++c) {
                frame_buffer[s * codec_context->ch_layout.nb_channels + c] =
                        get_sample(codec_context, frame->extended_data[0],
                                s * codec_context->ch_layout.nb_channels + c);
            }
        }
    }

    int bufferSize = static_cast<int>(frame_buffer.size());
    auto* outData = new float[bufferSize];
    memcpy(outData, frame_buffer.data(), bufferSize * sizeof(float));
//    audioEffectsPipeline->process(
//        frame_buffer.data(),
//        static_cast<int>(frame_buffer.size()),
//        outData
//    );

    while (!should_stop_execution && output->get_free_space() < frame_size) {
        std::this_thread::sleep_for(std::chrono::milliseconds(1));
    }

    output->write(outData, frame_size);
    delete[] outData;
}


float FFmpegDecoder::get_sample(const AVCodecContext *codec_context, const uint8_t *buffer, int sample_index) {
    int64_t val = 0;
    float ret = 0;
    int sampleSize = av_get_bytes_per_sample(codec_context->sample_fmt);

    switch (sampleSize) {
        case 1:
            // 8bit samples are always unsigned
            val = reinterpret_cast<const uint8_t *>(buffer)[sample_index];
            // make signed
            val -= 127;
            break;

        case 2:
            val = reinterpret_cast<const int16_t *>(buffer)[sample_index];
            break;

        case 4:
            val = reinterpret_cast<const int32_t *>(buffer)[sample_index];
            break;

        case 8:
            val = reinterpret_cast<const int64_t *>(buffer)[sample_index];
            break;

        default:
            printf("Invalid sample size %d.\n", sampleSize);
            return 0;
    }

    // Check which data type is in the sample.
    switch (codec_context->sample_fmt) {
        case AV_SAMPLE_FMT_U8:
        case AV_SAMPLE_FMT_S16:
        case AV_SAMPLE_FMT_S32:
        case AV_SAMPLE_FMT_U8P:
        case AV_SAMPLE_FMT_S16P:
        case AV_SAMPLE_FMT_S32P:
            // integer => Scale to [-1, 1] and convert to float.
            ret = static_cast<float>(val) / static_cast<float>((1 << (sampleSize * 8 - 1)) - 1);
            break;
        case AV_SAMPLE_FMT_FLT:
        case AV_SAMPLE_FMT_FLTP:
            // float => reinterpret
            ret = *reinterpret_cast<float *>(&val);
            break;
        case AV_SAMPLE_FMT_DBL:
        case AV_SAMPLE_FMT_DBLP:
            // double => reinterpret and then static cast down
            ret = static_cast<float>(*reinterpret_cast<double *>(&val));
            break;
        default:
            fprintf(stderr, "Invalid sample format %s.\n",
                    av_get_sample_fmt_name(codec_context->sample_fmt));
            return 0;
    }

    return ret;
}

void FFmpegDecoder::drain_decoder(CircularAudioBuffer *output) {
    int err;
    // Some codecs may buffer frames. Sending NULL activates drain-mode.
    if ((err = avcodec_send_packet(codec_context, nullptr)) == 0) {
        // Read the remaining packets from the decoder.
        err = receive_and_handle(output);
        if (err != AVERROR(EAGAIN) && err != AVERROR_EOF) {
            // Neither EAGAIN nor EOF => Something went wrong.
            print_error("Receive error.", err);
        }
    } else {
        // Something went wrong.
        print_error("Send error.", err);
    }
}

FFmpegDecoder::FFmpegDecoder(
    int &sample_rate,
    int &channel_count,
    const char *file_path,
    size_t &array_size
    // std::unique_ptr<AudioEffectsPipeline> pipeline
) : path(file_path) {
    in_file = fopen(file_path, "r");
    if (!in_file) {
        free(in_file);
        printf("Error opening file %s", file_path);
        return;
    }

    format_context = nullptr;
    int err;
    if ((err = avformat_open_input(&format_context, path, nullptr, nullptr)) != 0) {
        print_error("Error opening file: ", err);
        return;
    }

    avformat_find_stream_info(format_context, nullptr);

    // Try to find an audio stream.
    audio_stream_index = find_audio_stream(format_context);
    if (audio_stream_index == -1) {
        // No audio stream was found.
        printf("None of the available %d streams are audio streams.\n", format_context->nb_streams);
        avformat_close_input(&format_context);
        return;
    }

    // Find the correct decoder for the codec.
    codec = avcodec_find_decoder(
            format_context->streams[audio_stream_index]->codecpar->codec_id);
    if (codec == nullptr) {
        // Decoder not found.
        printf("Decoder not found. The codec is not supported.\n");
        avformat_close_input(&format_context);
        return;
    }

    // Initialize codec context for the decoder.
    codec_context = avcodec_alloc_context3(codec);
    codec_context->thread_count = 4;
    codec_context->thread_type = FF_THREAD_FRAME;
    if (codec_context == nullptr) {
        // Something went wrong. Cleaning up...
        avformat_close_input(&format_context);
        printf("Could not allocate a decoding context.\n");
        return;
    }

    // Fill the codecContext with the parameters of the codec used in the read file.
    if ((err = avcodec_parameters_to_context(codec_context,
                                             format_context->streams[audio_stream_index]->codecpar)) !=
        0) {
        // Something went wrong. Cleaning up...
        avcodec_free_context(&codec_context);
        avformat_close_input(&format_context);
        printf("Error setting codec context parameters. %d", err);
        return;
    }

    codec_context->request_sample_fmt = av_get_alt_sample_fmt(codec_context->sample_fmt, 0);

    // Initialize the decoder.
    if ((err = avcodec_open2(codec_context, codec, nullptr)) != 0) {
        print_error("Error initializing a decoder", err);
        avcodec_free_context(&codec_context);
        avformat_close_input(&format_context);
        return;
    }
    sample_rate = codec_context->sample_rate;
    channel_count = codec_context->ch_layout.nb_channels;

    // Print some interesting file information.
    print_stream_information(codec, codec_context, audio_stream_index);

    frame = nullptr;
    if ((frame = av_frame_alloc()) == nullptr) {
        avcodec_free_context(&codec_context);
        avformat_close_input(&format_context);
        return;
    }

    frame_buffer.resize(codec_context->frame_size * codec_context->ch_layout.nb_channels);
    array_size = static_cast<size_t>(buffer_duration_seconds * sample_rate * channel_count);
//    audioEffectsPipeline = std::move(pipeline);
//    audioEffectsPipeline->updateConfiguration(
//            codec_context->sample_rate
//    );
}

void FFmpegDecoder::decode_packet(CircularAudioBuffer *output_packet) {
    AVPacket *packet = av_packet_alloc();
    int err;

    while (!should_stop_execution) {
        // Read a packet
        err = av_read_frame(format_context, packet);
        if (err == AVERROR_EOF) {
            // EOF reached, optionally drain decoder
            drain_decoder(output_packet);
            break;
        } else if (err != 0) {
            print_error("Read error.", err);
            break;
        }

        // Skip non-audio packets
        if (packet->stream_index != audio_stream_index) {
            av_packet_unref(packet);
            continue;
        }

        // Send packet to decoder
        err = avcodec_send_packet(codec_context, packet);
        av_packet_unref(packet);
        if (err != 0 && err != AVERROR(EAGAIN)) {
            print_error("Send error.", err);
            break;
        }

        // Receive decoded frames and write to AudioBuffer
        err = receive_and_handle(output_packet);
        if (err != 0 && err != AVERROR(EAGAIN)) {
            print_error("Receive error.", err);
            break;
        }
    }

    av_packet_free(&packet);
}

void FFmpegDecoder::seek_to(int64_t timestamp_ms) {
    if (!format_context || !codec_context) return;

    should_stop_execution = false;

    // Convert milliseconds to stream timestamp
    int64_t timestamp = av_rescale_q(timestamp_ms,
            AVRational{1, 1000}, // milliseconds
            format_context->streams[audio_stream_index]->time_base);

    int ret = av_seek_frame(format_context, audio_stream_index, timestamp, AVSEEK_FLAG_BACKWARD);
    if (ret < 0) {
        printf("Seek failed to %lld ms", timestamp_ms);
        return;
    }

    // Flush decoder buffers
    avcodec_flush_buffers(codec_context);
}

FFmpegDecoder::~FFmpegDecoder() {
    // Free all data used by the frame.
    av_frame_free(&frame);

    // Close the context and free all data associated to it, but not the context itself.
    // avcodec_close(codec_context);

    // Free the context itself.
    avcodec_free_context(&codec_context);

    // We are done here. Close the input.
    avformat_close_input(&format_context);

    // Close the infile.
    fclose(in_file);
}

void FFmpegDecoder::stop_execution() {
    should_stop_execution = true;
}
