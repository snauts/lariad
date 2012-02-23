#ifndef MEM_H
#define MEM_H

#include "common.h"

#define MEM_MAX_BLOCKS 2
#define MEM_MAX_NAMELEN 100

#ifndef NDEBUG
/*
 * With Linux libc > 5.4.23, this will guard against simple errors, such as
 * repeat calls to free().
 */
#define MALLOC_CHECK_ 3
#endif /* Debug mode. */

/*
 * The memory module defines memory pools; their use hopefully speeds things up
 * and saves some memory when lots of small object allocations happen. Some
 * other benefits include: ability to iterate over all allocated structures,
 * memory use statistics, ability to free everything that's in the pool in one
 * go.
 *
 * A pool, in this implementation, is a sequence of contiguous "cells" of memory
 * that form a linked list. All cells have the same size that is equal to the
 * size of the record they can hold plus space for two pointers: to next and
 * previous cell. Alloc()ed cells are removed from the beginning of the list;
 * free()d cells are returned to the end of the list (the list only contains
 * free cells). Both operations are O(1).
 *
 * Blocks are groups of cells. When no free cells from existing blocks remain, a
 * new block is allocated and used. Up to two blocks are supported for a memory
 * pool. More would just seem like a bad initial estimate though the maximum
 * number of blocks is configurable.
 */

/*
 * Memory pool structure.
 */
typedef struct {
	uint	cell_size;	/* Size of one cell. */
	uint	num_cells;	/* Number of cells in one block. */
	uint	num_blocks;	/* Number of allocated blocks. */
	void	*blocks[MEM_MAX_BLOCKS];	/* Block addresses. */
	void	*free_cells;	/* Beginning of free cell list. */
	void	*free_cells_last; /* Last cell in free cell list. */
	void	*inuse_cells;	/* Beginning of allocated cell list. */
	char name[MEM_MAX_NAMELEN];	/* A short description of what's
					   in the pool. */

	/* Allocation statistics. */
	uint	stat_current;	/* Number of currently allocated cells. */
	uint	stat_alloc;	/* Number of mp_alloc() calls for this pool. */
	uint	stat_free;	/* Number of mp_free() calls for this pool. */
	uint	stat_peak;	/* Peak number of allocated cells. */
} mem_pool;

#define mem_pool_valid(mp) ((mp) != NULL && (mp)->cell_size > 0 &&	\
	(mp)->num_cells > 0 && (mp)->num_blocks > 0)

/* Standard allocation with some error checking. */
void	*mem_alloc(uint size, const char *descr);
void	 mem_realloc(void **ptr, uint size, const char *descr);
void	 mem_free(void *ptr);

/* Create and destroy memory pools. */
mem_pool	*mem_pool_new(uint record_size, uint num_records,
		     const char *name);
void		 mem_pool_init(mem_pool *mp, uint record_size, uint num_records,
		     const char *name);
void		 mem_pool_free(mem_pool *mp);

/* Pool allocation routines. */
void	*mp_alloc(mem_pool *mp);
void	 mp_free(mem_pool *mp, void *ptr);
void	 mp_free_all(mem_pool *mp);

/* Traverse allocated structures. */
void	*mp_first(mem_pool *mp);
void	*mp_next(void *ptr);
typedef void (*mem_func)(void *);
void	 mp_foreach(mem_pool *mp, mem_func func);

#endif /* MEM_H */
