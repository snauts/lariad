#ifndef MATRIX_H
#define MATRIX_H

/*
 * 4x4 matrix type: an array of sixteen floats. All matrix operations assume
 * matrices are stored in column major order:
 *
 * |0  4  8  12|
 * |1  5  9  13|
 * |2  6  10 14|
 * |3  7  11 15|
 */
typedef struct {
	float val[16];
} Matrix;

/* Matrix element access. */
#define M(matrix, r, c)		(matrix).val[(r) + (c)*4]
#define MP(matrix, r, c)	(matrix)->val[(r) + (c)*4]

/*
 * Matrix routines.
 */

void	m_identity(Matrix *m);

void	m_set_translate(Matrix *m, const float v[4]);
void	m_set_rotZ(Matrix *m, float angle);

void	m_translate(Matrix *m, const float v[4]);
void	m_rotZ(Matrix *m, float angle);
void	m_rotZ_at(Matrix *m, float angle, const float c[4]);

void	m_mult(Matrix *m, const Matrix *m2);
void	m_mult_cpy(const Matrix *m1, const Matrix *m2, Matrix *result);
void	m_multf(Matrix *m, float f);

#endif /* VECTOR_H */
