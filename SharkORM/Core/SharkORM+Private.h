//
//  SharkORM+Private.h
//  SharkORM
//
//  Copyright © 2016 SharkSync. All rights reserved.
//

#ifndef SharkORM_Private_h
#define SharkORM_Private_h

#import "SharkORM.h"
#import "SQLite3.h"
#import "SRKDefinitions.h"

@class SRKTransactionGroup;

@interface SharkORM ()

// form data methods
-(BOOL)removeObject:(SRKObject*)entity inTransaction:(SRKTransactionGroup*)transaction;
-(BOOL)commitObject:(SRKObject*)entity inTransaction:(SRKTransactionGroup*)transaction;
-(void)replaceUUIDPrimaryKey:(SRKObject *)entity withNewUUIDKey:(NSString*)newPrimaryKey;
+(void)refreshObject:(SRKObject*)entity;

-(NSMutableArray*)fetchEntitySetForQuery:(SRKQuery*)query;
-(uint64_t)fetchCountForQuery:(SRKQuery*)query;
-(double)fetchSumForQuery:(SRKQuery*)query field:(NSString*)fieldname;
-(NSArray*)fetchDistinctForQuery:(SRKQuery*)query field:(NSString*)fieldname;
-(NSArray*)fetchIDsForQuery:(SRKQuery*)query;
+(NSMutableArray*)entityRelationships;
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
