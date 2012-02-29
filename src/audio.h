#ifndef AUDIO_H
#define AUDIO_H

#include <SDL_mixer.h>
#include "common.h"
#include "physics.h"
#include "uthash.h"

/* Control audio interface. */
int     audio_init();
void    audio_close();
void    audio_free_unused();
void    audio_adjust_volume();

/* Manage sounds. */
void    audio_play(const char *name, uintptr_t group, int volume, int loops, int fade_in,
                   uint *sound_id, int *channel);
void    audio_set_volume(int channel, uint sound_id, int volume);
void    audio_bind_volume(int ch, uint sound_id, Body *source, Body *listener,
                          float dist_maxvol, float dist_silence);
void    audio_fadeout(int channel, uint sound_id, int fade_time);
void    audio_stop(int channel, uint sound_id);

/* Manage music. */
void    audio_music_play(const char *name, int volume, int loops, int fade_in, double pos);
void    audio_music_set_volume(int volume);
void    audio_music_pause(void);
void    audio_music_resume(void);
void    audio_music_fadeout(int fade_time);

/* Manage sound groups. */
void    audio_pause_group(uintptr_t group);
void    audio_resume_group(uintptr_t group);
void    audio_set_group_volume(uintptr_t group, int volume);
void    audio_fadeout_group(uintptr_t group, int fade_time);
void    audio_stop_group(uintptr_t group);

#endif /* AUDIO_H */

