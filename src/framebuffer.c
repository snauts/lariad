#include <math.h>
#include <stdio.h>
#include <assert.h>
#include <SDL_opengl.h>
#include "config.h"
#include "geometry.h"
#include "misc.h"
#include "log.h"

extern Config config;

void (*glGenerateMipmap)(GLenum target);
void (*glGenFramebuffers)(GLsizei n, GLuint *ids);
void (*glBindFramebuffer)(GLenum target, GLuint framebuffer);
void (*glFramebufferTexture2D)(GLenum target, GLenum attachment, GLenum textarget, GLuint texture, GLint level);
void (*glDeleteFramebuffers)(GLsizei n, GLuint *framebuffers);

enum {
    JUST_DISPLAY = 0,
    CROSSFADE,
    SLIDE_LEFT,
    SLIDE_RIGHT,
    ZOOM_IN,
    ZOOM_OUT,
};

static int fb_to_display = 0;
static int fb_to_draw_into = 0;
static GLuint fbo_id[] = { 0, 0 };
static GLuint texture_id[] = { 0, 0 };

/*
 * Since framebuffer texture has power of two dimensions, these texture coords
 * are necessary to extract the actual content (excluding the blank area).
 */
static float fb_texture_s;
static float fb_texture_t;

void switch_framebuffer(void) {
    fb_to_draw_into = fb_to_draw_into ^ 1;
    fb_to_display = fb_to_draw_into ^ 1;
}

static void init_framebuffer(int i) {
    uint fb_texture_w = nearest_pow2(config.screen_width);
    uint fb_texture_h = nearest_pow2(config.screen_height);
    fb_texture_s = (float)config.screen_width / fb_texture_w;
    fb_texture_t = (float)config.screen_height / fb_texture_h;

    /* generate texture */
    glGenTextures(1, &texture_id[i]);
    glBindTexture(GL_TEXTURE_2D, texture_id[i]);
    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA8, fb_texture_w, fb_texture_h, 0, GL_RGBA, GL_UNSIGNED_BYTE, 0);
    glBindTexture(GL_TEXTURE_2D, 0);

    /* Get extension function addresses. */
    glGenerateMipmap = (__typeof__(glGenerateMipmap))
        SDL_GL_GetProcAddress("glGenerateMipmapEXT");
    glGenFramebuffers = (__typeof__(glGenFramebuffers))
        SDL_GL_GetProcAddress("glGenFramebuffersEXT");
    glBindFramebuffer = (__typeof__(glBindFramebuffer))
        SDL_GL_GetProcAddress("glBindFramebufferEXT");
    glFramebufferTexture2D = (__typeof__(glFramebufferTexture2D))
        SDL_GL_GetProcAddress("glFramebufferTexture2DEXT");
    glDeleteFramebuffers = (__typeof__(glDeleteFramebuffers))
            SDL_GL_GetProcAddress("glDeleteFramebuffersEXT");

    /* generate framebuffer object */
    glGenFramebuffers(1, &fbo_id[i]);
    glBindFramebuffer(GL_FRAMEBUFFER, fbo_id[i]);
    glFramebufferTexture2D(GL_FRAMEBUFFER,
			      GL_COLOR_ATTACHMENT0,
			      GL_TEXTURE_2D, texture_id[i], 0);
    glClearColor(0.0, 0.0, 0.0, 1.0);
    glClear(GL_COLOR_BUFFER_BIT);
    glBindFramebuffer(GL_FRAMEBUFFER, 0);

	GLenum error;
	while ((error = glGetError()) != GL_NO_ERROR) {
		log_warn("OpenGL error: %s", getGLErrorString(error));
	}
}

void bind_framebuffer(void) {
    static int init_done = 0;
    if (!init_done) {
	init_framebuffer(0);
	init_framebuffer(1);
	init_done = 1;
    }
    glBindFramebuffer(GL_FRAMEBUFFER_EXT, fbo_id[fb_to_draw_into]);
}

static void draw_prolog(GLuint texture_id, float alpha) {
    glBindTexture(GL_TEXTURE_2D, texture_id);
    glColor4f(1.0, 1.0, 1.0, alpha);
}

static void draw_scaled(GLuint texture_id, float q) {
    float w = 0.5 * (config.w_r - config.w_l);
    float h = 0.5 * (config.w_t - config.w_b);
    draw_prolog(texture_id, 1.0);
    glBegin(GL_QUADS);
    glTexCoord2f(0, 0);
    glVertex2f(0.5 - q * w, 0.5 - q * h);
    glTexCoord2f(0, fb_texture_t);
    glVertex2f(0.5 - q * w, 0.5 + q * h);
    glTexCoord2f(fb_texture_s, fb_texture_t);
    glVertex2f(0.5 + q * w, 0.5 + q * h);
    glTexCoord2f(fb_texture_s, 0);
    glVertex2f(0.5 + q * w, 0.5 - q * h);
    glEnd();
}

static void draw_image(GLuint texture_id, float x, float y, float alpha) {
    draw_prolog(texture_id, alpha);
    glBegin(GL_QUADS);
    glTexCoord2f(0, 0);
    glVertex2f(config.w_l + x, config.w_b + y);
    glTexCoord2f(0, fb_texture_t);
    glVertex2f(config.w_l + x, config.w_t + y);
    glTexCoord2f(fb_texture_s, fb_texture_t);
    glVertex2f(config.w_r + x, config.w_t + y);
    glTexCoord2f(fb_texture_s, 0);
    glVertex2f(config.w_r + x, config.w_b + y);
    glEnd();
}

static void just_display_framebuffer(void) {
    draw_image(texture_id[fb_to_display], 0, 0, 1.0);
}

static int effect_num = JUST_DISPLAY;
static uint64_t timer;
static void start_timer(void) {
    timer = SDL_GetTicks();
}

static float timer_progress(float seconds) {
    assert(seconds != 0.0);
    return (SDL_GetTicks() - timer) / (1000 * seconds);
}

static float gain(float x, float q) {
    return 0.5 * ((x < 0.5) ? powf(2 * x, q) : (2 - powf(2 - 2 * x, q)));
}

static void zoom_in(float progress) {
    draw_image(texture_id[fb_to_display], 0, 0, 1.0);
    draw_scaled(texture_id[fb_to_draw_into], progress);
}

static void zoom_out(float progress) {
    draw_image(texture_id[fb_to_draw_into], 0, 0, 1.0);
    draw_scaled(texture_id[fb_to_display], (1.0 - progress));
}

static void slide_sideways(float progress, float dir) {
    progress = gain(progress, 4);
    float width = dir * (config.w_r - config.w_l);
    draw_image(texture_id[fb_to_display], 0, 0, 1.0);
    draw_image(texture_id[fb_to_draw_into], (1.0 - progress) * width, 0, 1.0);
}

static void crossfade(float progress) {
    draw_image(texture_id[fb_to_draw_into], 0, 0, 1.0);
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    draw_image(texture_id[fb_to_display], 0, 0, 1.0 - progress);
}

static void display_effect(void) {
    float progress = timer_progress(0.5);
    if (progress >= 1.0) {
	effect_num = JUST_DISPLAY;
	fb_to_display = fb_to_draw_into;
	just_display_framebuffer();
    }
    else {
	switch (effect_num) {
	case SLIDE_LEFT:
	    slide_sideways(progress, -1);
	    break;
	case SLIDE_RIGHT:
	    slide_sideways(progress, 1);
	    break;
	case ZOOM_IN:
	    zoom_in(progress);
	    break;
	case ZOOM_OUT:
	    zoom_out(progress);
	    break;
	default:
	    crossfade(progress);
	    break;
	}
    }
}

static void framebuffer_effect(void) {
    if (effect_num == JUST_DISPLAY) {
	just_display_framebuffer();
    }
    else {
	display_effect();
    }
}

void fade_to_other_framebuffer(int transition_type) {
    effect_num = transition_type;
    start_timer();
}

void draw_framebuffer(void) {
    extern uint bound_texture;
    glBindFramebuffer(GL_FRAMEBUFFER_EXT, 0);
    glViewport(0, 0, config.window_width, config.window_height);
    glClearColor(0.0, 0.0, 0.0, 1.0);
    glClear(GL_COLOR_BUFFER_BIT);
    glMatrixMode(GL_PROJECTION);
    glLoadIdentity();

    glOrtho(0.0, 1.0, 0.0, 1.0, 0.0, 1.0);
    glBlendFunc(GL_ONE, GL_ZERO);

    framebuffer_effect();

    glBindTexture(GL_TEXTURE_2D, 0);
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    bound_texture = 0;
}

static void delete_framebuffer(int i) {
    if (texture_id[i]) {
	glDeleteTextures(1, &texture_id[i]);
    }
    if (fbo_id[i]) {
	glDeleteFramebuffers(1, &fbo_id[i]);
    }
}

void cleanup_framebuffer(void) {
    delete_framebuffer(0);
    delete_framebuffer(1);
}
