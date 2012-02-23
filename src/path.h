#ifndef PATH_H
#define PATH_H

#include "geometry.h"

/* Type of interpolation. */
#define PATH_LINEAR	10
#define PATH_CUBIC	11
	
/* What happens when t falls outside of base range. */
#define PATH_LOOP	20
#define PATH_CLAMP	21
#define PATH_REVERSE	22

/* Motion type, given a linear increase/decrease of t. */
#define PATH_NORMAL	30
#define PATH_PIECEWISE	31
#define PATH_CONSTANT	32

/*
 * Path is a list of points whose values can be used for interpolation to
 * produce intermediate positions. Time (or progress) value is supplied to an
 * interpolation routine which produces a corresponding point.
 * There are several variables (members of Path) that control the behavior of
 * this function:
 *	interp	Interpolation type. LINEAR is as if straight line segments were
 *		drawn from point to point, without any curvature. Other possible
 *		types such as CUBIC, COSINE, HERMITE produce smoother movement.
 *	closed	Closed paths have first and last points connected. The other
 *		option would be an open path.
 *	outside	This variable controls what happens when time (t) value falls
 *		outside its base range (this can be 0..1, or 0..N, or 0..N-1
 *		depending on other path variables). The produced positions can
 *		be LOOPed, CLAMPed, or REVERSEd.
 *	motion	Motion describes what base range of values for time are allowed,
 *		and how they are interpreted.
 *		NORMAL motion base interval always goes from 0..1, where 0 means
 *		beginning of path and 1 means the end of path. This type of
 *		motion timing is not specifically defined but instead is what
 *		is most "natural" (easiest) for each path interpolation type.
 *		PIECEWISE timing base interval is 0..N-1 or 0..N (if path is
 *		closed) and each point-to-point distance corresponds to a time
 *		range length of one. So t=0 corresponds to points[0], t=1
 *		corresponds to points[1], and t=N-1 corresponds to points[N-1].
 *		CONSTANT goes from 0..1, and produces constant velocity motion
 *		(as opposed to PIECEWISE moving faster for longer intervals, and
 *		slower for shorter ones).
 */
typedef struct {
	int	objtype;	/* = OBJTYPE_PATH */
	int	refcount;	/* Reference count. */

	vect_f_list	*points;
	int		num_points;
	
	/* Index of, and pointer to, the point last accessed. */
	int		last_index;
	vect_f_list	*last_point;
	
	int	interp;		/* Linear, cosine, cubic, hermite, .. */
	int	closed;		/* Open or closed path. */
	int	outside;	/* Loop, clamp, or reverse. */
	int 	motion;		/* Normal, piecewise, constant. */
} Path;

void	 path_init(Path *path, int interp, int closed, int outside, int motion);
Path	*path_new(int type, int closed, int outside, int motion);
void	 path_destroy(Path *path);
void	 path_free(Path *path);

vect_f	 path_get(Path *path, int index);
void	 path_add(Path *path, vect_f p);
int	 path_interp(Path *path, float t, vect_f *result);

#endif /* PATH_H */
