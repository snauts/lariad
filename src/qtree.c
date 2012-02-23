#include <assert.h>
#include <math.h>
#include <stdlib.h>
#include "common.h"
#include "qtree.h"
#include "log.h"
#include "mem.h"
#include "uthash_tuned.h"
#include "utlist.h"

/*
 * Allocate new node and zero out its memory.
 */
static QTreeNode *
new_node()
{
	extern mem_pool mp_treenode;
	QTreeNode *node;

	node = mp_alloc(&mp_treenode);
	memset(node, 0, sizeof(*node));
	return node;
}

/*
 * Free node memory.
 */
static void
free_node(QTreeNode *node)
{
	extern mem_pool mp_treenode;
	
	/* Make sure this node is empty. */
	assert(node != NULL && node->num_objects == 0 && node->objects == NULL);
	assert(node->kids[0] == NULL && node->kids[1] == NULL &&
	    node->kids[2] == NULL && node->kids[3] == NULL);
	
	mp_free(&mp_treenode, node);
}

/*
 * Initialize quad tree.
 */
void
qtree_init(QTree *tree, uint levels)
{
	uint halfsize;
	
	assert(tree != NULL && levels > 0 && levels < 21);
	
	/* Create root node and initialize it. */
	tree->root = new_node();
	tree->root->size = 1 << levels;		/* size = 2^levels */
	tree->root->level = levels;
	halfsize = 1 << (levels-1);		/* halfsize = 2^(levels-1) */
	bb_init(&tree->root->bb, -halfsize, -halfsize, halfsize, halfsize);
}

/*
 * Remove objects from this node, destroy child nodes, and finally free node
 * memory.
 */
static void
destroy_node(QTreeNode *node)
{
	extern mem_pool mp_treeobjptr;
	int i, node_list_empty;
	QTreeObject *object;
	QTreeObjectPtr *object_ptr;
	
	/* Remove objects from node's object list. */
	while (node->objects) {
		/* Shorthand. */
		object_ptr = node->objects;
		object = object_ptr->object;
		
		/* First, remove node from object's node list. */
		node_list_empty = 1;
		for (i = 0; i < 4; i++) {
			if (object->_nodes[i] != NULL) {
				if (object->_nodes[i] == node)
					object->_nodes[i] = NULL;
				else
					node_list_empty = 0;
			}
		}
		
		/* If object's node list became empty, that means we can flag
		   object as not being part of partitioned space anymore. */
		if (node_list_empty)
			object->ptr = NULL;
		
		/* Remove object pointer from object list and free its memory.*/
		LL_DELETE(node->objects, object_ptr);
		mp_free(&mp_treeobjptr, object_ptr);
		node->num_objects--;
	}
	
	/* Destroy child nodes recursively. */
	for (i = 0; i < 4; i++) {
		if (node->kids[i] != NULL)
			destroy_node(node->kids[i]);
	}
	
	/* Free node memory. */
	free_node(node);
}

/*
 * Removes all objects from quad tree, destroys all nodes and frees their
 * memory.
 */
void
qtree_destroy(QTree *tree)
{
	/* Return to uninitialized state. */
	destroy_node(tree->root);
	tree->root = NULL;
}

/*
 * Add object to node (or recursively to its children).
 *
 * node		Node pointer.
 * object	QTreeObject pointer.
 * node_pos	Array of up to four node positions. These are the precalculated
 *		positions of nodes that object will be added to.
 * num_pos	Number of node positions in node_pos array.
 */
static void
add_object(QTreeNode *node, QTreeObject *object, vect_i *node_pos, uint num_pos)
{
	extern mem_pool mp_treeobjptr;
	uint i, j, halfsize, local_num_pos;
	BB child_bb, *node_bb;
	QTreeNode *child;
	QTreeObjectPtr *obj_ptr;
	vect_i local_node_pos[4];
	
	assert(node != NULL && object != NULL && object->_level <= node->level);
	assert(node_pos != NULL && num_pos > 0 && num_pos <= 4);
	
	/* Is this the node level that object is supposed to be at? */
	if (node->level == object->_level) {
		/* Only one node position must remain, and it should match the
		   bottom left orner position of current node bounding box. */
		assert(num_pos == 1 && node_pos[0].x == node->bb.l &&
		    node_pos[0].y == node->bb.b);
		
		/* Create new "object pointer" structure. */
		obj_ptr = mp_alloc(&mp_treeobjptr);
		obj_ptr->object = object;
		
		/* Prepend object pointer to node object list. */
		LL_PREPEND(node->objects, obj_ptr);
		node->num_objects++;
		
		/* Insert node pointer into object's node list. */
		for (i = 0; i < 4; i++) {
			if (object->_nodes[i] == NULL) {
				object->_nodes[i] = node;
				return;
			}
		}
		log_err("No free node slots.");
		abort();
	}
	
	/*
	 * Find which of the four child nodes intersect object bounding box.
	 *
	 * index 0 -- top left,
	 * index 1 -- bottom left,
	 * index 2 -- bottom right,
	 * index 3 -- top right
	 *
	 *    0 | 3
	 *    -----
	 *    1 | 2
	 */

	/* Shorthand. */
	node_bb = &node->bb;
	halfsize = node->size >> 1;

	/*
	 * Top left quad.
	 */
	
	child = node->kids[0];
	if (child != NULL) {
		child_bb = child->bb;
	} else {
		bb_init(&child_bb, node_bb->l, node_bb->b + halfsize,
		    node_bb->r - halfsize, node_bb->t);
	}
	/* Select node positions that fall within the child node. */
	local_num_pos = 0;
	for (i = 0; i < num_pos; i++) {
		if (node_pos[i].x < child_bb.r &&
		    node_pos[i].y >= child_bb.b) {
			local_node_pos[local_num_pos].x = node_pos[i].x;
			local_node_pos[local_num_pos].y = node_pos[i].y;
			local_num_pos++;
			
			/* Get rid of used node position from original array. */
			for (j = i+1; j < num_pos; j++)
				node_pos[j-1] = node_pos[j];
			num_pos--;
			i--;
		}
	}
	/* If child node contains any of the object nodes, go deeper. */
	if (local_num_pos > 0) {
		if (child == NULL) {
			/* Create child node. */
			child = new_node();
			child->bb = child_bb;
			child->level = node->level - 1;
			child->size = halfsize;
			child->parent = node;
			node->kids[0] = child;
		}
		/* Add object (recursively) to child node. */
		add_object(child, object, local_node_pos, local_num_pos);
	}
	
	/*
	 * Bottom left quad.
	 */
	
	child = node->kids[1];
	if (child != NULL) {
		child_bb = child->bb;
	} else {
		bb_init(&child_bb, node_bb->l, node_bb->b,
		    node_bb->r - halfsize, node_bb->t - halfsize);
	}
	/* Select node positions that fall within the child node. */
	local_num_pos = 0;
	for (i = 0; i < num_pos; i++) {
		if (node_pos[i].x < child_bb.r &&
		    node_pos[i].y < child_bb.t) {
			local_node_pos[local_num_pos].x = node_pos[i].x;
			local_node_pos[local_num_pos].y = node_pos[i].y;
			local_num_pos++;
			
			/* Get rid of used node position from original array. */
			for (j = i+1; j < num_pos; j++)
				node_pos[j-1] = node_pos[j];
			num_pos--;
			i--;
		}
	}
	/* If child node contains any of the object nodes, go deeper. */
	if (local_num_pos > 0) {
		if (child == NULL) {
			/* Create child node. */
			child = new_node();
			child->bb = child_bb;
			child->level = node->level - 1;
			child->size = halfsize;
			child->parent = node;
			node->kids[1] = child;
		}
		/* Add object (recursively) to child node. */
		add_object(child, object, local_node_pos, local_num_pos);
	}
	
	/*
	 * Bottom right quad.
	 */
	
	child = node->kids[2];
	if (child != NULL) {
		child_bb = child->bb;
	} else {
		bb_init(&child_bb, node_bb->l + halfsize, node_bb->b,
		    node_bb->r, node_bb->t - halfsize);
	}
	/* Select node positions that fall within the child node. */
	local_num_pos = 0;
	for (i = 0; i < num_pos; i++) {
		if (node_pos[i].x >= child_bb.l &&
		    node_pos[i].y < child_bb.t) {
			local_node_pos[local_num_pos].x = node_pos[i].x;
			local_node_pos[local_num_pos].y = node_pos[i].y;
			local_num_pos++;
			
			/* Get rid of used node position from original array. */
			for (j = i+1; j < num_pos; j++)
				node_pos[j-1] = node_pos[j];
			num_pos--;
			i--;
		}
	}
	/* If child node contains any of the object nodes, go deeper. */
	if (local_num_pos > 0) {
		if (child == NULL) {
			/* Create child node. */
			child = new_node();
			child->bb = child_bb;
			child->level = node->level - 1;
			child->size = halfsize;
			child->parent = node;
			node->kids[2] = child;
		}
		/* Add object (recursively) to child node. */
		add_object(child, object, local_node_pos, local_num_pos);
	}
	
	/*
	 * Top right quad.
	 */
	
	child = node->kids[3];
	if (child != NULL) {
		child_bb = child->bb;
	} else {
		bb_init(&child_bb, node_bb->l + halfsize, node_bb->b + halfsize,
		    node_bb->r, node_bb->t);
	}
	/* Select node positions that fall within the child node. */
	local_num_pos = 0;
	for (i = 0; i < num_pos; i++) {
		if (node_pos[i].x >= child_bb.l &&
		    node_pos[i].y >= child_bb.b) {
			local_node_pos[local_num_pos].x = node_pos[i].x;
			local_node_pos[local_num_pos].y = node_pos[i].y;
			local_num_pos++;
			
			/* Get rid of used node position from original array. */
			for (j = i+1; j < num_pos; j++)
				node_pos[j-1] = node_pos[j];
			num_pos--;
			i--;
		}
	}
	/* If child node contains any of the object nodes, go deeper. */
	if (local_num_pos > 0) {
		if (child == NULL) {
			/* Create child node. */
			child = new_node();
			child->bb = child_bb;
			child->level = node->level - 1;
			child->size = halfsize;
			child->parent = node;
			node->kids[3] = child;
		}
		/* Add object (recursively) to child node. */
		add_object(child, object, local_node_pos, local_num_pos);
	}
	
	assert(num_pos == 0);		/* All nodes must be used. */
}

/*
 * Add an object to quad tree.
 *
 * tree		The tree.
 * object	Object that is going to be added to the quad tree.
 *		Don't forget to set the bounding box member (bb), so that
 *		qtree_add() would know where in the tree this object is supposed
 *		to go.
 */
void
qtree_add(QTree *tree, QTreeObject *object)
{
	int left, right, bottom, top;
	uint obj_size, node_size, num_pos;
	BB *root_bb;
	vect_i node_pos[4];
	
	/* Basic sanity. */
	assert(tree != NULL && tree->root != NULL);
	assert(object != NULL && object->ptr != NULL);
	assert(!object->stored && !object->_visited);
	assert(object->_level == (uint)-1);
	assert(object->_nodes[0] == NULL && object->_nodes[1] == NULL &&
	    object->_nodes[2] == NULL && object->_nodes[3] == NULL);
	
	/* Shorthand. */
	root_bb = &tree->root->bb;
	assert(bb_valid(*root_bb) && bb_valid(object->bb));
	left = object->bb.l;
	right = object->bb.r;
	bottom = object->bb.b;
	top = object->bb.t;
	
#ifndef NDEBUG
	/* Make sure object bounding box fits inside root node. */
	if (left < root_bb->l || right > root_bb->r ||
	    bottom < root_bb->b || top > root_bb->t) {
		log_err("Object (%p) with bounding box {l=%i,r=%i,b=%i,t=%i} "
		    "is outside partitioned space {l=%i,r=%i,b=%i,t=%i}. Did "
		    "something fall through the floor? Maybe tree depth "
		    "argument of eapi.NewWorld() should be increased?", object,
		    left, right, bottom, top, root_bb->l, root_bb->r,
		    root_bb->b, root_bb->t);
		abort();
	}
#endif

	/* Calculate at which node level object should be inserted. */
	object->_level = 0;
	node_size = 1;
	obj_size = MAX2(right - left, top - bottom);
	while (node_size < obj_size) {
		node_size <<= 1;	/* 1, 2, 4, 8, 16, .. */
		object->_level++;
	}
	
	/* Calculate positions of nodes (at the selected level) that object will
	   be added to. */
	left = (left < 0) ? -((-left-1)/node_size)-1 : left/node_size;
	right = (right <= 0) ? -(-right/node_size)-1 : (right-1)/node_size;
	bottom = (bottom < 0) ? -((-bottom-1)/node_size)-1 : bottom/node_size;
	top = (top <= 0) ? -(-top/node_size)-1 : (top-1)/node_size;
	assert(right >= left && top >= bottom);
	
	/* Create an array containing (up to 4) new node positions. */
	node_pos[0].x = left * node_size;
	node_pos[0].y = bottom * node_size;
	num_pos = 1;
	if (left != right) {
		node_pos[1].x = right * node_size;
		node_pos[1].y = bottom * node_size;
		num_pos = 2;
		if (bottom != top) {
			node_pos[2].x = left * node_size;
			node_pos[2].y = top * node_size;
			node_pos[3].x = right * node_size;
			node_pos[3].y = top * node_size;
			num_pos = 4;
		}
	} else if (bottom != top) {
		node_pos[1].x = left * node_size;
		node_pos[1].y = top * node_size;
		num_pos = 2;
	}
	
	/* Recursive tree traversal to add object to nodes. */
	add_object(tree->root, object, node_pos, num_pos);
	
	/* Verify that it was really added and set "stored" flag. */
	assert(object->_nodes[0] != NULL || object->_nodes[1] != NULL ||
	    object->_nodes[2] != NULL || object->_nodes[3] != NULL);
	object->stored = 1;
}

static void
remove_node_if_empty(QTreeNode *node)
{
	int i;
	QTreeNode *parent;

	if (node->objects != NULL || node->kids[0] != NULL ||
	    node->kids[1] != NULL || node->kids[2] != NULL ||
	    node->kids[3] != NULL || node->parent == NULL)
		return;		/* Not empty or root node. */
	
	/* Find node in parent's child list and remove it from there. */
	parent = node->parent;
	for (i = 0; i < 4; i++) {
		if (parent->kids[i] == node) {
			parent->kids[i] = NULL;
			break;
		}
	}
	assert(i != 4);		/* Node should have been in the list. */
	
	/* Free node memory. */
	free_node(node);
	
	/* Now remove (recursively) parent node if it is empty. */
	remove_node_if_empty(parent);
}

static void
remove_object_from_nodes(QTreeObject *object, QTreeNode *nodes[])
{
	extern mem_pool mp_treeobjptr;
	int i;
	QTreeNode *node;
	QTreeObjectPtr *object_ptr;
	
	/* Remove object from each node that it's been added to. */
	for (i = 0; i < 4; i++) {
		node = nodes[i];
		if (node == NULL)
			continue;		/* Empty slot. */
		nodes[i] = NULL;
		
		/* Remove object from node's object pointer list. */
		for (object_ptr = node->objects; object_ptr != NULL;
		    object_ptr = object_ptr->next) {
			if (object_ptr->object == object) {
				LL_DELETE(node->objects, object_ptr);
				mp_free(&mp_treeobjptr, object_ptr);
				node->num_objects--;
				break;
			}
		}
		assert(object_ptr != NULL); /* Should have been in the list. */
		remove_node_if_empty(node);
	}
}

/*
 * Convoluted set-based logic.
 */
static inline void
handle_new_node_pos(vect_i node_pos, QTreeNode *obj_nodes[],
    QTreeNode *common[], uint *num_common, vect_i new_node_pos[],
    uint *num_new_pos)
{
	int i;
	QTreeNode *node;
	
	for (i = 0; i < 4; i++) {
		node = obj_nodes[i];
		if (node != NULL && node->bb.l == node_pos.x &&
		    node->bb.b == node_pos.y) {
			common[(*num_common)++] = obj_nodes[i];
			obj_nodes[i] = NULL;
			break;
		}
	}
	if (i == 4)
		new_node_pos[(*num_new_pos)++] = node_pos;
}

void
qtree_update(QTree *tree, QTreeObject *object)
{
	int left, right, bottom, top, i;
	uint obj_size, node_size, num_new_pos, num_obj_nodes, new_level;
	BB *root_bb;
	vect_i new_node_pos[4], newpos;
	QTreeNode *remove_from[4];
	
	/* Basic sanity. */
	assert(tree != NULL && tree->root != NULL);
	assert(object != NULL && object->ptr != NULL);
	assert(object->stored && !object->_visited);
	assert(object->_level <= tree->root->level);
	assert(object->_nodes[0] != NULL || object->_nodes[1] != NULL ||
	    object->_nodes[2] != NULL || object->_nodes[3] != NULL);
	
	/* Shorthand. */
	root_bb = &tree->root->bb;
	assert(bb_valid(*root_bb) && bb_valid(object->bb));
	left = object->bb.l;
	right = object->bb.r;
	bottom = object->bb.b;
	top = object->bb.t;
	
#ifndef NDEBUG
	/* Make sure object bounding box fits inside root node. */
	if (left < root_bb->l || right > root_bb->r ||
	    bottom < root_bb->b || top > root_bb->t) {
		log_err("Object (%p) with bounding box {l=%i,r=%i,b=%i,t=%i} "
		    "is outside partitioned space {l=%i,r=%i,b=%i,t=%i}. Did "
		    "something fall through the floor? Maybe tree depth "
		    "argument of eapi.NewWorld() should be increased?", object,
		    left, right, bottom, top, root_bb->l, root_bb->r,
		    root_bb->b, root_bb->t);
		abort();
	}
#endif

	/* Calculate at which node level object should be inserted. */
	new_level = 0;
	node_size = 1;
	obj_size = MAX2(right - left, top - bottom);
	while (node_size < obj_size) {
		node_size <<= 1;	/* 1, 2, 4, 8, 16, .. */
		new_level++;
	}
	
	/* Calculate positions of nodes (at the selected level) that object
	   should belong to after we're done with this routine. */
	left = (left < 0) ? -((-left-1)/node_size)-1 : left/node_size;
	right = (right <= 0) ? -(-right/node_size)-1 : (right-1)/node_size;
	bottom = (bottom < 0) ? -((-bottom-1)/node_size)-1 : bottom/node_size;
	top = (top <= 0) ? -(-top/node_size)-1 : (top-1)/node_size;
	assert(right >= left && top >= bottom);
	
	/* Save the nodes that object belongs to presently. We'll remove the
	    object from these nodes later. Also clear object's node list. */
	memcpy(remove_from, object->_nodes, sizeof(object->_nodes));
	memset(object->_nodes, 0, sizeof(object->_nodes));
	
	if (object->_level != new_level) {
		/*
		 * Since object ends up being on another tree level, the
		 * handling is simple: add to new nodes, and then remove from
		 * old nodes.
		 */
		
		/* Create an array containing (up to 4) new node positions. */
		new_node_pos[0].x = left * node_size;
		new_node_pos[0].y = bottom * node_size;
		num_new_pos = 1;
		if (left != right) {
			new_node_pos[1].x = right * node_size;
			new_node_pos[1].y = bottom * node_size;
			num_new_pos = 2;
			if (bottom != top) {
				new_node_pos[2].x = left * node_size;
				new_node_pos[2].y = top * node_size;
				new_node_pos[3].x = right * node_size;
				new_node_pos[3].y = top * node_size;
				num_new_pos = 4;
			}
		} else if (bottom != top) {
			new_node_pos[1].x = left * node_size;
			new_node_pos[1].y = top * node_size;
			num_new_pos = 2;
		}
		
		/* Recursive tree traversal to add object to new nodes. */
		object->_level = new_level;
		add_object(tree->root, object, new_node_pos, num_new_pos);
		
		/* Remove object from nodes it was previously stored in. */
		remove_object_from_nodes(object, remove_from);
		
		/* Verify that object is still in the tree. */
		assert(object->_nodes[0] != NULL || object->_nodes[1] != NULL ||
		    object->_nodes[2] != NULL || object->_nodes[3] != NULL);
		return;
	}
	
	/* Create an array containing (up to 4) new node positions. */
	num_new_pos = 0;
	num_obj_nodes = 0;
	newpos.x = left * node_size;
	newpos.y = bottom * node_size;
	handle_new_node_pos(newpos, remove_from, object->_nodes, &num_obj_nodes,
	    new_node_pos, &num_new_pos);
	if (left != right) {
		newpos.x = right * node_size;
		newpos.y = bottom * node_size;
		handle_new_node_pos(newpos, remove_from, object->_nodes,
		    &num_obj_nodes, new_node_pos, &num_new_pos);
		if (bottom != top) {
			newpos.x = left * node_size;
			newpos.y = top * node_size;
			handle_new_node_pos(newpos, remove_from, object->_nodes,
			    &num_obj_nodes, new_node_pos, &num_new_pos);
			
			newpos.x = right * node_size;
			newpos.y = top * node_size;
			handle_new_node_pos(newpos, remove_from, object->_nodes,
			    &num_obj_nodes, new_node_pos, &num_new_pos);
		}
	} else if (bottom != top) {
		newpos.x = left * node_size;
		newpos.y = top * node_size;
		handle_new_node_pos(newpos, remove_from, object->_nodes,
		    &num_obj_nodes, new_node_pos, &num_new_pos);
	}
	
	if (num_new_pos > 0) {
		/* Recursive tree traversal to add object to new nodes. */
		add_object(tree->root, object, new_node_pos, num_new_pos);
	}
	
	/* Remove object from nodes it was previously stored in (if any). */
	remove_object_from_nodes(object, remove_from);
	
#ifndef NDEBUG
	/* Verify that object is still in the tree. */
	assert(object->_nodes[0] != NULL || object->_nodes[1] != NULL ||
	    object->_nodes[2] != NULL || object->_nodes[3] != NULL);
	
	/* Verify that unchanged nodes + new nodes == current number of object
	   nodes. */
	uint total = 0;
	for (i = 0; i < 4; i++) {
		if (object->_nodes[i] != NULL)
			total++;
	}
	assert(total == num_obj_nodes + num_new_pos);
#endif
}

/*
 * Remove object from quad tree.
 */
void
qtree_remove(QTree *tree, QTreeObject *object)
{
	assert(tree != NULL && tree->root != NULL);
	assert(object != NULL && object->ptr != NULL);
	assert(object->stored && !object->_visited);
	assert(object->_nodes[0] != NULL || object->_nodes[1] != NULL ||
	    object->_nodes[2] != NULL || object->_nodes[3] != NULL);
	
	/* Remove object from its nodes. */
	remove_object_from_nodes(object, object->_nodes);
	
	/* Unset "stored" flag since this object is no longer stored within the
	   quad tree. Also set level to -1 for the same purpose. */
	object->stored = 0;
	object->_level = (uint)-1;
}

/*
 * Append this node's objects to lookup array, and the objects of any of this
 * node's children if they intersect requested bounding box.
 *
 * node		Node whose objects will be added to result array. Routine
 *		proceeds recursively down into child nodes if they overlap
 *		provided bounding box.
 * bb		We're looking for nodes that overlap this bounding box. If NULL,
 *		all child node objects are added unconditionally.
 * lookup	Result array of tree objects.
 * max_results	Max size of result array.
 * num_results	Number of objects added to lookup array.
 *
 * Returns codes:
 *	0 -- success, everything went as expected.
 *	1 -- number of found objects exceeds max_results. Resulting lookup array
 *		will be truncated.
 */
static int
lookup_objects(QTreeNode *node, const BB *bb, QTreeObject **lookup,
    uint max_results, uint *num_results)
{
	int i;
	BB *child_bb;
	QTreeNode *child;
	QTreeObject *object;
	QTreeObjectPtr *object_ptr;
	
	/* Add this node's objects to lookup array. */
	for (object_ptr = node->objects; object_ptr != NULL;
	    object_ptr = object_ptr->next) {
		object = object_ptr->object;
		assert(object != NULL && object->ptr != NULL);
		if (object->_visited)
			continue;	/* Object has been already added. */
		
		/* Append object to lookup array. */
		if (*num_results >= max_results)
			return 1;
		lookup[(*num_results)++] = object;
		
		/*
		 * Set "visited" flag so that we know that this object has
		 * already been added to lookup object array. Remember that an
		 * object can exist simultaneously in up to four nodes, so we
		 * must do this in order to not have duplicates.
		 */
		object->_visited = 1;
	}
	
	/* If no bounding box provided, add child node objects
	   unconditionally. */
	if (bb == NULL) {
		for (i = 0; i < 4; i++) {
			child = node->kids[i];
			if (child != NULL) {
				if (lookup_objects(child, NULL, lookup, max_results,
				    num_results) != 0)
					return 1;
			}
		}
		return 0;
	}
	
	/* Process child nodes. */
	for (i = 0; i < 4; i++) {
		child = node->kids[i];
		if (child == NULL)
			continue;	/* Ignore empty slot. */
		child_bb = &child->bb;
		if (!bb_overlap(bb, child_bb))
			continue;	/* No intersection with child node. */
		if (child_bb->l >= bb->l && child_bb->b >= bb->b &&
		    child_bb->r <= bb->r && child_bb->t <= bb->t) {
			/* Bounding box completely encloses child node. Add its
			   objects and the objects of further child nodes
			   unconditionally. */
			if (lookup_objects(child, NULL, lookup, max_results,
			    num_results) != 0)
				return 1;
			continue;
		}
		
		/* Child node intersects requested bounding box. But since it
		   it does not fall entirely within it, we pass requested
		   bounding box as argument. */
		if (lookup_objects(child, bb, lookup, max_results, num_results) != 0)
			return 1;
	}
	return 0;
}

/*
 * Look up objects from the tree that fall into the provided bounding box.
 *
 * tree		The quad tree that's used for lookups.
 * bb		Get objects located in area specified by this bounding box.
 * result	Add found objects to this array.
 * max_results	Size of "result" array (i.e., how many objects can be inserted
 *		into it).
 * num_results	After lookup is done, the variable that this points to will be
 *		set to the actual number of objects that were found during
 *		lookup.
 *
 * Return values:
 * 	0 -- success, everything went as expected.
 *	1 -- number of found objects exceeds max_results. Resulting lookup array
 *		will be truncated.
 */
int
qtree_lookup(const QTree *tree, const BB *bb, QTreeObject **result,
    uint max_results, uint *num_results)
{
	int stat;
	uint i;
	BB *root_bb;

	assert(tree != NULL && tree->root != NULL);
	assert(bb != NULL && bb_valid(*bb));
	assert(result != NULL && num_results != NULL);
	
	/* If we don't intersect root node bounding box, then no need to bother
	   looking anything up. */
	*num_results = 0;
	root_bb = &tree->root->bb;
	if (!bb_overlap(bb, root_bb))
		return 0;
	
	/* Perform recursive lookup. */
	stat = lookup_objects(tree->root, bb, result, max_results, num_results);
	
	/* Set visited flag for found objects to zero. */
	for (i = 0; i < *num_results; i++) {
		result[i]->_visited = 0;
	}
	return stat;
}

/*
 * Initialize a QTreeObject structure.
 */
void
qtree_obj_init(QTreeObject *object, void *ptr)
{
	assert(object != NULL && ptr != NULL);
	memset(object, 0, sizeof(*object));
	object->ptr = ptr;
	object->_level = (uint)-1;
}
