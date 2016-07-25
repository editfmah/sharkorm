//
//  SRKDefinitions.h
//  SharkORM
//
//  Copyright © 2016 SharkSync. All rights reserved.
//

#ifndef SRKDefinitions_h
#define SRKDefinitions_h

#define SRK_PROPERTY_TYPE_NUMBER                1
#define SRK_PROPERTY_TYPE_STRING                2
#define SRK_PROPERTY_TYPE_IMAGE                 3
#define SRK_PROPERTY_TYPE_ARRAY                 4
#define SRK_PROPERTY_TYPE_DICTIONARY            5
#define SRK_PROPERTY_TYPE_DATE                  6
#define SRK_PROPERTY_TYPE_INT                   7
#define SRK_PROPERTY_TYPE_BOOL                  8
#define SRK_PROPERTY_TYPE_LONG                  9
#define SRK_PROPERTY_TYPE_FLOAT                 10
#define SRK_PROPERTY_TYPE_CHAR                  11
#define SRK_PROPERTY_TYPE_SHORT                 12
#define SRK_PROPERTY_TYPE_LONGLONG              14
#define SRK_PROPERTY_TYPE_UCHAR                 15
#define SRK_PROPERTY_TYPE_UINT                  16
#define SRK_PROPERTY_TYPE_USHORT                17
#define SRK_PROPERTY_TYPE_ULONG                 18
#define SRK_PROPERTY_TYPE_ULONGLONG             19
#define SRK_PROPERTY_TYPE_DOUBLE                20
#define SRK_PROPERTY_TYPE_CHARPTR               21
#define SRK_PROPERTY_TYPE_URL                   22
#define SRK_PROPERTY_TYPE_DATA                  23
#define SRK_PROPERTY_TYPE_MUTABLEDATA           24
#define SRK_PROPERTY_TYPE_MUTABLEARAY           25
#define SRK_PROPERTY_TYPE_MUTABLEDIC            26
#define SRK_PROPERTY_TYPE_NSOBJECT              27
#define SRK_PROPERTY_TYPE_INT64                 28
#define SRK_PROPERTY_TYPE_UINT64                29
#define SRK_PROPERTY_TYPE_ENTITYOBJECT          98
#define SRK_PROPERTY_TYPE_ENTITYOBJECTARRAY     99
#define SRK_PROPERTY_TYPE_UNDEFINED             100

#define SRK_DEFAULT_LIMIT						9999999
#define SRK_DEFAULT_CONDITION					@"123=123"
#define SRK_DEFAULT_ORDER						@"Id ASC"
#define SRK_DEFAULT_OFFSET						0

#define SRK_START_TRANSACTION_STATEMENT			@"BEGIN TRANSACTION;"
#define SRK_COMMIT_TRANSACTION_STATEMENT		@"COMMIT TRANSACTION;"
#define SRK_ROLLBACK_TRANSACTION_STATEMENT		@"ROLLBACK TRANSACTION;"

#define SRK_FIELD_NAME_FORMAT                   @"%@.%@ as result$%@"
#define SRK_JOINED_FIELD_NAME_FORMAT            @"%@.%@ as result$%@_$_%@"


#define SRK_DEFAULT_PRIMARY_KEY_NAME				@"Id"

#define SuppressPerformSelectorLeakWarning(Stuff) \
do { \
_Pragma("clang diagnostic push") \
_Pragma("clang diagnostic ignored \"-Warc-performSelector-leaks\"") \
Stuff; \
_Pragma("clang diagnostic pop") \
} while (0)

typedef enum {
	SRK_PRIKEY_INTEGER = 1,
	SRK_PRIKEY_GUID = 2
} SRKPrimaryKeyColumnType;

typedef enum {
	SRK_COLUMN_TYPE_TEXT = 1,
	SRK_COLUMN_TYPE_NUMBER = 2,
	SRK_COLUMN_TYPE_DATE = 3,
	SRK_COLUMN_TYPE_IMAGE = 4,
	SRK_COLUMN_TYPE_INTEGER = 5,
	SRK_COLUMN_TYPE_BLOB = 6,
	SRK_COLUMN_TYPE_ENTITYCLASS = 99,
	SRK_COLUMN_TYPE_ENTITYCOLLECTION = 100
} SRKColumnStorageType;

/* global variables for use across all SharkORM instances */
static NSObject*   SRK_LOCK_WRITE;
static id<SRKDelegate> delegate;

#endif /* SRKDefinitions_h */
