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



#ifndef SharkORM_Private_h
#define SharkORM_Private_h

#import "SharkORM.h"
#import "SQLite3.h"
#import "SRKDefinitions.h"

@interface SharkORM ()

// form data methods
-(BOOL)removeObject:(SRKObject*)entity;
-(BOOL)commitObject:(SRKObject*)entity;
-(void)replaceUUIDPrimaryKey:(SRKObject *)entity withNewUUIDKey:(NSString*)newPrimaryKey;
+(void)refreshObject:(SRKObject*)entity;

-(NSMutableArray*)fetchEntitySetForQuery:(SRKQuery*)query;
-(uint64_t)fetchCountForQuery:(SRKQuery*)query;
-(double)fetchSumForQuery:(SRKQuery*)query field:(NSString*)fieldname;
-(NSArray*)fetchDistinctForQuery:(SRKQuery*)query field:(NSString*)fieldname;
-(NSArray*)fetchIDsForQuery:(SRKQuery*)query;
+(NSArray*)entityRelationships;
+(NSMutableArray*)entityRelationshipsForClass:(Class)class;
+(SRKRelationship*)entityRelationshipsForProperty:(NSString*)property inClass:(Class)class;
+(NSMutableDictionary*)tableSchemas;
+(NSArray*)fieldsForTable:(NSString*)table;
+(SRKSettings*)getSettings;
+(sqlite3*)handleForDatabase:(NSString*)dbName;
+(NSString*)databaseNameForClass:(Class)classDecl;
+(void)createTableNamed:(NSString*)tableName withPrimaryKeyType:(SRKPrimaryKeyColumnType)keyType inDatabase:(NSString*)dbName;
+(void)indexFieldInTable:(NSString*)tableName columnName:(NSString*)columnName inDatabase:(NSString*)dbName;
+(void)addEntityRelationship:(SRKRelationship*)r inDatabase:(NSString*)dbName;
+(void)refactorTableFromEntityDefinition:(NSDictionary*)definition forTable:(NSString*)table inDatabase:(NSString*)dbName primaryKeyAsString:(BOOL)pkIsString;
+(void)prepareFTSTableForClass:(Class)classDecl withPropertyList:(NSArray*)properties;
+(void)removeMissingFieldsFromEntityDefinition:(NSDictionary*)definition forTable:(NSString*)table inDatabase:(NSString*)dbName;
+(void)setSchemaRevision:(int)revision inDatabase:(NSString*)dbName;
+(int)getSchemaRevisioninDatabase:(NSString*)dbName;
+(void)setEntityRevision:(int)revision forEntity:(NSString*)entity inDatabase:(NSString*)dbName;
+(int)getEntityRevision:(NSString*)entity inDatabase:(NSString*)dbName;
+(int)primaryKeyType:(NSString*)tableName;
+(void)cacheSchemaForDatabase:(NSString*)database withHandle:(sqlite3*)db;
+(void)cachePrmaryKeyForTable:(NSString*)table inDatabase:(NSString*)dbName;
+(void)cachePrmaryKeyTypeTable:(NSString*)table inDatabase:(NSString*)dbName;
+(void)executeSQL:(NSString*)sql inDatabase:(NSString*)dbName;
+ (BOOL)column:(NSString*)column existsInTable:(NSString *)table;
+(id)getValueFromQuery:query inClass:classDecl;

@end

#endif /* SharkORM_Private_h */
