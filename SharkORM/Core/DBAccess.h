//    MIT License
//
//    Copyright (c) 2016 SharkSync
//
//    Permission is hereby granted, free of charge, to any person obtaining a copy
//    of this software and associated documentation files (the "Software"), to deal
//    in the Software without restriction, including without limitation the rights
//    to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//    copies of the Software, and to permit persons to whom the Software is
//    furnished to do so, subject to the following conditions:
//
//    The above copyright notice and this permission notice shall be included in all
//    copies or substantial portions of the Software.
//
//    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//    IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//    FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//    AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//    LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//    OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//    SOFTWARE.

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
