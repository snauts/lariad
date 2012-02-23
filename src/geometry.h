#ifndef GEOM_H
#define GEOM_H

/*
 * Two dimensional floating point vector.
 */
typedef struct {
	double x, y;
} vect_f;

/*
 * Two dimensional integer vector.
 */
typedef struct {
	int x, y;
} vect_i;

/*
 * Wrapper for vect_f so it can be added to lists.
 */
typedef struct vect_f_list_t {
	vect_f v;
	struct vect_f_list_t *prev, *next;
} vect_f_list;

vect_f_list	*listvect_new(vect_f v);
void		 listvect_free(vect_f_list *);

/* 
 * Rectangle specified by integer edge offsets from origin.
 */
typedef struct {
	int l, b, r, t;	/* Left, top, right, bottom. */
} BB;

/*
 * Circle specified by radius and offset.
 */
typedef struct {
	unsigned int radius;
	vect_i offset;
} Circle;

/* Bounding box sanity (physical world, not texture). */
#define bb_valid(bb) ((bb).l < (bb).r && (bb).b < (bb).t)

int	bb_overlap_area(const BB *a, const BB *b);
int	bb_overlap(const BB *a, const BB *b);
int	bb_intersect_resolve(const BB *a, const BB *b, BB *resolve);
void	bb_init(BB *bb, int l, int b, int r, int t);
void	bb_add_vect(BB *bb, int x, int y);

vect_f	vect_f_new(double x, double y);
vect_f	vect_f_add(vect_f a, vect_f b);
vect_f	vect_f_sub(vect_f a, vect_f b);
vect_f	vect_f_scale(vect_f a, double f);
double	vect_f_dot(vect_f a, vect_f b);
int	vect_f_equal(vect_f a, vect_f b);
vect_f	vect_f_round(vect_f v);
vect_f	vect_f_neg(vect_f v);
vect_f  vect_f_rotate(const vect_f *a, float theta);

static const vect_f vect_f_zero = {0.0, 0.0};

#endif /* GEOM_H */

