#include <assert.h>
#include <stdlib.h>
#include <stdarg.h>
#include <string.h>
#include <math.h>
#include <limits.h>
#include "geometry.h"

vect_f
vect_f_new(double x, double y)
{
	vect_f v = {x, y};
	return v;
}

vect_f
vect_f_add(vect_f a, vect_f b)
{
	vect_f result = {a.x + b.x, a.y + b.y};
	return result;
}

vect_f
vect_f_sub(vect_f a, vect_f b)
{
	vect_f result = {a.x - b.x, a.y - b.y};
	return result;
}

vect_f
vect_f_scale(vect_f a, double f)
{
	vect_f result = {a.x*f, a.y*f};
	return result;
}

int
vect_f_equal(vect_f a, vect_f b)
{
	return a.x == b.x && a.y == b.y;
}

vect_f
vect_f_round(vect_f v)
{
	vect_f result = {round(v.x), round(v.y)};
	return result;
}

vect_f
vect_f_neg(vect_f v)
{
	vect_f result = {-v.x, -v.y};
	return result;
}

double
vect_f_dot(vect_f a, vect_f b)
{
	return a.x*b.x + a.y*b.y;
}

vect_f
vect_f_rotate(const vect_f *a, float theta)
{
	float cs = cos(theta);
	float sn = sin(theta);
	return (vect_f) { a->x * cs - a->y * sn, 
			  a->x * sn + a->y * cs };
}

void
bb_init(BB *bb, int l, int b, int r, int t)
{
	bb->l = l;
	bb->t = t;
	bb->r = r;
	bb->b = b;
}

void
bb_add_vect(BB *bb, int x, int y)
{
	bb->l += x;
	bb->b += y;
	bb->r += x;
	bb->t += y;
}

/*
 * Return true if bounding boxes intersect, false otherwise.
 */
int
bb_overlap(const BB *A, const BB *B)
{
	if (A->l >= B->r || A->r <= B->l || A->b >= B->t || A->t <= B->b)
		return 0;
	return 1;
}

/*
 * Pick smallest integer from all the arguments and return it.
 *
 * n		Number of int arguments.
 * ...		n integer numbers.
 */
static int
min_i(int n, ...)
{
	int i, min_value;
	va_list ap;

	min_value = INT_MAX;
	va_start(ap, n);
	while (n--) {
		i = va_arg(ap, int);
		if (i < min_value)
			min_value = i;
	}
	va_end(ap);
	return min_value;
}

/*
 * Intersection area of two axis-aligned bounding boxes. Negative if they do not
 * intersect.
 */
int
bb_overlap_area(const BB *a, const BB *b)
{
	int wi, hi;
	
	assert(a != NULL && bb_valid(*a));
	assert(b != NULL && bb_valid(*b));

	wi = min_i(4, a->r - b->l, b->r - a->l, a->r - a->l, b->r - b->l);
	hi = min_i(4, a->t - b->b, b->t - a->b, a->t - a->b, b->t - b->b);
	return (wi < 0.0 || hi < 0.0) ? -abs(wi * hi) : wi * hi;
}

/*
 * What can be done to move box [b] out of box [a]? The result is stored in
 * bounding box pointed to by [resolve]. The result isn't really a valid
 * bounding box, but just four values -- distances in each of the four
 * directions (left, bottom, right, top) that can be added to box [b] in order
 * to move it out of intersection state.
 * The actual return value of the function is a boolean -- 0 if the two boxes
 * do not intersect, 1 if they do. Note that a positive result (1) is also
 * returned if the boxes only touch, but do not overlap.
 */
int
bb_intersect_resolve(const BB *a, const BB *b, BB *resolve)
{	
	assert(resolve != NULL);
	assert(a != NULL && bb_valid(*a));
	assert(b != NULL && bb_valid(*b));
		
	resolve->t = a->t - b->b;	/* Upward resolution distance. */
	resolve->r = a->r - b->l;	/* Resolution distance to the left. */
	if (resolve->t < 0 || resolve->t > (a->t - a->b) + (b->t - b->b) ||
	    resolve->r < 0 || resolve->r > (a->r - a->l) + (b->r - b->l)) {
		memset(resolve, 0, sizeof(*resolve));
		return 0; /* No intersection. */
	}
		
	resolve->b = a->b - b->t;	/* Downward resolution distance. */
	resolve->l = a->l - b->r;	/* Resolution distance to the right. */	
	return 1;
}
