#include <assert.h>
#include <math.h>
#include <stdlib.h>
#include <string.h>
#include "common.h"
#include "log.h"
#include "mem.h"
#include "path.h"
#include "utlist.h"

/*
 * Initialize Path structure. See the structure definition (path.h) for what the
 * arguments mean.
 */
void
path_init(Path *path, int interp, int closed, int outside, int motion)
{
	assert(path != NULL);
	assert(interp == PATH_LINEAR);
	assert(outside == PATH_LOOP || outside == PATH_CLAMP ||
	    outside == PATH_REVERSE);
	assert(motion == PATH_NORMAL || motion == PATH_PIECEWISE ||
	    motion == PATH_CONSTANT);
	
	path->objtype = OBJTYPE_PATH;
	path->refcount = 0;
	path->points = NULL;
	path->num_points = 0;
	path->last_index = 0;
	path->last_point = NULL;
	path->interp = interp;
	path->closed = closed;
	path->outside = outside;
	path->motion = motion;
}

Path *
path_new(int interp, int closed, int outside, int motion)
{
	extern mem_pool mp_path;
	Path *path;
	
	path = mp_alloc(&mp_path);
	path_init(path, interp, closed, outside, motion);
	return path;
}

void	 
path_destroy(Path *path)
{
	vect_f_list *lv;
	assert(path != NULL && path->refcount == 0);
	
	/* Destroy point list. */
	while (path->points != NULL) {
		lv = path->points;
		DL_DELETE(path->points, path->points);
		listvect_free(lv);
	}
	memset(path, 0, sizeof(Path));
}

void
path_free(Path *path)
{
	extern mem_pool mp_path;
	
	path_destroy(path);
	mp_free(&mp_path, path);
}

/*
 * Add a point at the end of path.
 */
void
path_add(Path *path, vect_f p)
{
	vect_f_list *lv;
	
	lv = listvect_new(p);
	DL_APPEND(path->points, lv);
	
	path->num_points++;
	if (path->last_point == NULL)
		path->last_point = path->points;
}

vect_f
path_get(Path *path, int index)
{
	assert(path != NULL && path->num_points > 0);
	assert(index >= 0 && index < path->num_points);
	assert(path->last_index >= 0 && path->last_index < path->num_points);
	assert(path->last_point != NULL);
	
	if (index >= path->last_index) {
		while (index != path->last_index) {
			path->last_index++;
			path->last_point = path->last_point->next;
		}
	} else {
		while (index != path->last_index) {
			path->last_index--;
			path->last_point = path->last_point->prev;
		}
	}
	return path->last_point->v;
}

static int
linear(Path *path, float t, vect_f *result)
{
	int i, j, N;
	vect_f p1, p2;
	float tfrac;
	
	/* N is number of segments. For an open path this is one less than
	   number of points. For closed paths they're the same. */
	N = path->closed ? path->num_points : path->num_points - 1;
	
	switch (path->motion) {
	case PATH_NORMAL:
		t *= N;
		break;
	case PATH_PIECEWISE:
		break;
	case PATH_CONSTANT:
	default:
		fatal_error("Unsupported motion type: %i.", path->motion);
	}
	
	/* i is index of point that comes before t, and j is index of point
	   that comes after t. */
	switch (path->outside) {
	case PATH_REVERSE:
		/* If we're going in the negative direction, translate t so it
		   maps to the same point in positive direction. */
		if (t < 0.0)
			t = 2*N - t;
		
		i = ((int)floor(t)) % (2*N);
		j = ((int)ceil(t)) % (2*N);
		if (i >= path->num_points)
			i = (2*N - i) % path->num_points;
		if (j >= path->num_points)
			j = (2*N - j) % path->num_points;
		break;
	case PATH_CLAMP:
		i = (int)floor(t);
		j = (int)ceil(t);
		if (i >= N)
			i = N;
		if (j >= N)
			j = N;
		break;
	case PATH_LOOP:
		i = ((int)floor(t)) % N;
		j = ((int)ceil(t)) % N;
		break;
	}
	
	p1 = path_get(path, i);
	p2 = path_get(path, j);
	tfrac = t - floor(t); /* Fractional part of t. */

	/* Calculate interpolation p = p1*(1-t) + p2*t. */
	*result = vect_f_add(vect_f_scale(p1, 1-tfrac), vect_f_scale(p2, tfrac));
	return 0;
}

/*
 * Interpolate path points to produce an intermediate point as result.
 *
 * path		Path structure pointer.
 * t		Time (or progress) value.
 * result	Computed point is stored here.
 *
 * Computed result of this function is dependent on "interp", "closed",
 * "outside", and "motion" members of path structure.
 * Zero return value means success, nonzero - error.
 */
int
path_interp(Path *path, float t, vect_f *result)
{
	assert(path != NULL);
	if (path->num_points < 2)
		return 1;
	
	switch (path->interp) {
	case PATH_LINEAR:
		return linear(path, t, result);
	default:
		fatal_error("Interpolation type (%i) unsupported.",
		    path->interp);
	}
	/* NOTREACHED */
	return 1;
}
