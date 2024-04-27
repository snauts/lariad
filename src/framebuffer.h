#ifndef FRAMEBUFFER_H
#define FRAMEBUFFER_H

void switch_framebuffer(void);
void fade_to_other_framebuffer(int transition_type);
void init_framebuffers();
void draw_framebuffer_effects(void);
void cleanup_framebuffer(void);

#endif