#ifndef AUDIO_H
#define AUDIO_H

#include <SDL_mixer.h>
#include "common.h"
#include "physics.h"
#include "uthash.h"

/* Determines how long unused sounds stay in memory. */
#define SOUND_HISTORY   3

typedef struct {
        Mix_Chunk       *sample;
        char            name[100];      /* name = hash key. */
        int             usage;          /* Determines how long ago sound was last used. */
        UT_hash_handle  hh;             /* Makes this struct hashable. */
} Sound;

Sound   *sound_lookup_or_create(const char *name);
void     sound_free_all();
void     sound_free_unused();

int     audio_init();
void    audio_close();
void    audio_adjust_volume();

void    audio_play(Sound *snd, uintptr_t group, int volume, int loops, int fade_in,
                   uint *sound_id, int *channel);
void    audio_set_volume(int channel, uint sound_id, int volume);
void    audio_bind_volume(int ch, uint sound_id, Body *source, Body *listener,
                          float dist_maxvol, float dist_silence);
void    audio_fadeout(int channel, uint sound_id, int fade_time);
void    audio_stop(int channel, uint sound_id);

/* Manage sound groups. */
void    audio_pause_group(uintptr_t group);
void    audio_resume_group(uintptr_t group);
void    audio_set_group_volume(uintptr_t group, int volume);
void    audio_fadeout_group(uintptr_t group, int fade_time);
void    audio_stop_group(uintptr_t group);

#endif /* AUDIO_H */

