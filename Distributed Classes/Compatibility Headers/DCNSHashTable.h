/*	NSHashTable.h
	Copyright (c) 1994-2014, Apple Inc. All rights reserved.
 */

#import <Foundation/NSPointerFunctions.h>
#import <Foundation/NSString.h>
#import <Foundation/NSEnumerator.h>

#if !defined(__FOUNDATION_DCNSHASHTABLE__)
#define __FOUNDATION_DCNSHASHTABLE__ 1

@class NSHashTable;

#if (TARGET_OS_MAC) || TARGET_OS_WIN32

/****************	(void *) Hash table operations	****************/

typedef struct {NSUInteger _pi; NSUInteger _si; void *_bs;} NSHashEnumerator;

FOUNDATION_EXPORT void NSFreeHashTable(NSHashTable *table);
FOUNDATION_EXPORT void NSResetHashTable(NSHashTable *table);
FOUNDATION_EXPORT BOOL NSCompareHashTables(NSHashTable *table1, NSHashTable *table2);
FOUNDATION_EXPORT NSHashTable *NSCopyHashTableWithZone(NSHashTable *table, NSZone *zone);
FOUNDATION_EXPORT void *NSHashGet(NSHashTable *table, const void *pointer);
FOUNDATION_EXPORT void NSHashInsert(NSHashTable *table, const void *pointer);
FOUNDATION_EXPORT void NSHashInsertKnownAbsent(NSHashTable *table, const void *pointer);
FOUNDATION_EXPORT void *NSHashInsertIfAbsent(NSHashTable *table, const void *pointer);
FOUNDATION_EXPORT void NSHashRemove(NSHashTable *table, const void *pointer);
FOUNDATION_EXPORT NSHashEnumerator NSEnumerateHashTable(NSHashTable *table);
FOUNDATION_EXPORT void *NSNextHashEnumeratorItem(NSHashEnumerator *enumerator);
FOUNDATION_EXPORT void NSEndHashTableEnumeration(NSHashEnumerator *enumerator);
FOUNDATION_EXPORT NSUInteger NSCountHashTable(NSHashTable *table);
FOUNDATION_EXPORT NSString *NSStringFromHashTable(NSHashTable *table);
FOUNDATION_EXPORT NSArray *NSAllHashTableObjects(NSHashTable *table);


/****************	Legacy	****************/

typedef struct {
    NSUInteger	(*hash)(NSHashTable *table, const void *);
    BOOL	(*isEqual)(NSHashTable *table, const void *, const void *);
    void	(*retain)(NSHashTable *table, const void *);
    void	(*release)(NSHashTable *table, void *);
    NSString 	*(*describe)(NSHashTable *table, const void *);
} NSHashTableCallBacks;

FOUNDATION_EXPORT NSHashTable *NSCreateHashTableWithZone(NSHashTableCallBacks callBacks, NSUInteger capacity, NSZone *zone);
FOUNDATION_EXPORT NSHashTable *NSCreateHashTable(NSHashTableCallBacks callBacks, NSUInteger capacity);


FOUNDATION_EXPORT const NSHashTableCallBacks NSIntegerHashCallBacks NS_AVAILABLE_MAC(10_5);
FOUNDATION_EXPORT const NSHashTableCallBacks NSNonOwnedPointerHashCallBacks;
FOUNDATION_EXPORT const NSHashTableCallBacks NSNonRetainedObjectHashCallBacks;
FOUNDATION_EXPORT const NSHashTableCallBacks NSObjectHashCallBacks;
FOUNDATION_EXPORT const NSHashTableCallBacks NSOwnedObjectIdentityHashCallBacks;
FOUNDATION_EXPORT const NSHashTableCallBacks NSOwnedPointerHashCallBacks;
FOUNDATION_EXPORT const NSHashTableCallBacks NSPointerToStructHashCallBacks;
FOUNDATION_EXPORT const NSHashTableCallBacks NSIntHashCallBacks NS_DEPRECATED_MAC(10_0, 10_5);

#else

#if defined(__has_include)
#if __has_include(<Foundation/NSHashTablePriv.h>)
#include <Foundation/NSHashTablePriv.h>
#endif
#endif

#endif

#endif

