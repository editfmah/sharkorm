//
//  SharkORM
//  Copyright © 2016 SharkSync. All rights reserved.
//
//  DBAccess compatibility header.

#ifndef DBAccess_h
#define DBAccess_h

#import <SharkORM/SharkORM.h>

// classes
#define DBObject            SRKObject
#define DBQuery             SRKQuery
#define DBDelegate          SRKDelegate
#define DBError             SRKError
#define DBEvent             SRKEvent
#define DBAccess            SharkORM
#define DBResultSet         SRKResultSet
#define DBIndexDefinition   SRKIndexDefinition
#define DBQueryProfile      SRKQueryProfile
#define DBAccessSettings    SRKSettings
#define DBTransaction       SRKTransaction
#define DBEventHandler      SRKEventHandler
#define DBContext           SRKContext


// functions
#define dbMakeLike          makeLikeParameter

// enums

typedef enum {
    DB_RELATE_ONETOONE = 1,
    DB_RELATE_ONETOMANY = 2,
    DB_RELATE_MANYTOMANY = 3,
} DBRelationshipType;

enum DBIndexSortOrder {
    DBIndexSortOrderAscending = 1,
    DBIndexSortOrderDescending = 2,
    DBIndexSortOrderNoCase = 3
};

enum DBAccessEvent {
    DBAccessEventInsert = 1,
    DBAccessEventUpdate = 2,
    DBAccessEventDelete = 4,
};

#endif /* DBAccess_h */
