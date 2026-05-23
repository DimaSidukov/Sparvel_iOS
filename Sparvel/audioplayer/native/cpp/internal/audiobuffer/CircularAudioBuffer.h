//
// Created by siduk on 18.06.2023.
//

#pragma once

#include <memory>
#include <vector>
#include <thread>

// TODO: remove from the project, use Apple's AudioBuffer
class CircularAudioBuffer {
public:
    explicit CircularAudioBuffer(size_t size): buffer(new float[size]), buffer_size(size) { }

    size_t write(const float* data, size_t num_samples);
    size_t read(float* data, size_t num_samples);
    void reset();

    bool is_empty() const;
    bool is_full() const;
    size_t get_free_space() const;
    size_t get_size() const;

    ~CircularAudioBuffer() {
        delete[] buffer;
    }

private:
    size_t buffer_size;
    float* buffer;
    std::atomic<size_t> write_index{0};
    std::atomic<size_t> read_index{0};
};
