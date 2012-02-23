#ifndef QTREE_H
#define QTREE_H

#include "geometry.h"
#include "mem.h"
#include "uthash.h"

struct QTreeNode_t;

/*
 * Quad tree object. This is what can be inserted into the tree.
 */
typedef struct {
	void		*ptr;		/* Pointer to something, usually the
					   structure that contains this
					   QTreeObject. */
	BB		bb;		/* Object bounding box. Based on this,
					   we determine where in the tree the
					   object should go. */
	int		stored;		/* Read-only attribute. Will be set if
					   this object is stored inside quad
					   tree. */

	/* "Private" members below. */
	struct QTreeNode_t *_nodes[4];	/* List of pointers to nodes that this
					   object belongs to. */
	uint		_level;		/* Tree level where object exists in. */
	int		_visited;	/* Flag used by lookup routines. If set,
					   object has already been added to
					   resulting object lookup array. */
} QTreeObject;

typedef struct QTreeObjectPtr_t {
	QTreeObject		*object;
	struct QTreeObjectPtr_t	*next;
} QTreeObjectPtr;

/*
 * Quad tree node.
 */
typedef struct QTreeNode_t {
	QTreeObjectPtr	*objects;
	uint		num_objects;
	BB		bb;
	uint		level;
	uint		size;
	struct QTreeNode_t *parent;
	struct QTreeNode_t *kids[4];
} QTreeNode;

/*
 * Top structure of quad tree.
 */
typedef struct {
	QTreeNode	*root;
} QTree;

void	qtree_init(QTree *tree, uint levels);
void	qtree_destroy(QTree *tree);

void	qtree_obj_init(QTreeObject *obj, void *ptr);

void	qtree_add(QTree *tree, QTreeObject *object);
void	qtree_remove(QTree *tree, QTreeObject *object);
void	qtree_update(QTree *tree, QTreeObject *object);

int	qtree_lookup(const QTree *tree, const BB *bb, QTreeObject **result,
	    uint max_results, uint *num_results);

#endif /* QTREE_H */
