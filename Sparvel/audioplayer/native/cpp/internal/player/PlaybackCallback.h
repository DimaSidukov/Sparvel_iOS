//
//  PlaybackCallback.h
//  Sparvel
//
//  Created by Dmitriy Sidukov on 29.05.2026.
//

struct PlaybackCallback {
public:
    virtual void on_position_update(int64_t position, int force) = 0;
    virtual void on_state_update(int is_playing) = 0;
    virtual void on_data_loaded(int success) = 0;
};
