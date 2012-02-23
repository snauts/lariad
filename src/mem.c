#include <assert.h>
#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include "common.h"
#include "log.h"
#include "mem.h"

#if 0
/*
 * Make a human readable string out of memory size in bytes (e.g., 3K, 24M).
 */
static void
human(uint num_bytes, char *str, uint str_size)
{
	if (num_bytes < 1024) {
		snprintf(str, str_size, "%i bytes", num_bytes);
		return;
	}
	if (num_bytes < 1024 * 1024) {
		snprintf(str, str_size, "%iK", num_bytes / 1024);
		return;
	}
	if (num_bytes < 1024 * 1024 * 1024) {
		snprintf(str, str_size, "%iM", num_bytes / 1024 / 1024);
		return;
	}
	snprintf(str, str_size, "%iG", num_bytes / 1024 / 1024 / 1024);
}
#endif /* Unused block. */

/*
 * Allocate memory.
 *
 * size		Number of bytes to allocate.
 * descr	Short description of what this memory will be used for.
 */
void *
mem_alloc(uint size, const char *descr)
{
	void *ptr;

	assert(descr != NULL);

	ptr = malloc(size);
	assert(ptr != NULL);

#if 0
#ifndef NDEBUG
	char s[20];

	human(size, s, 20);
	log_msg("[MEM] %s mem_alloc()ed for '%s' at %p.", s, descr, ptr);
#endif /* Debug mode. */
#endif /* Unused block. */

	return ptr;
}

/*
 * Reallocate memory. 
 * 
 * ptr		A pointer to a pointer to the resizable memory.
 * size		Number of bytes to allocate.
 * descr	Short description of what this memory will be used for.
 */
void
mem_realloc(void **ptr, uint size, const char *descr)
{
	assert(ptr != NULL);
	assert(descr != NULL);

	*ptr = realloc(*ptr, size);
	assert(*ptr != NULL);

#if 0
#ifndef NDEBUG
	char s[20];

	human(size, s, 20);
	log_msg("[TEMP] %s mem_realloc()ed for '%s' at %p.", s, descr, *ptr);
#endif /* Debug mode. */
#endif /* Unused block. */
}

/*
 * Free memory.
 */
void
mem_free(void *ptr)
{
	assert(ptr != NULL);
	free(ptr);
}

/*
 * Create a new memory pool.
 *
 * num_records	Number of estimated records.
 * record_size	Size of each data record.
 * name		Short description of what will be stored in this pool.
 */
mem_pool *
mem_pool_new(uint record_size, uint num_records, const char *name)
{
	mem_pool *mp;

	mp = mem_alloc(sizeof(mem_pool), name);
	mem_pool_init(mp, record_size, num_records, name);
	return mp;
}

/*
 * Initialize a new memory pool.
 *
 * record_size	Size of one data record.
 * num_records	Number of estimated records.
 * name		Short description of what will be stored in this pool.
 */
void
mem_pool_init(mem_pool *mp, uint record_size, uint num_records,
    const char *name)
{
	uint i;
	char *ptr;

	assert(record_size > 0 && num_records > 0 && name != NULL);
	snprintf(mp->name, MEM_MAX_NAMELEN, "%i %s", num_records, name);
	mp->cell_size = 2*sizeof(void *) + record_size;
	mp->num_cells = num_records;
	mp->blocks[0] = mem_alloc(mp->cell_size * mp->num_cells, mp->name);
	memset(mp->blocks[0], 0, mp->cell_size * mp->num_cells);
	mp->num_blocks = 1;
	mp->free_cells = mp->blocks[0];
	mp->inuse_cells = NULL;

	/* Start pool statistics. */
	mp->stat_current = 0;
	mp->stat_alloc = 0;
	mp->stat_free = 0;
	mp->stat_peak = 0;

	/* Create a linked list of cells: the pointer in the current cell is set
	   to point to the previous and next cell. */
	for (i = 0; i < mp->num_cells; i++) {
		ptr = (char *)mp->blocks[0] + mp->cell_size * i;
		*((void **)ptr+0) = ptr - mp->cell_size;	/* prev */
		*((void **)ptr+1) = ptr + mp->cell_size;	/* next */
	}
	*(void **)mp->blocks[0] = NULL;		/* head->prev = NULL */
	*((void **)ptr+1) = NULL;		/* last->next = NULL */

	/* Set free_cells_last to point to last element in free cell list. */
	mp->free_cells_last = ptr;
}

/*
 * Free any resources associated with memory pool mp.
 */
void
mem_pool_free(mem_pool *mp)
{
	uint total;
	
	assert(mp != NULL);

	/*
	 * Calculate total number of currently available cells and print the
	 * various statistics.
	 */
	total = mp->num_blocks * mp->num_cells;
	log_msg("[MEM] Destroy '%s' (%i, %i, %i, %i, %i)", mp->name, total,
	    mp->stat_current, mp->stat_alloc, mp->stat_free, mp->stat_peak);

	/* Free all blocks and the memory pool structure itself. */
	while (mp->num_blocks) {
		mp->num_blocks--;
		mem_free(mp->blocks[mp->num_blocks]);
		mp->blocks[mp->num_blocks] = NULL;
	}
	mem_free(mp);
}

/*
 * Allocate memory from pool mp.
 */
void *
mp_alloc(mem_pool *mp)
{
	uint i, b;
	void *ptr, **next, **prev;

	assert(mp != NULL);

	if (mp->free_cells == NULL) {
		if (mp->num_blocks >= MEM_MAX_BLOCKS) {
			log_err("[MEM] Pool '%s' out of memory.", mp->name);
			abort();
		}
		/* Allocate a new block. */
		if (mp->num_blocks > 0)
			log_warn("[MEM] New block required for '%s'", mp->name);
		b = mp->num_blocks;	/* New block index. */
		mp->blocks[b] = mem_alloc(mp->cell_size * mp->num_cells,
		    mp->name);
		memset(mp->blocks[b], 0, mp->cell_size * mp->num_cells);
		mp->num_blocks++;

		/* Create a linked list of cells: the pointer in the current
		   cell is set to point to the previous and next cell. */
		for (i = 0; i < mp->num_cells; i++) {
			ptr = (char *)mp->blocks[b] + mp->cell_size * i;
			*((void **)ptr+0) = ptr - mp->cell_size;  /* prev */
			*((void **)ptr+1) = ptr + mp->cell_size;  /* next */
		}
		*(void **)mp->blocks[b] = NULL;		/* head->prev = NULL */
		*((void **)ptr+1) = NULL;		/* last->next = NULL */
		
		mp->free_cells = mp->blocks[b];	/* Make block addresses
						   available. */
		/* Set free_cells_last to point to last cell from new block. */
		mp->free_cells_last = ptr;
	}

	/* Adjust statistics. */
	mp->stat_current += 1;
	mp->stat_alloc += 1;
	if (mp->stat_current > mp->stat_peak)
		mp->stat_peak = mp->stat_current;

	/* Remove first cell from free cell list. */
	prev = ((void **)mp->free_cells+0);
	next = ((void **)mp->free_cells+1);
	assert(*prev == NULL);
	ptr = (void **)mp->free_cells+2;		/* Ptr to item data. */
	assert(*next != NULL || mp->free_cells == mp->free_cells_last);
	mp->free_cells = *next;				/* head = head->next. */
	if (mp->free_cells != NULL)
		*((void **)mp->free_cells+0) = NULL;	/* head->prev = NULL */
	else
		mp->free_cells_last = NULL;		/* Last element gone. */

	/* Add cell to allocated cell list. */
	*next = mp->inuse_cells;			/* item->next = head */
	if (mp->inuse_cells != NULL)
		*((void **)mp->inuse_cells+0) = prev;	/* head->prev = item */
	mp->inuse_cells = prev;				/* head = ptr */

	return ptr;
}

/*
 * Free memory from a memory pool.
 */
void
mp_free(mem_pool *mp, void *ptr)
{
	void **next, **prev;
	
#ifndef NDEBUG
	uint i, blocksize;

	assert(mp != NULL && ptr != NULL);

	/* Check if address belongs to the pool. */
	blocksize = mp->cell_size * mp->num_cells;
	for (i = 0; i < mp->num_blocks; i++) {
		if (ptr >= mp->blocks[i] && ptr < mp->blocks[i] + blocksize)
			break;
	}
	if (i == mp->num_blocks) {
		log_err("[MEM] mp_free(): pointer %p does not belong to '%s.'",
		    ptr, mp->name);
		abort();
	}
	/* Clear memory to hopefully invalidate it. */
	memset(ptr, 0, mp->cell_size - 2*sizeof(void *));
#endif /* Debug mode. */

	/* Adjust statistics. */
	mp->stat_current -= 1;
	mp->stat_free += 1;

	/* Remove cell from allocated cell list. */
	prev = ((void **)ptr-2);
	next = ((void **)ptr-1);
	if (*prev == NULL)
		mp->inuse_cells = *next;	/* head = ptr->next */
	else
		*((void **)(*prev)+1) = *next;	/* ptr->prev->next = ptr->next */
	if (*next != NULL)
		*((void **)(*next)+0) = *prev;	/* ptr->next->prev = ptr->prev */
		
	/* Add ptr cell to the end of free cell list. */
	*next = NULL;					/* ptr->next = NULL */
	*prev = mp->free_cells_last;			/* ptr->prev = last */
	if (mp->free_cells_last != NULL) {
		assert(*((void **)mp->free_cells_last+1) == NULL);
		*((void **)mp->free_cells_last+1) = prev; /* last->next = ptr */
	} else {
		assert(mp->free_cells == NULL);		/* No elements. */
		mp->free_cells = prev;			/* head = ptr */
	}
	mp->free_cells_last = prev;			/* last = ptr */
}

/*
 * Free all memory from a memory pool.
 */
void
mp_free_all(mem_pool *mp)
{
	uint total;
	
	assert(mp != NULL);

	/*
	 * Calculate total number of currently available cells and print the
	 * various statistics.
	 */
	total = mp->num_blocks * mp->num_cells;
	log_msg("[MEM] Free all from '%s' (%i, %i, %i, %i, %i)", mp->name,
	    total, mp->stat_current, mp->stat_alloc, mp->stat_free,
	    mp->stat_peak);

	/* Reset stats. */
	mp->stat_current = 0;
	mp->stat_alloc = 0;
	mp->stat_free = 0;
	mp->stat_peak = 0;

	/* Free all blocks & destroy lists. */
	while (mp->num_blocks) {
		mp->num_blocks--;
		mem_free(mp->blocks[mp->num_blocks]);
		mp->blocks[mp->num_blocks] = NULL;
	}
	mp->free_cells = NULL;
	mp->free_cells_last = NULL;
	mp->inuse_cells = NULL;
}

/*
 * Return first pointer from the allocated cell list.
 */
void *
mp_first(mem_pool *mp)
{
	assert(mp != NULL);
	if (mp->inuse_cells == NULL)
		return NULL;
	return (char *)mp->inuse_cells + 2*sizeof(void *);
}

/*
 * Iterate over allocated structures. A pointer that belongs to the list is
 * passed as an argument, next in the list is returned. If the end of the
 * allocated cell list is reached, NULL is returned.
 */
void *
mp_next(void *ptr)
{
	void **next;

	assert(ptr != NULL);
	next = (void **)ptr-1;
	if (*next == NULL)
		return NULL;
	return (void **)(*next)+2;
}

/*
 * Execute a routine for each allocated structure.
 */
void
mp_foreach(mem_pool *mp, mem_func func)
{
	void *ptr;

	ptr = mp_first(mp);
	while (ptr) {
		func(ptr);
		ptr = mp_next(ptr);
	}
}
