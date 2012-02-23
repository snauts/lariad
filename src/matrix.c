#include <assert.h>
#include <math.h>
#include <stdlib.h>
#include "common.h"
#include "compat.h"
#include "matrix.h"

/*
 * Since columns are contiguous in memory in our chosen representation, rows
 * here are actually columns, not that it matters for the identity matrix.
 */
static Matrix identity_matrix = {{
	1.0, 0.0, 0.0, 0.0,
	0.0, 1.0, 0.0, 0.0,
	0.0, 0.0, 1.0, 0.0,
	0.0, 0.0, 0.0, 1.0
}};

/*
 * Set matrix to identity.
 */
void
m_identity(Matrix *m)
{
	assert(m != NULL);
	*m = identity_matrix;
}

/*
 * Create translation matrix.
 */
void
m_set_translate(Matrix *m, const float v[4])
{
	assert(m != NULL && v != NULL);
	m_identity(m);
	MP(m, 0, 3) = v[0];
	MP(m, 1, 3) = v[1];
	MP(m, 2, 3) = v[2];
}

/*
 * Set matrix [m] to the rotation matrix about Z axis by [angle] radians. The
 * rotation will be counterclockwise if you think of the axis as coming toward
 * you.
 */
void
m_set_rotZ(Matrix *m, float angle)
{
	assert(m != NULL);
	m_identity(m);
	MP(m, 0, 0) = cosf(angle);
	MP(m, 0, 1) = -sinf(angle);
	MP(m, 1, 0) = sinf(angle);
	MP(m, 1, 1) = cosf(angle);
}

#if 0
/*
 * Set matrix to a stretch transform.
 *
 * m		Matrix that will contain the tranformation.
 * p		This vector will determine the length of the stretch: it is a
 *		vector that, unlike most others, will only be *translated* by
 *		the vector v, and *not scaled*.
 *		This way of specifying the stretch is used so you can choose a
 *		specific point [p] that you know should go to (p + s), and the
 *		rest of the points will then be transformed according to that.
 * s		Stretch vector.
 */
void
m_set_stretch(Matrix *m, const Vector *p, const Vector *s)
{
	float Q;

	assert(m != NULL && p != NULL && s != NULL && p != s);
	m_identity(m);

	/*
	 * If dot(p, s) is zero, it means either that that [s] is zero (i.e., no
	 * stretching), or that the origin must be stretched to some other point
	 * (impossible). We ignore both of these cases by setting [Q] to 1.
	 */
	Q = v_dot(p, s);
	if (fabs(Q) < EPSILON8)
		Q = 1.0;
	
	MP(m, 0, 0) = 1.0 + XP(s)*XP(s)/Q;
	MP(m, 0, 1) = XP(s)*YP(s)/Q;
	MP(m, 0, 2) = XP(s)*ZP(s)/Q;
	MP(m, 1, 0) = XP(s)*YP(s)/Q;
	MP(m, 1, 1) = 1.0 + YP(s)*YP(s)/Q;
	MP(m, 1, 2) = YP(s)*ZP(s)/Q;
	MP(m, 2, 0) = XP(s)*ZP(s)/Q;
	MP(m, 2, 1) = YP(s)*ZP(s)/Q;
	MP(m, 2, 2) = 1.0 + ZP(s)*ZP(s)/Q;
}
#endif

/*
 * Apply translation to matrix.
 */
void
m_translate(Matrix *m, const float v[4])
{
	Matrix tmp;

	assert(m != NULL && v != NULL);
	m_set_translate(&tmp, v);
	m_mult(m, &tmp);
}

/*
 * Apply rotation transform by [angle] radians around Z axis.
 */
void
m_rotZ(Matrix *m, float angle)
{
	Matrix tmp;

	assert(m != NULL);
	m_set_rotZ(&tmp, angle);
	m_mult(m, &tmp);
}

/*
 * Rotate around a specified point.
 * XXX untested
 */
void
m_rotZ_at(Matrix *m, float angle, const float c[4])
{
	assert(m != NULL && c != NULL);
	m_translate(m, c);
	m_rotZ(m, angle);

	float c_rev[4] = {-c[0], -c[1], -c[2], c[3]};
	m_translate(m, c_rev);
}

#if 0
/*
 * Apply stretch transformation to matrix [m]. See m_set_strech() for
 * explanation of the other two arguments.
 */
void
m_stretch(Matrix *m, const float p[4], const float s[4])
{
	Matrix tmp;

	assert(m != NULL && p != NULL && s != NULL && p != s);
	m_set_stretch(&tmp, p, s);
	m_mult(m, &tmp);
}

/*
 * Stretch transform performed as if point [c] was the stationary center of the
 * coordinate system; i.e., translating to it, stretching, then translating
 * back. Note that it makes no sense for [p] and [c] to be the same point, since
 * stretching the origin is impossible. The routine, however, tolerates this and
 * does nothing in this case for the sake of some convenience for the calling
 * code.
 */
void
m_stretch_at(Matrix *m, const float p[4], const float s[4], const float c[4])
{
	Vector c_rev, p_trans;
	
	assert(m != NULL && p != NULL && s != NULL && c != NULL);
	assert(p != s && s != c);

	/* Translate [p] into the space that will be stretched. */
	v_reverse_cpy(c, &c_rev);
	v_add(p, &c_rev, &p_trans);

	/* Translate, stretch, translate back. */
	m_translate(m, c);
	m_stretch(m, &p_trans, s);
	m_translate(m, &c_rev);
}
#endif

/*
 * Multiply two matrices; store result in [a].
 */
void
m_mult(Matrix *a, const Matrix *b)
{
	float ai0, ai1, ai2, ai3;	
	assert(a != NULL && b != NULL && a != b);
	for (int i = 0; i < 4; i++) {
		ai0 = MP(a, i, 0);
		ai1 = MP(a, i, 1);
		ai2 = MP(a, i, 2);
		ai3 = MP(a, i, 3);

		MP(a, i, 0) = ai0*MP(b, 0, 0) + ai1*MP(b, 1, 0) +
		    ai2*MP(b, 2, 0) + ai3*MP(b, 3, 0);
		MP(a, i, 1) = ai0*MP(b, 0, 1) + ai1*MP(b, 1, 1) +
		    ai2*MP(b, 2, 1) + ai3*MP(b, 3, 1);
		MP(a, i, 2) = ai0*MP(b, 0, 2) + ai1*MP(b, 1, 2) +
		    ai2*MP(b, 2, 2) + ai3*MP(b, 3, 2);
		MP(a, i, 3) = ai0*MP(b, 0, 3) + ai1*MP(b, 1, 3) +
		    ai2*MP(b, 2, 3) + ai3*MP(b, 3, 3);
	}
}

/*
 * Multiply each member of [m] with the floating point number [f].
 */
void
m_multf(Matrix *m, float f)
{
	assert(m != NULL);
	for (int i = 0; i < 16; i++)
		m->val[i] *= f;
}
