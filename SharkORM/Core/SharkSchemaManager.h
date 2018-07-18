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
