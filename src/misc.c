#include <lua.h>
#include <SDL.h>
#include <SDL_image.h>
#include <assert.h>
#include <math.h>
#include <stdarg.h>
#include <stdint.h>
#include "config.h"
#include "log.h"
#include "lua_util.h"
#include "mem.h"
#include "misc.h"

#if 0
/*
 * Generate a checkerboard texture. Texture ID has to be already generated and
 * bound.
 */
void
gentex_checkerboard(int width, int height)
{
	int i, j, c;
	GLubyte *board;
	GLubyte color1[] = {40, 80, 10, 255};
	GLubyte color2[] = {40, 40, 40, 255};
	
	assert(width > 0 && height > 0);
	assert(is_power(width, 2) && is_power(height, 2));

	board = mem_alloc(width * height * 4, "Checkerboard texture");

	for (i = 0; i < width; i++) {
		for (j = 0; j < height; j++) {
			c = (((i&0x1)==0)^((j&0x1)==0));
			memcpy(&board[(j*width + i)*4], c ? color1 : color2, 4);
		}
	}
	glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, width, height, 0, GL_RGBA,
	    GL_UNSIGNED_BYTE, board);
	mem_free(board);
}
#endif /* Unused block. */

/*
 * Load OpenGL texture from SDL surface.
 *
 * tex		Texture object that will be modified.
 * img		SDL surface to be loaded.
 */
void
surface_to_texture(Texture *tex, SDL_Surface *img)
{
	SDL_Surface *converted;
	Uint32 flags, rmask, gmask, bmask, amask;

	assert(tex != NULL);
	assert(!SDL_MUSTLOCK(img)); /* Shouldn't require locking. */
	
#if SDL_BYTEORDER == SDL_BIG_ENDIAN
	rmask = 0xff000000;
	gmask = 0x00ff0000;
	bmask = 0x0000ff00;
	amask = 0x000000ff;
#else
	rmask = 0x000000ff;
	gmask = 0x0000ff00;
	bmask = 0x00ff0000;
	amask = 0xff000000;
#endif
	/* Create a surface with such a pixel format that we can feed its pixels
	   directly into OpenGL. */
	flags = SDL_SWSURFACE | SDL_SRCALPHA;
	converted = SDL_CreateRGBSurface(flags, img->w, img->h, 32, rmask,
	    gmask, bmask, amask);
	if (converted == NULL)
		fatal_error("[SDL] Could not create surface for texture (%s)"
		    "conversion: %s", tex->name, SDL_GetError());
	    
	/* From SDL documentation wiki:
	 * When you're blitting between two alpha surfaces, normally the alpha
	 * of the destination acts as a mask. If you want to just do a
	 * "dumb copy" that doesn't blend, you have to turn off the SDL_SRCALPHA
	 * flag on the source surface. This is how it's supposed to work, but
	 * can be surprising when you're trying to combine one image with
	 * another and both have transparent backgrounds.
	 */
	img->flags &= ~SDL_SRCALPHA;
	
	/* Copy loaded image data onto a surface that we can feed into OpenGL.
	   We let SDL_BlitSurface() do all the conversion work. */
	if (SDL_BlitSurface(img, NULL, converted, NULL) != 0)
		fatal_error("[SDL] Convert-blit of %s unsuccessful.", tex->name);
	
	/* Store image width & height in texture struct. Note that actual
	   texture size must be power of two. */
	tex->w = img->w;
	tex->h = img->h;
	tex->pow_w = nearest_pow2(img->w);
	tex->pow_h = nearest_pow2(img->h);

	/* Create a blank texture with power-of-two dimensions. Then load
	   converted image data into its lower left. */
	glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, tex->pow_w, tex->pow_h, 0,
	    GL_RGBA, GL_UNSIGNED_BYTE, NULL);
	glTexSubImage2D(GL_TEXTURE_2D, 0, 0, 0, converted->w, converted->h,
	    GL_RGBA, GL_UNSIGNED_BYTE, converted->pixels);
	    
	SDL_FreeSurface(converted);
}

/*
 * Given an image filename, load it as SDL surface using SDL_image's
 * IMG_Load(); then convert it to OpenGL texture and free the surface.
 */
void
load_texture_from_file(Texture *tex, const char *filename)
{
	SDL_Surface *img;

	log_msg("Loading '%s' into texture memory (id=%i).", filename, tex->id);
	img = IMG_Load(filename);
	if (img == NULL) {
		log_err("[SDL_image] %s.", IMG_GetError());
		abort();
	}

	surface_to_texture(tex, img);
	SDL_FreeSurface(img);
}

/*
 * Copy OpenGL color buffer into client memory.
 */
void
read_screen(void *pixels, GLenum color_buffer, int w, int h)
{
	glReadBuffer(color_buffer);
	glReadPixels(0, 0, w, h, GL_RGBA, GL_UNSIGNED_BYTE, pixels);
}

/*
 * Copy pixels from client memory into OpenGL color buffer.
 */
void
write_screen(void *pixels, GLenum color_buffer, int w, int h)
{
	glDrawBuffer(color_buffer);
	glDrawPixels(w, h, GL_RGBA, GL_UNSIGNED_BYTE, pixels);
}

/*
 * This behaves like SDL_GetError() but reports OpenGL errors.
 */
const char *
GL_GetError()
{
	switch (glGetError()) {
	case GL_NO_ERROR:
		return NULL;
	case GL_INVALID_ENUM:
		return "Unacceptable value for an enumerated argument.";
	case GL_INVALID_VALUE:
		return "Numeric argument out of range.";
	case GL_INVALID_OPERATION:
		return "Specified operation not allowed.";
	case GL_STACK_OVERFLOW:
		return "Command would cause stack overflow.";
	case GL_STACK_UNDERFLOW:
		return "Command would cause stack underflow.";
	case GL_OUT_OF_MEMORY:
		return "Not enough memory.";
#ifdef GL_VERSION_1_2	/* Looks like later versions will still define this. */
	case GL_TABLE_TOO_LARGE:
		return "Table exceeds supported size.";
#endif /* OpenGL version >= 1.2 */
	default:
		return "Unknown error code.";
	}
}

/*
 * Check OpenGL error state and report any errors.
 */
void
check_errors_GL()
{
	const char *s;

	/* Read glGetError() man page for why this is a loop. */
	while ((s = GL_GetError()))
		log_err("[OpenGL] %s", s);
}

/*
 * Check SDL's error state and report any errors.
 */
void
check_errors_SDL()
{
	const char *s;
	
	s = SDL_GetError();
	if (strlen(s) != 0) {
		log_err("[SDL] %s", s);
		SDL_ClearError();
	}
}

/*
 * Logs any OpenGL and SDL errors that might have occured. Use this at least
 * every frame to notice all errors.
 */
void
check_errors()
{
	check_errors_GL();
	check_errors_SDL();
}

/*
 * Look for extension name in the the GL_EXTENSIONS string.
 */
int
check_extension(const char *name)
{
	int wordlen, namelen;
	char *estr, *end;

	assert(name != NULL);

	estr = (char *)glGetString(GL_EXTENSIONS);
	if (estr == NULL) {
		log_err("glGetString(GL_EXTENSIONS) returned 0.");
		check_errors_GL();
		return 0;
	}
	namelen = strlen(name);
	end = estr + strlen(estr);

	while (estr < end) {
		wordlen = strcspn(estr, " "); /* Count non-space characters. */
		if ((namelen == wordlen) && (strncmp(name, estr, wordlen) == 0))
			return 1;
		estr += (wordlen + 1);
	}
	return 0;
}

/* Nearest power of 2. */
uint
nearest_pow2(uint number)
{
        uint result = 2;
        while (result < number)
                result <<= 1;
        return result;
}

/*
 * Is [number] a power of [base]?.
 */
int
is_power(int number, int base)
{
	assert(base != 0);

	while (number != 1) {
		if (number % base != 0)
			return 0;
		number /= base;
	}
	return 1;
}

/*
 * Pick smallest float from all the arguments and return it.
 *
 * n		Number of float arguments.
 * ...		n floating point numbers.
 */
float
minf(int n, ...)
{
	float f, min_f;
	va_list ap;

	min_f = HUGE_VAL;
	va_start(ap, n);
	while (n--) {
		/* NOTE: floats are promoted to double when passed as ... */
		f = va_arg(ap, double);
		if (f < min_f)
			min_f = f;
	}
	va_end(ap);
	return min_f;
}

/*
 * Pick biggest float from all the arguments and return it.
 *
 * n		Number of float arguments.
 * ...		n floating point numbers.
 */
float
maxf(int n, ...)
{
	float f, max_f;
	va_list ap;

	max_f = -HUGE_VAL;
	va_start(ap, n);
	while (n--) {
		/* NOTE: floats are promoted to double when passed as ... */
		f = va_arg(ap, double);
		if (f > max_f)
			max_f = f;
	}
	va_end(ap);
	return max_f;
}

/*
 * Test two floating point numbers for equality.
 */
int
float_eq(float a, float b, float epsilon)
{
	if (fabs(a - b) < MAX3(a, b, 1.0) * epsilon)
		return 1;
	return 0;
}

uint32_t
color_floatv_to_uint32(float color[4])
{
	uint32_t c;
	
#if SDL_BYTEORDER == SDL_BIG_ENDIAN
	c = ((uint32_t)(color[0]*255.0) << 24);
	c |= ((uint32_t)(color[1]*255.0) << 16);
	c |= ((uint32_t)(color[2]*255.0) << 8);
	c |= ((uint32_t)(color[3]*255.0) << 0);
#else
	c = ((uint32_t)(color[3]*255.0) << 24);
	c |= ((uint32_t)(color[2]*255.0) << 16);
	c |= ((uint32_t)(color[1]*255.0) << 8);
	c |= ((uint32_t)(color[0]*255.0) << 0);
#endif
	return c;
}

void
color_uint32_to_floatv(uint32_t in, float out[4])
{
#if SDL_BYTEORDER == SDL_BIG_ENDIAN
	out[0] = ((in & 0xFF000000) >> 24) / 255.0;
	out[1] = ((in & 0x00FF0000) >> 16) / 255.0;
	out[2] = ((in & 0x0000FF00) >> 8) / 255.0;
	out[3] = ((in & 0x000000FF) >> 0) / 255.0;
#else
	out[3] = ((in & 0xFF000000) >> 24) / 255.0;
	out[2] = ((in & 0x00FF0000) >> 16) / 255.0;
	out[1] = ((in & 0x0000FF00) >> 8) / 255.0;
	out[0] = ((in & 0x000000FF) >> 0) / 255.0;
#endif
}

