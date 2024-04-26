#include <math.h>
#include <stdio.h>
#include <assert.h>
#include <SDL_opengl.h>
#include "config.h"
#include "geometry.h"
#include "misc.h"
#include "log.h"

extern Config config;

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

static GLuint main_framebuffer;
static GLuint offscreen_framebuffer;
static GLuint main_fb_texture_id;
static GLuint offscreen_fb_texture_id;

/*
 * Since framebuffer texture has power of two dimensions, these texture coords
 * are necessary to extract the actual content (excluding the blank area).
 */
static float fb_texture_s;
static float fb_texture_t;

static void init_framebuffers() {
    uint fb_texture_w = nearest_pow2(config.screen_width);
    uint fb_texture_h = nearest_pow2(config.screen_height);
    fb_texture_s = (float)config.screen_width / fb_texture_w;
    fb_texture_t = (float)config.screen_height / fb_texture_h;

    /* generate texture for main and offscreen framebuffers */
    glGenTextures(1, &main_fb_texture_id);
    glBindTexture(GL_TEXTURE_2D, main_fb_texture_id);
    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, fb_texture_w, fb_texture_h, 0, GL_RGBA, GL_UNSIGNED_BYTE, 0);
    glGenTextures(1, &offscreen_fb_texture_id);
    glBindTexture(GL_TEXTURE_2D, offscreen_fb_texture_id);
    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, fb_texture_w, fb_texture_h, 0, GL_RGBA, GL_UNSIGNED_BYTE, 0);
    glBindTexture(GL_TEXTURE_2D, 0);

    /* Get extension function addresses. */
    if (!glGenFramebuffers) {
	glGenFramebuffers = (__typeof__(glGenFramebuffers))
		SDL_GL_GetProcAddress("glGenFramebuffersEXT");
	glBindFramebuffer = (__typeof__(glBindFramebuffer))
		SDL_GL_GetProcAddress("glBindFramebufferEXT");
	glFramebufferTexture2D = (__typeof__(glFramebufferTexture2D))
		SDL_GL_GetProcAddress("glFramebufferTexture2DEXT");
	glDeleteFramebuffers = (__typeof__(glDeleteFramebuffers))
		SDL_GL_GetProcAddress("glDeleteFramebuffersEXT");
    }

    /* generate main framebuffer */
    glGenFramebuffers(1, &main_framebuffer);
    glBindFramebuffer(GL_FRAMEBUFFER, main_framebuffer);
    glFramebufferTexture2D(GL_FRAMEBUFFER,
			      GL_COLOR_ATTACHMENT0,
			      GL_TEXTURE_2D, main_fb_texture_id, 0);
    glClearColor(0.0, 0.0, 0.0, 1.0);
    glClear(GL_COLOR_BUFFER_BIT);

    /* generate offscreen framebuffer */
    glGenFramebuffers(1, &offscreen_framebuffer);
    glBindFramebuffer(GL_FRAMEBUFFER, offscreen_framebuffer);
    glFramebufferTexture2D(GL_FRAMEBUFFER,
			      GL_COLOR_ATTACHMENT0,
			      GL_TEXTURE_2D, offscreen_fb_texture_id, 0);
    glClearColor(0.0, 0.0, 0.0, 1.0);
    glClear(GL_COLOR_BUFFER_BIT);
    glBindFramebuffer(GL_FRAMEBUFFER, 0);

	GLenum error;
	while ((error = glGetError()) != GL_NO_ERROR) {
		log_warn("OpenGL error: %s", getGLErrorString(error));
	}
}

static void draw_scaled(GLuint texture_id, float q) {
    float w = 0.5 * (config.w_r - config.w_l);
    float h = 0.5 * (config.w_t - config.w_b);
	glBindTexture(GL_TEXTURE_2D, texture_id);
	glColor4f(1.0, 1.0, 1.0, 1.0);
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
    glBindTexture(GL_TEXTURE_2D, texture_id);
    glColor4f(1.0, 1.0, 1.0, alpha);
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
    draw_image(main_fb_texture_id, 0, 0, 1.0);
    draw_scaled(offscreen_fb_texture_id, progress);
}

static void zoom_out(float progress) {
    draw_image(main_fb_texture_id, 0, 0, 1.0);
    draw_scaled(offscreen_fb_texture_id, (1.0 - progress));
}

static void slide_sideways(float progress, float dir) {
    progress = gain(progress, 4);
    float width = dir * (config.w_r - config.w_l);
    draw_image(main_fb_texture_id, 0, 0, 1.0);
    draw_image(offscreen_fb_texture_id, (1.0 - progress) * width, 0, 1.0);
}

static void crossfade(float progress) {
    draw_image(main_fb_texture_id, 0, 0, 1.0);
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    draw_image(offscreen_fb_texture_id, 0, 0, 1.0 - progress);
}

static void display_effect(void) {
    float progress = timer_progress(0.5);
    if (progress >= 1.0) {
	effect_num = JUST_DISPLAY;
	draw_image(main_fb_texture_id, 0, 0, 1.0);
    } else {
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

void fade_to_other_framebuffer(int transition_type) {
    effect_num = transition_type;
    start_timer();
}

void bind_framebuffer(void) {
    static int init_done = 0;
    if (!init_done) {
	init_framebuffers();
	init_done = 1;
    }

    glBindFramebuffer(GL_FRAMEBUFFER, main_framebuffer);
    glClearColor(0.0, 0.0, 0.0, 0.0);
    glClear(GL_COLOR_BUFFER_BIT);
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
}

void draw_framebuffer(void) {
    extern uint bound_texture;
    glBindFramebuffer(GL_FRAMEBUFFER, 0); // bind default framebuffer
    glViewport(0, 0, config.window_width, config.window_height);
    glClearColor(0.0, 0.0, 0.0, 1.0);
    glClear(GL_COLOR_BUFFER_BIT);

    /* Reset texture matrix. */
    glMatrixMode(GL_TEXTURE);
    glLoadIdentity();

    glMatrixMode(GL_PROJECTION);
    glLoadIdentity();
    glOrtho(0.0, 1.0, 0.0, 1.0, 0.0, 1.0);
    glBlendFunc(GL_ONE, GL_ZERO);

    if (effect_num == JUST_DISPLAY) {
	draw_image(main_fb_texture_id, 0, 0, 1.0);
    } else {
	display_effect();
    }

    glBindTexture(GL_TEXTURE_2D, 0);
    bound_texture = 0;
}

void cleanup_framebuffer(void) {
	glDeleteTextures(1, &main_fb_texture_id);
	glDeleteTextures(1, &offscreen_fb_texture_id);
	glDeleteFramebuffers(1, &main_framebuffer);
	glDeleteFramebuffers(1, &offscreen_framebuffer);
}
