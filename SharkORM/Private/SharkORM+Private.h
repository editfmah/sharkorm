//    MIT License
//
//    Copyright (c) 2010-2018 SharkSync
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


#import "SharkORM.h"
#import "SQLite3.h"
#import "SRKDefinitions.h"
#import "SharkSchemaManager.h"

@interface SharkORM ()

// form data methods
-(BOOL)removeObject:(SRKEntity*)entity;
-(BOOL)commitObject:(SRKEntity*)entity;
-(void)replaceUUIDPrimaryKey:(SRKEntity *)entity withNewUUIDKey:(NSString*)newPrimaryKey;
+(void)refreshObject:(SRKEntity*)entity;

-(NSMutableArray*)fetchEntitySetForQuery:(SRKQuery*)query;
-(uint64_t)fetchCountForQuery:(SRKQuery*)query;
-(double)fetchSumForQuery:(SRKQuery*)query field:(NSString*)fieldname;
-(NSArray*)fetchDistinctForQuery:(SRKQuery*)query field:(NSString*)fieldname;
-(NSArray*)fetchIDsForQuery:(SRKQuery*)query;
+(SRKSettings*)getSettings;
+(sqlite3*)handleForDatabase:(NSString*)dbName;
+(NSString*)databaseNameForClass:(Class)classDecl;
+(void)setSchemaRevision:(int)revision inDatabase:(NSString*)dbName;
+(int)getSchemaRevisioninDatabase:(NSString*)dbName;
+(void)setEntityRevision:(int)revision forEntity:(NSString*)entity inDatabase:(NSString*)dbName;
+(int)getEntityRevision:(NSString*)entity inDatabase:(NSString*)dbName;
+(NSInteger)primaryKeyType:(NSString*)tableName;
+(void)executeSQL:(NSString*)sql inDatabase:(NSString*)dbName;
+(id)getValueFromQuery:query inClass:classDecl;

@end

