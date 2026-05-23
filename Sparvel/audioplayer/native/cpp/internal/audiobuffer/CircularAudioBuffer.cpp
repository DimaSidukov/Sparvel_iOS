//
// Created by siduk on 18.06.2023.
//

#include "CircularAudioBuffer.h"

size_t CircularAudioBuffer::write(const float *data, size_t num_samples) {
    size_t written = 0;
    size_t current_write = write_index.load(std::memory_order_relaxed);
    size_t current_read = read_index.load(std::memory_order_acquire);

    while (written < num_samples) {
        size_t new_write = (current_write + 1) % buffer_size;
        if (new_write == current_read) {
            break;
        }
        buffer[current_write] = data[written++];
        current_write = new_write;
    }
    write_index.store(current_write, std::memory_order_release);
    return written;
}

size_t CircularAudioBuffer::read(float *data, size_t num_samples) {
    size_t read = 0;
    size_t current_read = read_index.load(std::memory_order_relaxed);
    size_t current_write = write_index.load(std::memory_order_acquire);

    while (read < num_samples) {
        if (current_read == current_write) {
            break;
        }
        data[read++] = buffer[current_read];
        current_read = (current_read + 1) % buffer_size;
    }
    read_index.store(current_read, std::memory_order_release);
    return read;
}

size_t CircularAudioBuffer::get_free_space() const {
    size_t current_write = write_index.load(std::memory_order_acquire);
    size_t current_read = read_index.load(std::memory_order_acquire);
    if (current_write >= current_read) {
        return buffer_size - (current_write - current_read) - 1;
    }
    return current_read - current_write - 1;
}

void CircularAudioBuffer::reset() {
    read_index.store(0, std::memory_order_release);
    write_index.store(0, std::memory_order_release);
}

bool CircularAudioBuffer::is_empty() const {
    return read_index.load(std::memory_order_acquire) == write_index.load(std::memory_order_acquire);
}

bool CircularAudioBuffer::is_full() const {
    size_t next_write = (write_index.load(std::memory_order_acquire) + 1) % buffer_size;
    return next_write == read_index.load(std::memory_order_acquire);
}

size_t CircularAudioBuffer::get_size() const {
    return buffer_size;
}
