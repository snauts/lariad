#ifndef MISC_H
#define MISC_H

#include <lua.h>
#include <SDL.h>
#include <SDL_opengl.h>
#include <stdint.h>
#include "common.h"
#include "game2d.h"
#include "str.h"

/* Game initialization. */
int	check_extension(const char *name);
int	getopt_bsd(int argc, char* const argv[], const char *optstring);

/* Textures. */
void	surface_to_texture(Texture *tex, SDL_Surface *img);
void	load_texture_from_file(Texture *tex, const char *filename);

/* Read/write OpenGL buffers. */
void	read_screen(void *pixels, GLenum color_buffer, int w, int h);
void	write_screen(void *pixels, GLenum color_buffer, int w, int h);

/* Error checks. */
const char 	*GL_GetError();
void		 check_errors_GL();
void		 check_errors_SDL();
void		 check_errors();

/* Number related. */
uint	nearest_pow2(uint number);
int	is_power(int number, int base);
float	minf(int n, ...);
float	maxf(int n, ...);
int	float_eq(float a, float b, float epsilon);

#endif /* MISC_H */
