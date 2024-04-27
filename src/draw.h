#ifndef DRAW_H
#define DRAW_H

#include "game2d.h"
#include "physics.h"

void    draw(Camera *cam);
void	draw_qtree(const QTree *tree);
void	draw_point(vect_f p);
void	draw_shape(const Shape *s);
void	draw_axes();
void	draw_BB(const BB *bb);
void	draw_quad(Camera *cam, BB *bb, float color[4]);
void	draw_text();

void	draw_tile(const Camera *cam, Tile *t);

#endif /* DRAW_H */
