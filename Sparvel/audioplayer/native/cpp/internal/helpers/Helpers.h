//
//  Helpers.h
//  Sparvel
//
//  Created by Dmitriy Sidukov on 01.06.2026.
//

#pragma once

#include "inttypes.h"

constexpr int64_t k_milliseconds_in_second = 1000;

constexpr UInt32 convert_frames_to_millis(const int64_t frames, const int sample_rate) {
    return static_cast<int64_t>((static_cast<double>(frames)/ sample_rate) * k_milliseconds_in_second);
}

constexpr int64_t convert_millis_to_frames(const int64_t millis, const int sample_rate) {
    return (millis * sample_rate) / k_milliseconds_in_second;
}
