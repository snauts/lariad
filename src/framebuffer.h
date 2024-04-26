#ifndef FRAMEBUFFER_H
#define FRAMEBUFFER_H

void switch_framebuffer(void);
void fade_to_other_framebuffer(int transition_type);
void bind_framebuffer(void);
void draw_framebuffer(void);
void cleanup_framebuffer(void);

#endif