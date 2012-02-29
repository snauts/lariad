#include <assert.h>
#include <math.h>
#include <SDL.h>
#include <SDL_mixer.h>
#include "audio.h"
#include "config.h"
#include "log.h"
#include "mem.h"
#include "physics.h"
#include "uthash.h"

static mem_pool mp_sound, mp_music;

/* Determines how long unused sounds stay in memory. */
#define SOUND_HISTORY   3
#define MUSIC_HISTORY   5

typedef struct {
        Mix_Chunk       *sample;
        char            name[100];      /* name = hash key. */
        int             usage;          /* Determines how long ago sound was last used. */
        UT_hash_handle  hh;             /* Makes this struct hashable. */
} Sound;

typedef struct {
        Mix_Music	*mix_music;
        char		name[100];
        int		usage;
        UT_hash_handle	hh;
} Music;

static Sound    *sound_hash;    /* Keep recently used sounds samples here. */
static Music    *music_hash;    /* Keep recently used music here. */

static int      have_audio;     /* True if audio init was successful. */

/* Output audio frequency (samples/sec) and chunksize (bytes/sample). */
static int      frequency;
static int      chunksize;

static uint     sound_id_gen;   /* Generate sound IDs incrementally. */
static int      num_channels;   /* Number of sound mixing channels. */

/*
 * Store info about sounds that are currently playing on mixer channels.
 *
 * The sound ID is  used here because sounds that user scripts reference may
 * have finished playing. So we want to make sure that we're not, for instance,
 * changing the volume of some other sound which just happens to be playing on
 * the same channel as the one before it whose volume we intended to change.
 *
 * If [snd] pointer is NULL, then that particual channel is inactive (nothing is
 * playing on it).
 */
static struct {
        Sound   *snd;           /* Sound currently playing on this channel. */
        uintptr_t group;        /* Group number is used to manipulate a bunch of
                                   sounds together as a group.*/
        uint    sound_id;       /* Scripts reference sounds by their IDs. */
        uint    callback_id;    /* Function to call when sound stops playing. */
        int     forever;        /* True if channel will never stop playing. */
        
        uint32_t start_time;    /* When channel playback was started. */
        uint32_t duration;      /* Sound duration in ms. */
        
        Body    *source;        /* Body that is producing the sound. */
        Body    *listener;      /* Body that "hears" the sound. */
        float   dist_maxvol;    /* Play sound at max volume when listener is this close to source. */
        float   dist_silence;   /* Volume drops off to zero when listener is this far from source. */
} channels[16];

/*
 * Look up sound object by name in the global hash. If it's not there,
 * create a new sound.
 *
 * name         Sound filename.
 */
static Sound *
sound_lookup_or_create(const char *name)
{
        /* See if structure with this name already exists. */
        Sound *snd;
        HASH_FIND_STR(sound_hash, name, snd);
        if (snd != NULL) {
                /* Reset usage counter and return sound. */
                snd->usage = SOUND_HISTORY;
                return snd;
        }
        
        /* A new sound. */
        snd = mp_alloc(&mp_sound);
        memset(snd, 0, sizeof(*snd));
        assert(strlen(name) < sizeof(snd->name));
        strcpy(snd->name, name);
        
        log_msg("Loading `%s` into sound memory.", name);
        snd->sample = Mix_LoadWAV(name);
        if (snd->sample == NULL)
                fatal_error("Could not load sound: %s.", Mix_GetError());
        
        /* Mark as recently used. */
        snd->usage = SOUND_HISTORY;
        
        /* Add to global hash which is indexed by name. */
        HASH_ADD_STR(sound_hash, name, snd);
        return snd;
}

/*
 * Look up music object by name in the global hash. If it's not there,
 * create new music.
 *
 * name         Music filename.
 */
static Music *
music_lookup_or_create(const char *name)
{
        /* See if structure with this name already exists. */
        Music *music;
        HASH_FIND_STR(music_hash, name, music);
        if (music != NULL) {
                /* Reset usage counter and return music. */
                music->usage = MUSIC_HISTORY;
                return music;
        }
        
        /* New music. */
        music = mp_alloc(&mp_music);
        memset(music, 0, sizeof(*music));
        assert(strlen(name) < sizeof(music->name));
        strcpy(music->name, name);
        
        log_msg("Loading `%s` into music memory.", name);
        music->mix_music = Mix_LoadMUS(name);
        if (music->mix_music == NULL)
                fatal_error("Could not load music: %s.", Mix_GetError());
        
        /* Mark as recently used. */
        music->usage = MUSIC_HISTORY;
        
        /* Add to global hash which is indexed by name. */
        HASH_ADD_STR(music_hash, name, music);
        return music;
}

/*
 * Free resources held within Sound structure, then free the structure memory
 * itself.
 */
static void
sound_free(Sound *snd)
{
        log_msg("Deleting sound `%s`.", snd->name);
        Mix_FreeChunk(snd->sample);
        memset(snd, 0, sizeof(*snd));

        mp_free(&mp_sound, snd);
}

/*
 * Free resources held within Music structure, then free the structure memory
 * itself.
 */
static void
music_free(Music *music)
{
        log_msg("Deleting music `%s`.", music->name);
        Mix_FreeMusic(music->mix_music);
        memset(music, 0, sizeof(*music));
        
        mp_free(&mp_music, music);
}

/*
 * Free memory of those sounds and music that have not been used in a while.
 */
void
audio_free_unused()
{
        Sound *snd, *snd_tmp;
        HASH_ITER(hh, sound_hash, snd, snd_tmp) {
                if (--snd->usage < 1) {
                        HASH_DEL(sound_hash, snd);
                        sound_free(snd);
                }
        }
        
        Music *music, *music_tmp;
        HASH_ITER(hh, music_hash, music, music_tmp) {
                if (--music->usage < 1) {
                        HASH_DEL(music_hash, music);
                        music_free(music);
                }
        }
}

void
audio_pause_group(uintptr_t group)
{
        if (!have_audio)
                return;
        
        if (group == 0) {
                /* Pause all channels. */
                Mix_Pause(-1);
                return;
        }
        
        /* Pause active channels that belong to group. */
        for (int i = 0; i < num_channels; i++) {
                if (channels[i].snd != NULL && channels[i].group == group)
                        Mix_Pause(i);
        }
}

void
audio_resume_group(uintptr_t group)
{
        if (!have_audio)
                return;
        if (group == 0) {
                /* Resume all channels. */
                Mix_Resume(-1);
                return;
        }
        
        /* Resume active channels that belong to chosen group. */
        for (int i = 0; i < num_channels; i++) {
                if (channels[i].snd != NULL && channels[i].group == group)
                        Mix_Resume(i);
        }
}

void
audio_play(const char *name, uintptr_t group, int volume, int loops, int fade_in,
           uint *sound_id, int *channel)
{
        assert(have_audio);
        assert(name && *name && fade_in >= 0 && loops >= -1);
        assert(sound_id != NULL && channel != NULL);
        
        /* Load sound. */
        Sound *snd = sound_lookup_or_create(name);
        
        /* Present time. */
        uint32_t now = SDL_GetTicks();
        
        /* Find a free channel. */
        int ch = -1;
        for (int i = 0; i < num_channels; i++) {
                if (channels[i].snd == NULL) {
                        ch = i;
                        break;
                }
        }
        if (ch == -1) {
                /*
                 * No free channels were found. Find a channel which has the
                 * same sound playing on it, and (in case there are multiple)
                 * has the least amount of time left for playback.
                 */
                int oldest_ch = -1;
                int least_timeleft;
                for (int i = 0; i < num_channels; i++) {
                        if (channels[i].snd != snd || channels[i].forever)
                                continue;
                        
                        uint32_t start_time = channels[i].start_time;
                        uint32_t duration = channels[i].duration;
                        int timeleft = (start_time + duration) - now;
                        if (oldest_ch == -1 || timeleft < least_timeleft) {
                                oldest_ch = i;
                                least_timeleft = timeleft;
                        }
                }
                if (oldest_ch != -1) {
                        ch = oldest_ch;
                        Mix_HaltChannel(ch);
                } else {
                        /*
                         * Still no luck.. kill the first channel that's not
                         * looping forever.
                         */
                        for (int i = 0; i < num_channels; i++) {
                                if (!channels[i].forever) {
                                        Mix_HaltChannel(i);
                                        ch = i;
                                        break;
                                }
                        }
                        if (ch == -1)
                                fatal_error("Out of audio channels. Please "
                                            "increase number of mixer channels "
                                            "in configuration file.");
                }
        }
        
        /* Set requested volume. */
        Mix_Volume(ch, volume);

        int rc = (fade_in > 0) ?
            Mix_FadeInChannelTimed(ch, snd->sample, loops, fade_in, -1) :
            Mix_PlayChannelTimed(ch, snd->sample, loops, -1);
        if (rc == -1)
                fatal_error("Playing sound failed: %s.", Mix_GetError());
        assert(rc == ch);
                
        /* Store sound data in channel array. */
        assert(!channels[ch].snd && !channels[ch].source &&
               !channels[ch].listener && !channels[ch].start_time);
        channels[ch].snd = snd;
        channels[ch].sound_id = ++sound_id_gen ? sound_id_gen : ++sound_id_gen;
        channels[ch].group = group;
        channels[ch].start_time = now;
        channels[ch].duration = 1000 * snd->sample->alen / chunksize / frequency;
        channels[ch].callback_id = 0;   /* No callback yet. */
        channels[ch].forever = (loops == -1);
        
        /* Return sound ID and channel. */
        *sound_id = channels[ch].sound_id;
        *channel = ch;
        assert(*sound_id);
        return;
}

static void
calculate_bound_volume(int ch)
{
        Body *source = channels[ch].source;
        Body *listener = channels[ch].listener;
        
        /*
         * If objtype member no longer says that it's a Body, assume the
         * body was destroyed and halt the channel.
         */
        if (source->objtype != OBJTYPE_BODY || listener->objtype != OBJTYPE_BODY) {
                Mix_HaltChannel(ch);
                return;
        }
        
        /* Distance from source to listener. */
        vect_f pos_diff = {
                listener->pos.x - source->pos.x,
                listener->pos.y - source->pos.y
        };
        float dist = sqrtf((pos_diff.x * pos_diff.x) + (pos_diff.y * pos_diff.y));
        
        /* See if we're within max volume distance. */
        float dist_maxvol = channels[ch].dist_maxvol;
        if (dist <= dist_maxvol) {
                Mix_Volume(ch, MIX_MAX_VOLUME);
                return;
        }
        
        /* See if we're further than silence distance. */
        float dist_silence = channels[ch].dist_silence;
        if (dist >= dist_silence) {
                Mix_Volume(ch, 0);
                return;
        }
        
        /* Linear volume calculation. */
        float volume = 1.0 - (dist - dist_maxvol) / (dist_silence - dist_maxvol);
        assert(volume >= 0.0 && volume <= 1.0);
        Mix_Volume(ch, volume * MIX_MAX_VOLUME);
}

/*
 * Bind channel volume to two bodies. Volume is then a function of the distance
 * between these two bodies.
 */
void
audio_bind_volume(int ch, uint sound_id, Body *source, Body *listener,
                  float dist_maxvol, float dist_silence)
{
        assert(have_audio);
        assert(ch >= 0 && ch < num_channels && sound_id > 0);
        assert(source && listener && dist_maxvol >= 0.0);
        assert(dist_silence > dist_maxvol);
        
        /* If sound has finished or sound IDs do not match, ignore. */
        if (channels[ch].snd == NULL || channels[ch].sound_id != sound_id)
                return;
        
        channels[ch].source = source;
        channels[ch].listener = listener;
        channels[ch].dist_maxvol = dist_maxvol;
        channels[ch].dist_silence = dist_silence;
        
        /* Start off with the correct volume. */
        calculate_bound_volume(ch);
}

/*
 * Adjust volume on those channels that are bound to bodies.
 */
void
audio_adjust_volume()
{
        for (int i = 0; i < num_channels; i++) {
                if (channels[i].snd == NULL || channels[i].source == NULL)
                        continue;       /* Channel inactive or not bound. */
                
                calculate_bound_volume(i);
        }
}

void
audio_set_volume(int ch, uint sound_id, int volume)
{
        assert(have_audio);
        assert(ch >= 0 && ch < num_channels && sound_id > 0);
        assert(volume >= 0 && volume <= MIX_MAX_VOLUME);
        
        /* If sound has finished or sound IDs do not match, ignore. */
        if (channels[ch].snd == NULL || channels[ch].sound_id != sound_id)
                return;

        Mix_Volume(ch, volume);
}

void
audio_set_group_volume(uintptr_t group, int volume)
{
        if (!have_audio)
                return;
        assert(volume >= 0 && volume <= MIX_MAX_VOLUME);
        
        if (group == 0) {
                /* Set volume on all channels. */
                Mix_Volume(-1, volume);
                return;
        }
        
        /* Set volume on active channels that belong to group. */
        for (int i = 0; i < num_channels; i++) {
                if (channels[i].snd != NULL && channels[i].group == group)
                        Mix_Volume(i, volume);
        }
}

void
audio_fadeout_group(uintptr_t group, int fade_time)
{
        if (!have_audio)
                return;
        assert(fade_time >= 0);
        
        if (group == 0) {
                /* Fade out all channels. */
                Mix_FadeOutChannel(-1, fade_time);
                return;
        }
        
        /* Fade out active channels that belong to group. */
        for (int i = 0; i < num_channels; i++) {
                if (channels[i].snd != NULL && channels[i].group == group)
                        Mix_FadeOutChannel(i, fade_time);
        }
}

void
audio_stop_group(uintptr_t group)
{
        if (!have_audio)
                return;
        
        if (group == 0) {
                /* Halt all channels. */
                Mix_HaltChannel(-1);
                return;
        }
        
        /* Halt active channels that belong to group. */
        for (int i = 0; i < num_channels; i++) {
                if (channels[i].snd != NULL && channels[i].group == group)
                        Mix_HaltChannel(i);
        }
}

void
audio_fadeout(int ch, uint sound_id, int fade_time)
{
        assert(have_audio);
        assert(ch >= 0 && ch < num_channels && sound_id > 0);
        assert(fade_time >= 0);
        
        /* If sound has finished or sound IDs do not match, ignore. */
        if (channels[ch].snd == NULL || channels[ch].sound_id != sound_id)
                return;

        Mix_FadeOutChannel(ch, fade_time);
}

void
audio_stop(int ch, uint sound_id)
{
        assert(have_audio);
        assert(ch >= 0 && ch < num_channels && sound_id > 0);
        
        /* If sound has finished or sound IDs do not match, ignore. */
        if (channels[ch].snd == NULL || channels[ch].sound_id != sound_id)
                return;

        Mix_HaltChannel(ch);
}

/*
 * loops        If zero, play infinite number of times.
 */
void
audio_music_play(const char *name, int volume, int loops, int fade_in, double pos)
{
        assert(have_audio);
        assert(loops >= 0);
        assert(volume >= 0 && volume <= MIX_MAX_VOLUME);
        assert(name && *name && fade_in >= 0 && pos >= 0.0);
        
        if (loops == 0)
                loops = -1;
        
        Music *music = music_lookup_or_create(name);
        Mix_VolumeMusic(volume);
        Mix_RewindMusic();
        
        Mix_FadeInMusicPos(music->mix_music, loops, fade_in, pos);
}

void
audio_music_set_volume(int volume)
{
        assert(volume >= 0 && volume <= MIX_MAX_VOLUME);
        Mix_VolumeMusic(volume);
}

void
audio_music_pause(void)
{
        Mix_PauseMusic();
}

void
audio_music_resume(void)
{
        Mix_ResumeMusic();
}

void
audio_music_fadeout(int fade_time)
{
        assert(fade_time >= 0);
        Mix_FadeOutMusic(fade_time);
}

/*
 * Callback that is invoked whenever a channel finishes playback.
 */
static void
channel_finished(int ch)
{
        assert(ch >= 0 && ch < num_channels);
        
        /*
         * Note: For reasons unknown this callback is sometimes called twice.
         * It does not really matter now, but if user callbacks are implemented,
         * then they should not be called twice.
         */
        if (channels[ch].snd != NULL)
                memset(&channels[ch], 0, sizeof(channels[ch]));
}

int
audio_init()
{        
        /* Print SDL_mixer runtime & compile versions. */
        const SDL_version *runtime_ver = Mix_Linked_Version();
        log_msg("SDL_mixer runtime version: %u.%u.%u", runtime_ver->major,
            runtime_ver->minor, runtime_ver->patch);
        SDL_version compile_ver;
        SDL_MIXER_VERSION(&compile_ver);
        log_msg("SDL_mixer compile version: %u.%u.%u", compile_ver.major,
            compile_ver.minor, compile_ver.patch);
        
        /* Initialize SDL mixer. */
        int mixer_flags = MIX_INIT_OGG;
        if ((Mix_Init(mixer_flags) & mixer_flags) != mixer_flags) {
                log_warn("Mix_Init() failed: %s.", Mix_GetError());
                return (have_audio = 0);
        }
        
        /* Read sound configuration. */
        frequency = cfg_get_int("frequency");
        num_channels = cfg_get_int("channels");
        chunksize = cfg_get_int("chunksize");
        int output_channels = cfg_get_bool("stereo") ? 2 : 1;
        
        /* Call Mix_OpenAudio with parameters from configuration. */
        int stat = Mix_OpenAudio(frequency, MIX_DEFAULT_FORMAT, output_channels,
            chunksize);
        if (stat == -1) {
                log_warn("Mix_OpenAudio failed: %s.", Mix_GetError());
                Mix_Quit();
                return (have_audio = 0);
        }
        
        /* Allocate requested number of mixing channels. */
        num_channels = Mix_AllocateChannels(num_channels);
        
        /* Get the actual audio setup. */
        Uint16 format;
        int num_open = Mix_QuerySpec(&frequency, &format, &output_channels);
        if (num_open == 0) {
                log_warn("Mix_QuerySpec error: %s.", Mix_GetError());
                Mix_Quit();
                return (have_audio = 0);
        }
        const char *format_str, *output_str;
        switch (format) {
                case AUDIO_U8: format_str = "U8"; break;
                case AUDIO_S8: format_str = "S8"; break;
                case AUDIO_U16LSB: format_str = "U16LSB"; break;
                case AUDIO_S16LSB: format_str = "S16LSB"; break;
                case AUDIO_U16MSB: format_str = "U16MSB"; break;
                case AUDIO_S16MSB: format_str = "S16MSB"; break;
                default:
                        format_str = "Unknown";
        }
        switch (output_channels) {
                case 1: output_str = "Mono"; break;
                case 2: output_str = "Stereo"; break;
                default:
                        output_str = "Unknown";
        }
        log_msg("Audio opened: frequency=%dHz format=%s output=%s "
            "num_channels=%d chunksize=%d", frequency, format_str, output_str,
            num_channels, chunksize);
        
        /* Print info about chunk decoders. */
        int num_decoders = Mix_GetNumChunkDecoders();
        log_msg("There are %d sample chunk deocoders available:", num_decoders);
        for (int i = 0; i < num_decoders; i++) {
                log_msg("\tSample chunk decoder %d is for %s", i,
                    Mix_GetChunkDecoder(i));
        }
        
        /* Print info about music decoders. */
        num_decoders = Mix_GetNumMusicDecoders();
        log_msg("There are %d music deocoders available:", num_decoders);
        for (int i = 0; i < num_decoders; i++) {
                log_msg("\tMusic decoder %d is for %s", i,
                    Mix_GetMusicDecoder(i));
        }
        
        /* Register callback to be called when a channel finishes playback. */
        Mix_ChannelFinished(channel_finished);
        
        /* Set up sound and music memory pools. */
        mem_pool_init(&mp_sound, sizeof(Sound), 100, "Sound");
        mem_pool_init(&mp_music, sizeof(Music), 10, "Music");
        
        return (have_audio = 1);
}

void
audio_close()
{
        if (!have_audio)
                return;
        
        Mix_CloseAudio();
        Mix_Quit();
        
        mp_free_all(&mp_sound);
        mp_free_all(&mp_music);
}
