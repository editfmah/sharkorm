//
//  SharkSchemaManager.h
//  SharkORM
//
//  Created by Adrian Herridge on 10/07/2018.
//  Copyright © 2018 SharkSync. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SharkORM+Private.h"

typedef enum : NSUInteger {
    Undefined,
    CreateTable,
    AddColumn,
    RemoveColumn,
} SharkSchemaChangeOperation;

@interface SharkSchemaStruct : NSObject

@property (strong) NSString* db;
@property (strong) NSString* entity;
@property (strong) NSString* pk;
@property (strong) NSMutableDictionary<NSString*, NSNumber*>* fields;
@property (strong) NSMutableDictionary<NSString*, NSString*>* indexes;

@end

@interface SharkSchemaManager : NSObject

+ (instancetype)shared;
- (NSArray<SRKRelationship*>*)relationshipsForEntity:(NSString*)entity;
- (NSArray<SRKRelationship*>*)relationshipsForEntity:(NSString*)entity type:(int)type;
- (NSArray<SRKRelationship*>*)relationshipsForEntity:(NSString*)entity property:(NSString*)property;
- (void)addRelationship:(SRKRelationship*)relationship;

- (BOOL)schemaPropertyExists:(NSString*)entity property:(NSString*)property;
- (NSArray<NSString*>*)schemaPropertiesForEntity:(NSString*)entity;
- (void)schemaSetEntity:(NSString*)entity database:(NSString*)database;
- (void)schemaSetEntity:(NSString*)entity pk:(NSString*)pk;
- (void)schemaSetEntity:(NSString*)entity property:(NSString*)property type:(int)type;
- (NSArray<NSString*>*)schemaTablesForDatabase:(NSString*)database;
- (NSString*)schemaPrimaryKeyForEntity:(NSString*)entity;
- (int)schemaPrimaryKeyTypeForEntity:(NSString*)entity;
- (int)schemaPropertyType:(NSString*)entity property:(NSString*)property;
- (void)schemaAddIndexDefinitionForEntity:(NSString*)entity name:(NSString*)name definition:(NSString*)definition;
- (NSDictionary<NSString*, NSString*>*)schemaIndexDefinitionsForEntity:(NSString*)entity;

- (void)schemaUpdateMissingDatabaseEntries:(NSString*)database;
- (BOOL)databasePropertyExistsInEntity:(NSString*)entity property:(NSString*)property;
- (NSArray<NSString*>*)databasePropertiesForEntity:(NSString*)entity;
- (int)databasePropertyTypeForEntity:(NSString*)entity property:(NSString*)property;
- (void)databaseSetEntity:(NSString*)entity property:(NSString*)property type:(int)type;
- (void)databaseSetEntity:(NSString*)entity pk:(NSString*)pk;
- (NSArray<NSString*>*)databaseTables:(NSString*)database;
- (NSString*)databasePrimaryKeyForEntity:(NSString*)entity;
- (int)databasePrimaryKeyTypeForEntity:(NSString*)entity;

- (void)databaseAddIndexDefinitionForEntity:(NSString*)entity name:(NSString*)name definition:(NSString*)definition;
- (NSDictionary<NSString*,NSString*>*)databaseIndexDefinitionsForEntity:(NSString*)entity;

- (void)reloadDatabaseSchemaForDatabase:(NSString*)database;
- (void)refactorDatabase:(NSString*)database entity:(NSString*)entity;
- (void)refactorDatabase:(NSString*)database;

@end
