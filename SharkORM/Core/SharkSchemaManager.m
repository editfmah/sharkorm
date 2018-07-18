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


#import "SharkSchemaManager.h"
#import "SharkORM+Private.h"
#import "SRKGlobals.h"

@implementation SharkSchemaStruct

- (instancetype)init {
    self = [super init];
    if (self) {
        self.fields = [NSMutableDictionary new];
        self.indexes = [NSMutableDictionary new];
    }
    return self;
}

@end

@implementation SharkSchemaManager {
    NSMutableArray<SRKRelationship*>* relationships;
    NSMutableDictionary<NSString*, SharkSchemaStruct*>* schemas;
    NSMutableDictionary<NSString*, SharkSchemaStruct*>* databases;
}

static SharkSchemaManager* this;

- (instancetype)init {
    self = [super init];
    if (self) {
        relationships = [NSMutableArray new];
        schemas = [NSMutableDictionary new];
        databases = [NSMutableDictionary new];
    }
    return self;
}

+ (instancetype)shared {
    if (!this) {
        this = [SharkSchemaManager new];
    }
    return this;
}

- (NSArray<SRKRelationship*>*)relationshipsForEntity:(NSString*)entity {
    
    NSMutableArray<SRKRelationship*>* results = [NSMutableArray new];
    for (SRKRelationship* r in relationships) {
        if ([[r.sourceClass description] isEqualToString:entity]) {
            [results addObject:r];
        }
    }
    return [NSArray arrayWithArray:results];
    
}

- (NSArray<SRKRelationship*>*)relationshipsForEntity:(NSString*)entity type:(int)type {
    
    NSMutableArray<SRKRelationship*>* results = [NSMutableArray new];
    for (SRKRelationship* r in [self relationshipsForEntity:entity]) {
        if (r.relationshipType == type) {
            [results addObject:r];
        }
    }
    return [NSArray arrayWithArray:results];
    
}

- (NSArray<SRKRelationship*>*)relationshipsForEntity:(NSString*)entity property:(NSString*)property {
    
    NSMutableArray<SRKRelationship*>* results = [NSMutableArray new];
    for (SRKRelationship* r in [self relationshipsForEntity:entity]) {
        if ([r.sourceProperty isEqualToString:property]) {
            [results addObject:r];
        }
    }
    return [NSArray arrayWithArray:results];
    
}

- (void)addRelationship:(SRKRelationship*)relationship {
    [relationships addObject:relationship];
}

- (BOOL)schemaPropertyExists:(NSString*)entity property:(NSString*)property {
    
    if (schemas[entity] != nil) {
        SharkSchemaStruct* schema = schemas[entity];
        for (NSString* f in schema.fields.allKeys) {
            if ([f isEqualToString:property]) {
                return YES;
            }
        }
    }
    
    return NO;
    
}

- (NSArray<NSString*>*)schemaPropertiesForEntity:(NSString*)entity {
    
    NSMutableArray<NSString*>* results = [NSMutableArray new];
    
    if (schemas[entity] != nil) {
        SharkSchemaStruct* schema = schemas[entity];
        for (NSString* f in schema.fields.allKeys) {
            [results addObject:f];
        }
    }
    
    return [NSArray arrayWithArray:results];
    
}

- (int)schemaPropertyType:(NSString*)entity property:(NSString*)property {
    
    if (schemas[entity] != nil) {
        SharkSchemaStruct* schema = schemas[entity];
        for (NSString* f in schema.fields.allKeys) {
            if ([f isEqualToString:property]) {
                return schema.fields[f].intValue;
            }
        }
    }
    
    return 0;
    
}

- (void)schemaSetEntity:(NSString*)entity property:(NSString*)property type:(int)type {
    
    SharkSchemaStruct* schema = schemas[entity];
    if (schema == nil) {
        schema = [SharkSchemaStruct new];
        schema.entity = entity;
        schemas[entity] = schema;
    }
    schema.fields[property] = @(type);
    
}

- (void)schemaSetEntity:(NSString*)entity pk:(NSString*)pk {
    
    SharkSchemaStruct* schema = schemas[entity];
    if (schema == nil) {
        schema = [SharkSchemaStruct new];
        schema.entity = entity;
        schemas[entity] = schema;
    }
    schema.pk = pk;
    
}

- (void)schemaSetEntity:(NSString*)entity database:(NSString*)database {
    
    SharkSchemaStruct* schema = schemas[entity];
    if (schema == nil) {
        schema = [SharkSchemaStruct new];
        schema.entity = entity;
        schemas[entity] = schema;
    }
    schema.db = database;
    
}

- (NSArray<NSString*>*)schemaTablesForDatabase:(NSString*)database {
    
    NSMutableArray<NSString*>* results = [NSMutableArray new];
    for(SharkSchemaStruct* s in schemas.allValues) {
        if ([s.db isEqualToString:database] && s.entity != nil) {
            [results addObject:s.entity];
        }
    }
    return [NSArray arrayWithArray:results];
    
}

- (NSString*)schemaPrimaryKeyForEntity:(NSString*)entity {
    
    if (schemas[entity] != nil) {
        return schemas[entity].pk;
    }
    return nil;
    
}

- (int)schemaPrimaryKeyTypeForEntity:(NSString *)entity {
    
    if (schemas[entity] != nil) {
        return schemas[entity].fields[schemas[entity].pk].intValue;
    }
    return SRK_PROPERTY_TYPE_NUMBER;
    
}

- (void)schemaAddIndexDefinitionForEntity:(NSString*)entity name:(NSString*)name definition:(NSString*)definition {
    
    SharkSchemaStruct* schema = schemas[entity];
    if (schema == nil) {
        schema = [SharkSchemaStruct new];
        schema.entity = entity;
        schemas[entity] = schema;
    }
    schema.indexes[name] = definition;
    
}

- (NSDictionary<NSString*, NSString*>*)schemaIndexDefinitionsForEntity:(NSString*)entity {
    
    if (schemas[entity] != nil) {
        return schemas[entity].indexes;
    }
    
    return [NSDictionary new];
    
}

- (void)schemaUpdateMissingDatabaseEntries:(NSString*)database {
    
    if (!database) {
        return;
    }
    
    for (SharkSchemaStruct* s in schemas.allValues) {
        if (s.db == nil) {
            s.db = database;
        }
    }
    
}

- (BOOL)databasePropertyExistsInEntity:(NSString*)entity property:(NSString*)property {
    
    if (databases[entity] != nil) {
        SharkSchemaStruct* schema = databases[entity];
        for (NSString* f in schema.fields.allKeys) {
            if ([f isEqualToString:property]) {
                return YES;
            }
        }
    }
    
    return NO;
}

- (NSArray<NSString*>*)databasePropertiesForEntity:(NSString*)entity {
    
    if (databases[entity] != nil) {
        SharkSchemaStruct* schema = databases[entity];
        return schema.fields.allKeys;
    }
    
    return @[];
    
}

- (int)databasePropertyTypeForEntity:(NSString*)entity property:(NSString*)property {
    
    if (databases[entity] != nil) {
        SharkSchemaStruct* schema = databases[entity];
        for (NSString* f in schema.fields.allKeys) {
            if ([f isEqualToString:property]) {
                return schema.fields[f].intValue;
            }
        }
    }
    
    return 0;
}

- (void)databaseSetEntity:(NSString*)entity property:(NSString*)property type:(int)type {
    
    SharkSchemaStruct* schema = databases[entity];
    if (schema == nil) {
        schema = [SharkSchemaStruct new];
        schema.entity = entity;
        databases[entity] = schema;
    }
    
    schema.fields[property] = @(type);
    
}

- (void)databaseSetEntity:(NSString*)entity database:(NSString*)database {
    
    SharkSchemaStruct* schema = databases[entity];
    if (schema == nil) {
        schema = [SharkSchemaStruct new];
        schema.entity = entity;
        databases[entity] = schema;
    }
    
    schema.db = database;
    
}

- (void)databaseSetEntity:(NSString*)entity pk:(NSString*)pk {
    
    SharkSchemaStruct* schema = databases[entity];
    if (schema == nil) {
        schema = [SharkSchemaStruct new];
        schema.entity = entity;
        databases[entity] = schema;
    }
    
    schema.pk = pk;
    
}

- (NSArray<NSString*>*)databaseTables:(NSString*)database {
    
    NSMutableArray<NSString*>* results = [NSMutableArray new];
    for (SharkSchemaStruct* d in databases.allValues) {
        if ([d.db isEqualToString:database]) {
            [results addObject:d.entity];
        }
    }
    
    return [NSArray arrayWithArray:results];
    
}

- (NSString*)databasePrimaryKeyForEntity:(NSString*)entity {
    
    if (databases[entity] != nil) {
        return databases[entity].pk;
    }
    
    return nil;
}

- (int)databasePrimaryKeyTypeForEntity:(NSString*)entity {
    
    if (databases[entity] != nil) {
        return databases[entity].fields[databases[entity].pk].intValue;
    }
    
    return 0;
}

- (void)databaseAddIndexDefinitionForEntity:(NSString*)entity name:(NSString*)name definition:(NSString*)definition {
    
    SharkSchemaStruct* schema = databases[entity];
    if (schema == nil) {
        schema = [SharkSchemaStruct new];
        schema.entity = entity;
        databases[entity] = schema;
    }
    schema.indexes[name] = definition;
    
}

- (NSDictionary<NSString*,NSString*>*)databaseIndexDefinitionsForEntity:(NSString*)entity {
    
    if (databases[entity] != nil) {
        SharkSchemaStruct* schema = databases[entity];
        return schema.indexes;
    }
    
    return @{};
}

- (void)reloadDatabaseSchemaForDatabase:(NSString*)database {
    
    sqlite3* handle = [[SRKGlobals sharedObject] handleForName:database];
    sqlite3_stmt* tableNames;
    const char* tableSQL = "SELECT name FROM sqlite_master WHERE type='table';\0";
    if (sqlite3_prepare_v2(handle, tableSQL, (int)strlen(tableSQL), &tableNames, nil) == SQLITE_OK) {
        while (sqlite3_step(tableNames) == SQLITE_ROW) {
            
            NSString* table = [NSString stringWithUTF8String:(const char*)sqlite3_column_text(tableNames, 0)];
            sqlite3_stmt* columnNames;
            NSString* columnSQL = [NSString stringWithFormat:@"PRAGMA table_info(%@);", table];
            
            [[SharkSchemaManager shared] databaseSetEntity:table database:database];
            
            if (sqlite3_prepare_v2(handle, columnSQL.UTF8String, (int)columnSQL.length, &columnNames, nil) == SQLITE_OK) {
                while (sqlite3_step(columnNames) ==  SQLITE_ROW) {
                    
                    NSString* field = [NSString stringWithUTF8String:(const char*)sqlite3_column_text(columnNames, 1)];
                    NSString* type = [NSString stringWithUTF8String:(const char*)sqlite3_column_text(columnNames, 2)];
                    int64_t pk = sqlite3_column_int64(columnNames, 5);
                    
                    int typeEnum = [self sqlTextTypeToInt:type];
                    
                    [SharkSchemaManager.shared databaseSetEntity:table property:field type:typeEnum];
                    if (pk != 0) {
                        [SharkSchemaManager.shared databaseSetEntity:table pk:field];
                    }
                    
                }
            }
            
            sqlite3_finalize(columnNames);
            
            sqlite3_stmt* indexNames;
            NSString* indexSQL = [NSString stringWithFormat:@"SELECT name,sql FROM sqlite_master WHERE tbl_name = '%@' AND type = 'index' AND sql IS NOT NULL;", table];
            
            if (sqlite3_prepare_v2(handle, indexSQL.UTF8String, (int)indexSQL.length, &indexNames, nil) == SQLITE_OK) {
                while (sqlite3_step(indexNames) ==  SQLITE_ROW) {
                    
                    NSString* name = [NSString stringWithUTF8String:(const char*)sqlite3_column_text(indexNames, 0)];
                    NSString* sql = [NSString stringWithUTF8String:(const char*)sqlite3_column_text(indexNames, 1)];
                    
                    [SharkSchemaManager.shared databaseAddIndexDefinitionForEntity:table name:name definition:sql];
                    
                }
            }
            
            sqlite3_finalize(indexNames);
            
        }
    }
}

- (int)sqlTextTypeToInt:(NSString*)type {
    
    if ([type isEqualToString:@"TEXT"]) {
        return SRK_COLUMN_TYPE_TEXT;
    }
    if ([type isEqualToString:@"TEXT COLLATE NOCASE"]) {
        return SRK_COLUMN_TYPE_TEXT;
    }
    if ([type isEqualToString:@"INTEGER"]) {
        return SRK_COLUMN_TYPE_INTEGER;
    }
    if ([type isEqualToString:@"NONE"]) {
        return SRK_COLUMN_TYPE_BLOB;
    }
    if ([type isEqualToString:@"BLOB"]) {
        return SRK_COLUMN_TYPE_BLOB;
    }
    if ([type isEqualToString:@"REAL"]) {
        return SRK_COLUMN_TYPE_NUMBER;
    }
    if ([type isEqualToString:@"NUMBER"]) {
        return SRK_COLUMN_TYPE_NUMBER;
    }
    if ([type isEqualToString:@"DATETIME"]) {
        return SRK_COLUMN_TYPE_DATE;
    }
    
    return SRK_COLUMN_TYPE_INTEGER;
    
}

- (NSString*)sqlTextTypeFromColumnType:(int)type {
    
    if (type == SRK_COLUMN_TYPE_TEXT) {
        return @"TEXT";
    }
    if (type == SRK_COLUMN_TYPE_NUMBER) {
        return @"NUMBER";
    }
    if (type == SRK_COLUMN_TYPE_INTEGER) {
        return @"INTEGER";
    }
    if (type == SRK_COLUMN_TYPE_DATE) {
        return @"DATETIME";
    }
    if (type == SRK_COLUMN_TYPE_IMAGE) {
        return @"BLOB";
    }
    if (type == SRK_COLUMN_TYPE_BLOB) {
        return @"BLOB";
    }
    if (type == SRK_COLUMN_TYPE_ENTITYCLASS) {
        return @"INTEGER";
    }
    if (type == SRK_COLUMN_TYPE_ENTITYCOLLECTION) {
        return @"";
    }
    
    return @"";
}

- (int)entityTypeToSQLSotrageType:(int)entityType {
    
    switch (entityType) {
        case SRK_PROPERTY_TYPE_NUMBER:
            return SRK_COLUMN_TYPE_NUMBER;
            break;
        case SRK_PROPERTY_TYPE_STRING:
            return SRK_COLUMN_TYPE_TEXT;
            break;
        case SRK_PROPERTY_TYPE_IMAGE:
            return SRK_COLUMN_TYPE_IMAGE;
        case SRK_PROPERTY_TYPE_ARRAY:
            return SRK_COLUMN_TYPE_BLOB;
        case SRK_PROPERTY_TYPE_DICTIONARY:
            return SRK_COLUMN_TYPE_BLOB;
        case SRK_PROPERTY_TYPE_DATE:
            return SRK_COLUMN_TYPE_DATE;
        case SRK_PROPERTY_TYPE_INT:
            return SRK_COLUMN_TYPE_INTEGER;
        case SRK_PROPERTY_TYPE_BOOL:
            return SRK_COLUMN_TYPE_INTEGER;
        case SRK_PROPERTY_TYPE_LONG:
            return SRK_COLUMN_TYPE_NUMBER;
        case SRK_PROPERTY_TYPE_FLOAT:
            return SRK_COLUMN_TYPE_NUMBER;
        case SRK_PROPERTY_TYPE_CHAR:
            return SRK_COLUMN_TYPE_TEXT;
        case SRK_PROPERTY_TYPE_SHORT:
            return SRK_COLUMN_TYPE_NUMBER;
        case SRK_PROPERTY_TYPE_LONGLONG:
            return SRK_COLUMN_TYPE_NUMBER;
        case SRK_PROPERTY_TYPE_UCHAR:
            return SRK_COLUMN_TYPE_NUMBER;
        case SRK_PROPERTY_TYPE_UINT:
            return SRK_COLUMN_TYPE_NUMBER;
        case SRK_PROPERTY_TYPE_USHORT:
            return SRK_COLUMN_TYPE_NUMBER;
        case SRK_PROPERTY_TYPE_ULONG:
            return SRK_COLUMN_TYPE_NUMBER;
        case SRK_PROPERTY_TYPE_ULONGLONG:
            return SRK_COLUMN_TYPE_NUMBER;
        case SRK_PROPERTY_TYPE_DOUBLE:
            return SRK_COLUMN_TYPE_NUMBER;
        case SRK_PROPERTY_TYPE_CHARPTR:
            return SRK_COLUMN_TYPE_TEXT;
        case SRK_PROPERTY_TYPE_DATA:
            return SRK_COLUMN_TYPE_BLOB;
        case SRK_PROPERTY_TYPE_MUTABLEDATA:
            return SRK_COLUMN_TYPE_BLOB;
        case SRK_PROPERTY_TYPE_MUTABLEARAY:
            return SRK_COLUMN_TYPE_BLOB;
        case SRK_PROPERTY_TYPE_MUTABLEDIC:
            return SRK_COLUMN_TYPE_BLOB;
        case SRK_PROPERTY_TYPE_URL:
            return SRK_COLUMN_TYPE_BLOB;
        case SRK_PROPERTY_TYPE_ENTITYOBJECT:
            return SRK_COLUMN_TYPE_ENTITYCLASS;
        case SRK_PROPERTY_TYPE_ENTITYOBJECTARRAY:
            return SRK_COLUMN_TYPE_ENTITYCOLLECTION;
        case SRK_PROPERTY_TYPE_NSOBJECT:
            return SRK_COLUMN_TYPE_BLOB;
        case SRK_PROPERTY_TYPE_UNDEFINED:
            break;
        default:
            break;
    }
    return 0;
}

- (void)refactorDatabase:(NSString*)database entity:(NSString*)entity {
    
    if (!database || [database isEqualToString:@""]) {
        
        // this is blank, so grab the default
        
        if (SRKGlobals.sharedObject.defaultDatabaseName != nil) {
            database = SRKGlobals.sharedObject.defaultDatabaseName;
        }
        
        // see if this database has been opened
        if ([SRKGlobals.sharedObject handleForName:database] == nil) {
            // this database will be refactored when finally opened in teh future.
            return;
        }
        
        // check to see if this table already exists
        if (databases[entity] == nil) {
            
            if ([entity isEqualToString:@"SmallPerson"]) {
                int i=0;
            }
            
            // completely new table, so we can do this in a single operation
            NSString* sql = @"CREATE TABLE IF NOT EXISTS ";
            sql = [sql stringByAppendingString:entity];
            sql = [sql stringByAppendingString:@" (Id "];
            if ([self schemaPrimaryKeyTypeForEntity:entity] == SRK_PROPERTY_TYPE_NUMBER) {
                sql = [sql stringByAppendingString:@"INTEGER PRIMARY KEY AUTOINCREMENT);"];
            } else {
                sql = [sql stringByAppendingString:@"TEXT PRIMARY KEY);"];
            }
            
            [SharkORM executeSQL:sql inDatabase:database];
            
            // now add the columns in one-by-one
            for (NSString* f in [self schemaPropertiesForEntity:entity]) {
                sql = @"ALTER TABLE ";
                sql = [sql stringByAppendingString:entity];
                sql = [sql stringByAppendingString:@" ADD COLUMN "];
                sql = [sql stringByAppendingString:f];
                sql = [sql stringByAppendingString:@" "];
                sql = [sql stringByAppendingString:[self sqlTextTypeFromColumnType:[self entityTypeToSQLSotrageType:[self schemaPropertyType:entity property:f]]]];
                [SharkORM executeSQL:sql inDatabase:database];
            }
            
        } else {
            
            NSString* sql = @"";
            
            // existing table, so look for missing columns and add them
            for (NSString* f in [self schemaPropertiesForEntity:entity]) {
                if (![self databasePropertyExistsInEntity:entity property:f]) {
                    sql = @"ALTER TABLE ";
                    sql = [sql stringByAppendingString:entity];
                    sql = [sql stringByAppendingString:@" ADD COLUMN "];
                    sql = [sql stringByAppendingString:f];
                    sql = [sql stringByAppendingString:@" "];
                    sql = [sql stringByAppendingString:[self sqlTextTypeFromColumnType:[self entityTypeToSQLSotrageType:[self schemaPropertyType:entity property:f]]]];
                    [SharkORM executeSQL:sql inDatabase:database];
                }
            }
            
            // look for changed data value types
            for (NSString* f in [self schemaPropertiesForEntity:entity]) {
                if ([self databasePropertyExistsInEntity:entity property:f]) {
                    if ([self entityTypeToSQLSotrageType:[self schemaPropertyType:entity property:f]] != [self databasePropertyTypeForEntity:entity property:f]) {
                        
                        // detect change, and migrate data accordingly
                        
                    }
                }
            }
            
            // notify the entity class that we are between two states, all new columns have been added, but we have not removed the old ones yet.
            //TODO: implement migration
            
            // look for extra columns that need to be dropped
            BOOL foundDefuncColumns = NO;
            for (NSString* f in [self databasePropertiesForEntity:entity]) {
                if (![self schemaPropertyExists:entity property:f]) {
                    foundDefuncColumns = YES;
                }
            }
            
            if (foundDefuncColumns) {
                
                // rename the old table
                [SharkORM executeSQL:[NSString stringWithFormat:@"ALTER TABLE %@ RENAME TO temp_%@;", entity, entity] inDatabase:database];
                
                // completely new table, so we can do this in a single operation
                NSString* sql = @"CREATE TABLE IF NOT EXISTS ";
                sql = [sql stringByAppendingString:entity];
                sql = [sql stringByAppendingString:@" (Id "];
                if ([self schemaPrimaryKeyTypeForEntity:entity] == SRK_PROPERTY_TYPE_NUMBER) {
                    sql = [sql stringByAppendingString:@"INTEGER PRIMARY KEY AUTOINCREMENT);"];
                } else {
                    sql = [sql stringByAppendingString:@"TEXT PRIMARY KEY);"];
                }
                
                [SharkORM executeSQL:sql inDatabase:database];
                
                // now add the columns in one-by-one
                for (NSString* f in [self schemaPropertiesForEntity:entity]) {
                    sql = @"ALTER TABLE ";
                    sql = [sql stringByAppendingString:entity];
                    sql = [sql stringByAppendingString:@" ADD COLUMN "];
                    sql = [sql stringByAppendingString:[self sqlTextTypeFromColumnType:[self entityTypeToSQLSotrageType:[self schemaPropertyType:entity property:f]]]];
                    [SharkORM executeSQL:sql inDatabase:database];
                }
                
                // copy the data from the temp database
                [SharkORM executeSQL:[NSString stringWithFormat:@"INSERT INTO %@ (%@) SELECT %@ FROM temp_%@;", entity, [[self schemaPropertiesForEntity:entity] componentsJoinedByString:@","], [[self schemaPropertiesForEntity:entity] componentsJoinedByString:@","], entity] inDatabase:database];
                
                // drop the temp table
                [SharkORM executeSQL:[NSString stringWithFormat:@"DROP TABLE temp_%@;", entity] inDatabase:database];
                
                // clear out the indexes as they are no longer on this new table
                databases[entity].indexes = [NSMutableDictionary new];
                
            }

        }
        
        // now create and remove indexes on the tables
        NSDictionary<NSString*, NSString*>* idx = [self schemaIndexDefinitionsForEntity:entity];
        for (NSString* i in idx.allKeys) {
            if ([self databaseIndexDefinitionsForEntity:entity][i] == nil) {
                // missing index, create it now
                [SharkORM executeSQL:idx[i] inDatabase:database];
            }
        }
        
        // remove old indexes
        idx = [self databaseIndexDefinitionsForEntity:entity];
        for (NSString* i in idx.allKeys) {
            if ([self schemaIndexDefinitionsForEntity:entity][i] == nil) {
                // missing index, create it now
                [SharkORM executeSQL:[NSString stringWithFormat:@"DROP INDEX IF EXISTS %@;", i] inDatabase:database];
            }
        }

    } // database != nil
    
}

- (void)refactorDatabase:(NSString*)database {
    
    /*
     *    This will iterate through the schema's, checking them against the Database structure.  After finding all the tables in the database and initialising their class objects if possible
     */
    
    [self reloadDatabaseSchemaForDatabase:database];
    
    // go though all the tables, checking for missed entities
    for (NSString* t in [self databaseTables:database]) {
        
        if (NSClassFromString(t) == nil) {
            if ([SRKGlobals.sharedObject getFQNameForClass:t] != nil) {
                NSClassFromString([SRKGlobals.sharedObject getFQNameForClass:t]);
            }
        }
        
    }
    
    // loop the tables, creating new or refactoring
    for (NSString* entity in [self schemaTablesForDatabase:database]) {
        [self refactorDatabase:database entity:entity];
    }
    
}


@end
