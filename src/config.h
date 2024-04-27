#ifndef CONFIG_H
#define CONFIG_H

#include "str.h"

/* Cached configuration (mostly read from config.lua). */
typedef struct {
	uint	FPSUpdateInterval;
	int	gameSpeed;
	float defaultShapeColor[4];
	String  name;       /* Game name. */
	String	version;	/* Game version. */
	String	location;	/* User application location path. */
	
	uint	screen_width;
	uint	screen_height;
	uint	window_width;
	uint	window_height;
	/* top, bottom, left, right corner of drawable window */
	float	w_t, w_b, w_l, w_r;
	int	force_native;
} Config;

void	cfg_read(const char *filename);
void	cfg_close();

/* Retrieve configuration. */
double	cfg_get_double(const char *key);
void	cfg_get_str(const char *key, String *result);
void	cfg_get_color(const char *key, float color[4]);
int	cfg_get_int(const char *key);
int	cfg_get_bool(const char *key);
int	cfg_has_field(const char *key);

#define GET_CFG(key, method, default_value) \
    (cfg_has_field(key) ? method(key) : (default_value))

#endif /* CONFIG_H */
