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



#include "sqlite3.h"
#import "SRKDefinitions.h"
#import "SRKObject+Private.h"
#import "SRKRegistry.h"
#import "SRKEventBlockHolder.h"
#import "SRKQuery+Private.h"
#import "SharkORM+Private.h"
#import "SRKUtilities.h"
#import "SRKUnsupportedObject.h"
#import "SRKJoinObject.h"
#import "FTSRegistry.h"
#import "SRKGlobals.h"
#import "SRKTransaction+Private.h"

#define EventInsert 1
#define EventUpdate 2
#define EventDelete 4

void dateFromString(sqlite3_context *context, int argc, sqlite3_value **argv);
BOOL isNillOrNull(NSObject* ob);

NSString* makeLikeParameter(NSString* stmt) {
    
    return [NSString stringWithFormat:@"%%%@%%", stmt];
    
}

typedef void (^SRKBasicBlock)();
typedef void(^SQLQueryRowBlock)(sqlite3_stmt* statement, NSMutableArray* resultsSet);

typedef enum : int {
    SRK_QUERY_TYPE_FETCH = 1,
    SRK_QUERY_TYPE_SUM = 2,
    SRK_QUERY_TYPE_COUNT = 3,
    SRK_QUERY_TYPE_DISTINCT = 4,
    SRK_QUERY_TYPE_IDS = 5,
} SRK_QUERY_TYPE;

@implementation SharkORM

+ (BOOL)NumberIsFraction:(NSNumber *)number {
    double dValue = [number doubleValue];
    if (dValue < 0.0)
        return (dValue != ceil(dValue));
    else
        return (dValue != floor(dValue));
}

+ (void)migrateFromLegacyCoredataFile:(NSString*)filePath tables:(NSArray*)tablesToConvert {
    
    NSMutableDictionary* results = [NSMutableDictionary new];
    
    sqlite3* tempDb;
    sqlite3_open(filePath.UTF8String, &tempDb);
    if (tempDb) {
        
        for (NSString* currentT in tablesToConvert) {
            
            @autoreleasepool {
                
                /* get a list of tables form this database */
                sqlite3_stmt* tableList = nil;
                if (sqlite3_prepare_v2(tempDb, [NSString stringWithFormat:@"SELECT DISTINCT tbl_name FROM sqlite_master WHERE tbl_name ='%@';",[NSString stringWithFormat:@"Z%@", currentT.uppercaseString]].UTF8String, -1, &tableList, nil) == SQLITE_OK) {
                    
                    while (sqlite3_step(tableList) == SQLITE_ROW) {
                        
                        NSString* currentTable = (NSString*)[[SRKUtilities new] sqlite3_column_objc:tableList column:0];
                        [results setObject:[NSMutableArray new] forKey:currentTable];
                        
                        /* now get all the data */
                        sqlite3_stmt* tableContents = nil;
                        if (sqlite3_prepare_v2(tempDb, [NSString stringWithFormat:@"SELECT * FROM %@;", currentTable].UTF8String, -1, &tableContents, nil) == SQLITE_OK) {
                            
                            while (sqlite3_step(tableContents) == SQLITE_ROW) {
                                
                                NSMutableDictionary* record = [NSMutableDictionary new];
                                
                                for (int i=0; i < sqlite3_column_count(tableContents); i++) {
                                    
                                    NSString* key = [NSString stringWithUTF8String:sqlite3_column_name(tableContents, i)];
                                    SRKUtilities* dba = [SRKUtilities new];
                                    key = [dba normalizedColumnName:key];
                                    
                                    NSObject* value = [[SRKUtilities new] sqlite3_column_objc:tableContents column:i];
                                    [record setObject:value forKey:key];
                                    
                                }
                                
                                NSMutableArray* thisArray = [results objectForKey:currentTable];
                                [thisArray addObject:record];
                                
                            }
                            
                        }
                        
                    }
                    
                }
                sqlite3_finalize(tableList);
                
                
                /* now go through the specified tables to convert them */
                
                /* we need to perform all of these writes within a single transaction */
                SRKContext* context = [SRKContext new];
                
                
                /* remove all existing data in these tables */
                NSString* currentTableName = currentT;
                if (!NSClassFromString(currentTableName)) {
                    currentTableName = [[SRKGlobals sharedObject] getFQNameForClass:currentT];
                }
                
                [[[NSClassFromString(currentTableName) query] fetchLightweight] removeAll];
                
                NSArray* oldTableData = [results objectForKey:[NSString stringWithFormat:@"Z%@", currentT.uppercaseString]];
                if (oldTableData) {
                    for (NSDictionary* record in oldTableData) {
                        
                        @autoreleasepool {
                            /* create a new SRKObject based on this class */
                            SRKObject* newRecord = [NSClassFromString(currentTableName) new];
                            if (newRecord) {
                                for (NSString* currentField in newRecord.fieldNames) {
                                    
                                    id value = [record objectForKey:[NSString stringWithFormat:@"Z%@", currentField.uppercaseString]];
                                    if (!value) {
                                        value = [NSNull null];
                                    }
                                    
                                    [newRecord setFieldRaw:currentField value:value];
                                    
                                }
                                [context addEntityToContext:newRecord];
                            }
                        }
                        
                    }
                }
                
                [context commit];
                
            }
        }
    }
    
}

+ (void)setupTablesFromClasses:(Class)classDecl,... {
    /* psudo call */
}

+ (BOOL)column:(NSString*)column existsInTable:(NSString *)table {
    
    NSDictionary* d = [[[SRKGlobals sharedObject] tableSchemas] objectForKey:table];
    if ([d objectForKey:column]) {
        return YES;
    } else {
        return NO;
    }
    
}

+ (NSArray *)fieldsForTable:(NSString *)table {
    return [[[[SRKGlobals sharedObject] tableSchemas] objectForKey:table] allKeys];
}

+ (NSMutableDictionary*)tableSchemas {
    return [[[SRKGlobals sharedObject] tableSchemas] copy];
}

+ (NSArray*)entityRelationships {
    return [[SRKGlobals sharedObject] systemEntityRelationshipsReadOnly];
}

+ (NSMutableArray*)entityRelationshipsForClass:(Class)class {
    
    NSMutableArray* relationships = [NSMutableArray new];
    
    for (SRKRelationship* r in [SharkORM entityRelationships]) {
        if ([[r.sourceClass description] isEqualToString:[class description]]) {
            [relationships addObject:r];
        }
    }
    
    return relationships;
    
}

+ (SRKRelationship*)entityRelationshipsForProperty:(NSString*)property inClass:(Class)class {
    
    NSMutableArray* relationships = [self entityRelationshipsForClass:class];
    
    for (SRKRelationship* r in relationships) {
        if ([r.sourceProperty isEqualToString:property]) {
            return r;
        }
    }
    
    return nil;
    
}

+ (SRKSettings*)getSettings {
    return [[SRKGlobals sharedObject] settings];
}

+ (void)setDelegate:(id)aDelegate {
    
    [[SRKGlobals sharedObject] setDelegate:aDelegate];
    
}

+ (void)setInsertCallbackBlock:(SRKGlobalEventCallback)callback {
    [[SRKGlobals sharedObject] setInsertCallback:callback];
}

+ (void)setUpdateCallbackBlock:(SRKGlobalEventCallback)callback {
    [[SRKGlobals sharedObject] setUpdateCallback:callback];
}

+ (void)setDeleteCallbackBlock:(SRKGlobalEventCallback)callback {
    [[SRKGlobals sharedObject] setDeleteCallback:callback];
}

+(sqlite3 *)defaultHandleForDatabase {
    
    return (sqlite3*)[[SRKGlobals sharedObject] defaultHandle];
    
}

+(sqlite3 *)handleForDatabaseNonBlocking:(NSString *)dbName {
    return [[SRKGlobals sharedObject] handleForName:dbName];
}

+(sqlite3 *)handleForDatabase:(NSString *)dbName {
    
    NSDate* startTime = [NSDate dateWithTimeIntervalSinceNow:1];
    while (![[SRKGlobals sharedObject] handleForName:dbName]) {
        [NSThread sleepForTimeInterval:0.01];
        if (startTime.timeIntervalSince1970 < [NSDate date].timeIntervalSince1970) {
            return nil;
        }
    }
    
    return [[SRKGlobals sharedObject] handleForName:dbName];
    
}

+(NSString *)databaseNameForClass:(Class)classDecl {
    
    NSString* dbName = nil;
    if ([classDecl isSubclassOfClass:[SRKObject class]]) {
        dbName = [classDecl storageDatabaseForClass];
    }
    
    if (!dbName) {
        if ([[SRKGlobals sharedObject] countOfHandles]) {
            return [[SRKGlobals sharedObject] defaultDatabaseName];
        }
    } else {
        return dbName;
    }
    
    return [SharkORM getSettings].defaultDatabaseName;
}

+(void)openDatabaseNamed:(NSString *)dbName {
    
    // bail if there is no databaseName passed in
    if (!dbName) {
        return;
    }
    
    if ([[SRKGlobals sharedObject] handleForName:dbName]) {
        return;
    }
    
    @synchronized([[SRKGlobals sharedObject] writeLockObject]) {
        
        sqlite3* dbHandle = nil;
        dbHandle = [[SRKGlobals sharedObject] handleForName:dbName];
        
        if (dbHandle) {
            sqlite3_close(dbHandle);
            dbHandle = nil;
        }
        
        /* open for user and join the system database */
        
        if (!dbHandle) {
            
            sqlite3_open([[[[SRKGlobals sharedObject] settings].databaseLocation stringByAppendingPathComponent: [NSString stringWithFormat:@"%@.db", dbName]] UTF8String], &dbHandle); // double pointer to allow void* casts later on!
            
#ifdef DEBUG
            NSLog(@"%s",[[[[SRKGlobals sharedObject] settings].databaseLocation stringByAppendingPathComponent: [NSString stringWithFormat:@"%@.db", dbName]] UTF8String]);
#endif
            
            sqlite3_exec(dbHandle, [NSString stringWithFormat:@"PRAGMA journal_mode=%@; PRAGMA default_cache_size = 200; PRAGMA cache_size = 200;", [[SRKGlobals sharedObject] settings].sqliteJournalingMode].UTF8String, 0, 0, 0);
            
            /* now store the handle within the void** array */
            [[SRKGlobals sharedObject] addHandle:dbHandle forDBName:dbName];
            [SharkORM registerSqliteExtensionsInDatabase:dbName];
            
            if (dbHandle) {
                
                /* create the revision table */
                sqlite3_exec(dbHandle, "CREATE TABLE IF NOT EXISTS _schemaRevision (revision INTEGER);", nil, nil, nil);
                sqlite3_exec(dbHandle, "CREATE TABLE IF NOT EXISTS _entityRevision (entityName TEXT,revision INTEGER);", nil, nil, nil);
                sqlite3_exec(dbHandle, "CREATE TABLE IF NOT EXISTS _floatPKTable (pkValue INTEGER); DELETE FROM _floatPKTable; INSERT INTO _floatPKTable VALUES (NULL);", nil, nil, nil);
                
            }
            else
            {
                /* database failed to open, raise an error */
                sqlite3_errmsg(dbHandle);
                
            }
        }
        
        /* now cache the system relationships for a performance improvement, only one relationship per table for this implementation */
        [SharkORM registerSystemExtensions:dbHandle];
        [SharkORM cacheDatabaseMetricsAfterChangeInDatabase:dbName];
        
    };
    
    /* now notify the delegate that the database has opened */
    if ([[SRKGlobals sharedObject] delegate]) {
        if ([[[SRKGlobals sharedObject] delegate] respondsToSelector:@selector(databaseOpened)]) {
            [[[SRKGlobals sharedObject] delegate] performSelector:@selector(databaseOpened)];
        }
    }
    
}

+ (void)cacheDatabaseMetricsAfterChangeInDatabase:(NSString*)dbName {
    
    [SharkORM cacheSchemaForDatabase:@"SQLITE_master" withHandle:[SharkORM handleForDatabase:dbName]];
    
    for (NSString* tablename in [[SRKGlobals sharedObject] tableSchemas].allKeys) {
        
        [SharkORM cachePrmaryKeyForTable:tablename inDatabase:dbName];
        [SharkORM cachePrmaryKeyTypeTable:tablename inDatabase:dbName];
        
    }
    
}

double ToRadian(double lat1);
double DiffRadian(double val1,double val2);
void spatialCalc(sqlite3_context *context, int argc, sqlite3_value **argv);

const double pi = 3.141592;
const double pid = 3.141592 / 180;

double ToRadian(double lat1)
{
    return lat1 * pid;
}

double DiffRadian(double val1,double val2)
{
    return ToRadian(val2) - ToRadian(val1);
}

void spatialCalc(sqlite3_context *context, int argc, sqlite3_value **argv)
{
    switch( sqlite3_value_type(argv[0]) )
    {
        case SQLITE_NULL:
        {
            sqlite3_result_null(context);
            break;
        }
        default:
        {
            double lat1 = sqlite3_value_double(argv[0]);
            double lng1 = sqlite3_value_double(argv[1]);
            double lat2 = sqlite3_value_double(argv[2]);
            double lng2 = sqlite3_value_double(argv[3]);
            double distance = (int)6378100 * 2 * asin(MIN(1, sqrt((pow(sin((DiffRadian(lat1, lat2)) / 2.0), 2.0) + cos(ToRadian(lat1)) * cos(ToRadian(lat2)) * pow(sin((DiffRadian(lng1, lng2)) / 2.0), 2.0)))));
            sqlite3_result_double(context, distance);
            break;
        }
    }
}

+ (void)registerSystemExtensions:(sqlite3*)thisDb {
    
    sqlite3_create_function(thisDb, "distancebetween", 4, SQLITE_ANY, NULL, &spatialCalc, 0, 0);
    
}

+ (void)cacheSchemaForDatabase:(NSString*)database withHandle:(sqlite3*)db {
    
    sqlite3_stmt* tableNames;
    if (sqlite3_prepare_v2(db, [[NSString stringWithFormat:@"SELECT name FROM %@ WHERE type='table';", database] UTF8String], -1, &tableNames, nil) == SQLITE_OK) {
        
        while (sqlite3_step(tableNames)== SQLITE_ROW) {
            
            NSString* tableName = (NSString*)[[SRKUtilities new] sqlite3_column_objc:tableNames column:0];
            NSMutableDictionary* fieldDef = [NSMutableDictionary new];
            
            /* now pull all of the columns out of the table with a pragma */
            
            sqlite3_stmt* fieldNames;
            if (sqlite3_prepare_v2(db, [[NSString stringWithFormat:@"PRAGMA table_info(%@);", tableName] UTF8String], -1, &fieldNames, nil) == SQLITE_OK) {
                
                while (sqlite3_step(fieldNames)== SQLITE_ROW) {
                    
                    NSString* fieldname = (NSString*)[[SRKUtilities new] sqlite3_column_objc:fieldNames column:1];
                    NSString* fieldType = (NSString*)[[SRKUtilities new] sqlite3_column_objc:fieldNames column:2];
                    
                    [fieldDef setObject:fieldType forKey:fieldname];
                    
                }
                
            }
            
            [[[SRKGlobals sharedObject] tableSchemas] setObject:fieldDef forKey:tableName];
            
            sqlite3_finalize(fieldNames);
        }
        
    }
    
    sqlite3_finalize(tableNames);
    
}

+ (void)cachePrmaryKeyForTable:(NSString*)table inDatabase:(NSString *)dbName {
    
    sqlite3_stmt* statement;
    
    NSString* sql = [NSString stringWithFormat:@"SELECT * FROM %@ LIMIT 1;", table];
    
    if (sqlite3_prepare_v2([SharkORM handleForDatabase:dbName], [sql UTF8String], -1, &statement, nil) == SQLITE_OK) {
        
        int result = sqlite3_step(statement);
        
        if (result == SQLITE_ROW || result == SQLITE_DONE) {
            
            for (int i=0; i < sqlite3_column_count(statement); i++) {
                
                int priKey = 0;
                
                sqlite3_table_column_metadata(
                                              [SharkORM handleForDatabase:dbName],                                   /* Connection handle */
                                              NULL,                                 /* Database name or NULL */
                                              [table UTF8String],                   /* Table name */
                                              sqlite3_column_name(statement, i),    /* Column name */
                                              NULL,                                 /* OUTPUT: Declared data type */
                                              NULL,                                 /* OUTPUT: Collation sequence name */
                                              NULL,                                 /* OUTPUT: True if NOT NULL constraint exists */
                                              &priKey,                              /* OUTPUT: True if column part of PK */
                                              NULL                                  /* OUTPUT: True if column is auto-increment */
                                              );
                
                if (priKey) {
                    [[[SRKGlobals sharedObject] primaryKeys] setObject:[NSString stringWithUTF8String:sqlite3_column_name(statement, i)] forKey:table];
                }
                
            }
            
        }
        
    } else {
        // 2do add error message / tablename checking
    }
    
    sqlite3_finalize(statement);
    
}

+ (void)cachePrmaryKeyTypeTable:(NSString*)table inDatabase:(NSString *)dbName {
    
    sqlite3_stmt* statement;
    
    NSString* sql = [NSString stringWithFormat:@"SELECT * FROM %@ LIMIT 1;", table];
    
    if (sqlite3_prepare_v2([SharkORM handleForDatabase:dbName], [sql UTF8String], -1, &statement, nil) == SQLITE_OK) {
        
        int result = sqlite3_step(statement);
        
        if (result == SQLITE_ROW || result == SQLITE_DONE) {
            
            for (int i=0; i < sqlite3_column_count(statement); i++) {
                
                int priKey = 0;
                const char* dataType = 0;
                
                sqlite3_table_column_metadata(
                                              [SharkORM handleForDatabase:dbName],  /* Connection handle */
                                              NULL,                                 /* Database name or NULL */
                                              [table UTF8String],                   /* Table name */
                                              sqlite3_column_name(statement, i),    /* Column name */
                                              &dataType,                            /* OUTPUT: Declared data type */
                                              NULL,                                 /* OUTPUT: Collation sequence name */
                                              NULL,                                 /* OUTPUT: True if NOT NULL constraint exists */
                                              &priKey,                              /* OUTPUT: True if column part of PK */
                                              NULL                                  /* OUTPUT: True if column is auto-increment */
                                              );
                
                if (priKey) {
                    
                    if ([[NSString stringWithUTF8String:dataType] isEqualToString:@"INTEGER"]) {
                        [[[SRKGlobals sharedObject] primaryTypes] setObject:[NSNumber numberWithInt:(int)SQLITE_INTEGER] forKey:table];
                    }
                    
                    if ([[NSString stringWithUTF8String:dataType] isEqualToString:@"TEXT"]) {
                        [[[SRKGlobals sharedObject] primaryTypes] setObject:[NSNumber numberWithInt:(int)SQLITE_TEXT] forKey:table];
                    }
                    
                }
                
            }
            
        }
        
    } else {
        // 2do add error message / tablename checking
        // sqlite3_errmsg([NSString tableName]);
    }
    
    sqlite3_finalize(statement);
    
}

#pragma mark - sqlite objc interface

+(void)setSchemaRevision:(int)revision inDatabase:(NSString *)dbName {
    
    sqlite3_exec([SharkORM handleForDatabase:dbName], [[NSString stringWithFormat:@"UPDATE _schemaRevision SET revision=%i; ", revision] UTF8String] , nil, nil, nil);
    
}

+(void)setEntityRevision:(int)revision forEntity:(NSString*)entity inDatabase:(NSString *)dbName {
    
    sqlite3_exec([SharkORM handleForDatabase:dbName], [[NSString stringWithFormat:@"UPDATE _entityRevision SET revision=%i WHERE entityName='%@'; ", revision, entity] UTF8String] , nil, nil, nil);
    
}

+(int)getEntityRevision:(NSString*)entity inDatabase:(NSString *)dbName {
    
    sqlite3_stmt* statement;
    int retVal = 0;
    
    sqlite3* hnd = [SharkORM handleForDatabase:dbName];
    
    if (sqlite3_prepare_v2(hnd, [[NSString stringWithFormat:@"SELECT revision FROM _entityRevision WHERE entityName='%@' LIMIT 1;", entity] UTF8String], -1, &statement, nil) == SQLITE_OK) {
        
        /* see if there is a row */
        
        int rowCount = 0;
        
        while (sqlite3_step(statement) == SQLITE_ROW) {
            rowCount++;
            retVal = sqlite3_column_int(statement, 0);
        }
        
        if (!rowCount) {
            sqlite3_exec([SharkORM handleForDatabase:dbName], [[NSString stringWithFormat:@"INSERT INTO _entityRevision VALUES ('%@',0);",entity] UTF8String] , nil, nil, nil);
        }
    }
    else {
        NSLog(@"error >> %s", sqlite3_errmsg(hnd));
    }
    
    sqlite3_finalize(statement);
    
    return retVal;
    
}

+(int)getSchemaRevisioninDatabase:(NSString *)dbName{
    
    sqlite3_stmt* statement;
    int retVal = 0;
    
    sqlite3* hnd = [SharkORM handleForDatabase:dbName];
    
    if (sqlite3_prepare_v2(hnd, "SELECT revision FROM _schemaRevision LIMIT 1;", -1, &statement, nil) == SQLITE_OK) {
        
        /* see if there is a row */
        
        int rowCount = 0;
        
        while (sqlite3_step(statement) == SQLITE_ROW) {
            rowCount++;
            retVal = sqlite3_column_int(statement, 0);
        }
        
        if (!rowCount) {
            sqlite3_exec([SharkORM handleForDatabase:dbName], "INSERT INTO _schemaRevision VALUES (0);", nil, nil, nil);
        }
    }
    else {
        NSLog(@"error >> %s", sqlite3_errmsg(hnd));
    }
    
    sqlite3_finalize(statement);
    
    return retVal;
    
}

+ (void)createTableNamed:(NSString*)tableName withPrimaryKeyType:(SRKPrimaryKeyColumnType)keyType inDatabase:(NSString *)dbName {
    
    NSString* sql = @"CREATE TABLE IF NOT EXISTS %@ (Id %@); CREATE INDEX IF NOT EXISTS idx_%@_prikey ON %@ (Id);";
    NSString* pri = nil;
    
    if (keyType == SRK_PRIKEY_INTEGER) {
        pri = @"INTEGER PRIMARY KEY AUTOINCREMENT";
    } else {
        pri = @"TEXT PRIMARY KEY";
    }
    
    NSString* execSql = [NSString stringWithFormat:sql, tableName, pri, tableName, tableName];
    
    sqlite3_exec([SharkORM handleForDatabase:dbName], [execSql UTF8String], nil, nil, nil);
    
    NSMutableDictionary* fields = [NSMutableDictionary new];
    [fields setObject:pri forKey:SRK_DEFAULT_PRIMARY_KEY_NAME];
    [[[SRKGlobals sharedObject] tableSchemas] setObject:fields forKey:tableName];
    
    [[[SRKGlobals sharedObject] primaryKeys] setObject:SRK_DEFAULT_PRIMARY_KEY_NAME forKey:tableName];
    [[[SRKGlobals sharedObject] primaryTypes] setObject:[NSNumber numberWithInt:keyType] forKey:tableName];
    
}

+(void)executeSQL:(NSString*)sql inDatabase:(NSString *)dbName {
    sqlite3* handle = nil;
    if (!dbName) {
        /* get the default database */
        handle = [[SRKGlobals sharedObject] defaultHandle];
    } else {
        handle = [[SRKGlobals sharedObject] handleForName:dbName];
    }
    char* error = 0;
    sqlite3_exec(handle, [sql UTF8String], nil, nil, &error);
    if (error) {
        free(error);
    }
}


+(void)indexFieldInTable:(NSString*)tableName columnName:(NSString*)columnName inDatabase:(NSString *)dbName {
    
    NSString* execSql = [NSString stringWithFormat:@"CREATE INDEX idx_%@_%@ ON %@ (%@ asc);", tableName,columnName, tableName, columnName];
    sqlite3_exec([SharkORM handleForDatabase:dbName], [execSql UTF8String], nil, nil, nil);
    
}

+ (void)removeColumnFromTable:(NSString*)tableName columnName:(NSString*)columnName inDatabase:(NSString*)dbName {
    
    NSMutableDictionary* fields = [[[SRKGlobals sharedObject] tableSchemas] objectForKey:tableName];
    NSObject* removedObject = nil;
    for (NSString* fieldName in fields.allKeys) {
        if ([fieldName isEqualToString:columnName]) {
            removedObject = fieldName;
        }
    }
    
    if (removedObject) {
        [fields removeObjectForKey:removedObject];
    }
    
    [[[SRKGlobals sharedObject] tableSchemas] setObject:fields forKey:tableName];
    
    /* re-jig the table now */
    
    NSString* fieldDefs = @"";
    
    if ([SharkORM primaryKeyType:tableName] == SRK_PRIKEY_INTEGER) {
        fieldDefs = [fieldDefs stringByAppendingFormat:@"Id %@", @"INTEGER PRIMARY KEY AUTOINCREMENT"];
    } else {
        fieldDefs = [fieldDefs stringByAppendingFormat:@"Id %@", @"TEXT PRIMARY KEY"];
    }
    
    for (NSString* fieldName in fields.allKeys) {
        if (![fieldName isEqualToString:SRK_DEFAULT_PRIMARY_KEY_NAME]) {
            fieldDefs = [fieldDefs stringByAppendingFormat:@",%@ %@", fieldName, [fields objectForKey:fieldName]];
        }
    }
    
    NSString* srcFields = SRK_DEFAULT_PRIMARY_KEY_NAME;
    
    for (NSString* fieldName in fields.allKeys) {
        if (![fieldName isEqualToString:SRK_DEFAULT_PRIMARY_KEY_NAME]) {
            srcFields = [srcFields stringByAppendingFormat:@",%@", fieldName];
        }
    }
    
    NSString* execSql = [NSString stringWithFormat:@"CREATE TABLE %@_temp (%@); INSERT INTO %@_temp (%@) SELECT %@ FROM %@; DROP TABLE %@; ALTER TABLE %@_temp RENAME TO %@;", tableName, fieldDefs, tableName,srcFields, srcFields, tableName, tableName, tableName, tableName];
    sqlite3_exec([SharkORM handleForDatabase:dbName], [execSql UTF8String], nil, nil, nil);
    
    /* remove from the cache as well */
    
    NSMutableArray* relToRemove = [NSMutableArray new];
    for (SRKRelationship * r in [[SRKGlobals sharedObject] systemEntityRelationshipsReadOnly]) {
        if (([[r.sourceClass description] isEqualToString:tableName] && [r.sourceProperty isEqualToString:columnName]) || ([[r.targetClass description] isEqualToString:tableName] && [r.targetProperty isEqualToString:columnName])) {
            [relToRemove addObject:r];
        }
    }
    
    for (NSObject* o in relToRemove) {
        [[[SRKGlobals sharedObject] systemEntityRelationships] removeObject:o];
    }
    
}

+ (NSString*)currentSqliteTypeForColumn:(NSString*)column inTable:(NSString*)tableName {
    
    NSString* retVal = @"";
    NSDictionary* d = [[[SRKGlobals sharedObject] tableSchemas] objectForKey:tableName];
    if (d) {
        NSString* def = [d objectForKey:column];
        if (def) {
            retVal = def;
        }
    }
    return retVal;
}

+ (int)currentEntityTypeForColumn:(NSString*)column inTable:(NSString*)tableName {
    
    int retVal = 0;
    
    NSDictionary* d = [[[SRKGlobals sharedObject] tableSchemas] objectForKey:tableName];
    if (d) {
        NSString* def = [d objectForKey:column];
        if (def) {
            if ([def isEqualToString:@"TEXT"]) {
                retVal = SRK_COLUMN_TYPE_TEXT;
            }
            if ([def isEqualToString:@"TEXT COLLATE NOCASE"]) {
                retVal = SRK_COLUMN_TYPE_TEXT;
            }
            if ([def isEqualToString:@"NUMBER"]) {
                retVal = SRK_COLUMN_TYPE_NUMBER;
            }
            if ([def isEqualToString:@"INTEGER"]) {
                retVal = SRK_COLUMN_TYPE_INTEGER;
            }
            if ([def isEqualToString:@"DATETIME"]) {
                retVal = SRK_COLUMN_TYPE_DATE;
            }
            if ([def isEqualToString:@"BLOB"]) {
                retVal = SRK_COLUMN_TYPE_BLOB;
            }
        }
    }
    
    return retVal;
    
}

+ (NSString*)sqliteTypeForColumnStorageType:(SRKColumnStorageType)columnType {
    
    NSString* type = @"";
    
    if (columnType == SRK_COLUMN_TYPE_TEXT) {
        type = @"TEXT";
    } else if (columnType == SRK_COLUMN_TYPE_NUMBER) {
        type = @"NUMBER";
    } else if (columnType == SRK_COLUMN_TYPE_INTEGER) {
        type = @"INTEGER";
    } else if (columnType == SRK_COLUMN_TYPE_DATE) {
        
        if ([[SharkORM getSettings] useEpochDates]) {
            type = @"DATETIME";
        } else {
            type = @"TEXT";
        }
        
    } else if (columnType == SRK_COLUMN_TYPE_IMAGE) {
        type = @"BLOB";
    } else if (columnType == SRK_COLUMN_TYPE_TEXT) {
        type = @"TEXT";
    } else if (columnType == SRK_COLUMN_TYPE_BLOB) {
        type = @"BLOB";
    } else if (columnType == SRK_COLUMN_TYPE_ENTITYCLASS) {
        /* special case, the column type is whatever the Id column of the table is */
        type = @"INTEGER";
    } else if (columnType == SRK_COLUMN_TYPE_ENTITYCOLLECTION) {
        /* special case, column type is nil because this is a reverse query */
        type = nil;
    }
    
    return type;
}


+ (void)changeColumnTypeInTable:(NSString*)tableName columnName:(NSString*)columnName originalType:(SRKColumnStorageType)originalType originalStorage:(NSString*)originalStorage newColumnType:(SRKColumnStorageType)newType newStorage:(NSString*)newStorage inDatabase:(NSString*)dbName {
    
    if (newType == SRK_COLUMN_TYPE_ENTITYCLASS || newType == SRK_COLUMN_TYPE_ENTITYCOLLECTION || newType == SRK_COLUMN_TYPE_IMAGE) {
        /* these column types are affinitive */
        return;
    }
    
    if (newType == SRK_COLUMN_TYPE_DATE && ([originalStorage isEqualToString:@"TEXT"] && [newStorage isEqualToString:@"DATETIME"])) {
        
        [self addColumnToTable:tableName columnName:[NSString stringWithFormat:@"temp_%@", columnName] columnType:newType inDatabase:dbName withDefaultValue:nil];
        sqlite3_exec([SharkORM handleForDatabase:dbName], [[NSString stringWithFormat:@"UPDATE %@ SET temp_%@ = dateFromString(%@);", tableName, columnName, columnName] UTF8String], nil, nil, nil);
        [self removeColumnFromTable:tableName columnName:columnName inDatabase:dbName];
        [self addColumnToTable:tableName columnName:columnName columnType:newType inDatabase:dbName withDefaultValue:nil];
        sqlite3_exec([SharkORM handleForDatabase:dbName], [[NSString stringWithFormat:@"UPDATE %@ SET %@ = temp_%@;", tableName, columnName, columnName] UTF8String], nil, nil, nil);
        [self removeColumnFromTable:tableName columnName:[NSString stringWithFormat:@"temp_%@", columnName] inDatabase:dbName];
        
    } else if (newType == SRK_COLUMN_TYPE_DATE && ([originalStorage isEqualToString:@"DATETIME"] && [newStorage isEqualToString:@"TEXT"])) {
        
        [self addColumnToTable:tableName columnName:[NSString stringWithFormat:@"temp_%@", columnName] columnType:newType inDatabase:dbName withDefaultValue:nil];
        sqlite3_exec([SharkORM handleForDatabase:dbName], [[NSString stringWithFormat:@"UPDATE %@ SET temp_%@ = stringFromDate(%@);", tableName, columnName, columnName] UTF8String], nil, nil, nil);
        [self removeColumnFromTable:tableName columnName:columnName inDatabase:dbName];
        [self addColumnToTable:tableName columnName:columnName columnType:newType inDatabase:dbName withDefaultValue:nil];
        sqlite3_exec([SharkORM handleForDatabase:dbName], [[NSString stringWithFormat:@"UPDATE %@ SET %@ = temp_%@;", tableName, columnName, columnName] UTF8String], nil, nil, nil);
        [self removeColumnFromTable:tableName columnName:[NSString stringWithFormat:@"temp_%@", columnName] inDatabase:dbName];
        
    }
    
}


+ (void)addColumnToTable:(NSString*)tableName columnName:(NSString*)columnName columnType:(SRKColumnStorageType)columnType inDatabase:(NSString*)dbName withDefaultValue:(id)value {
    
    NSString* sql = @"ALTER TABLE %@ ADD COLUMN %@ %@;";
    NSString* type = [self sqliteTypeForColumnStorageType:columnType];
    
    if (type) {
        NSString* execSql = [NSString stringWithFormat:sql, tableName, columnName, type];
        
        sqlite3_exec([SharkORM handleForDatabase:dbName], [execSql UTF8String], nil, nil, nil);
        
        NSMutableDictionary* fields = [[[SRKGlobals sharedObject] tableSchemas] objectForKey:tableName];
        [fields setObject:type forKey:columnName];
        [[[SRKGlobals sharedObject] tableSchemas] setObject:fields forKey:tableName];
    }
    
    if (value) {
        
        sqlite3_stmt* statement;
        
        sql = [NSString stringWithFormat:@"UPDATE %@ SET %@ = ?;", tableName , columnName];
        
        if (sqlite3_prepare_v2([SharkORM handleForDatabase:dbName], [sql UTF8String], -1, &statement, nil) == SQLITE_OK) {
            
            [[SRKUtilities new] bindParameters:@[value] toStatement:statement];
            
            int result = sqlite3_step(statement);
            
            if (result == SQLITE_DONE) {
                
            } else {
                /* error in prepare statement */
                if ([[SRKGlobals sharedObject] delegate] && [[[SRKGlobals sharedObject] delegate] respondsToSelector:@selector(databaseError:)]) {
                    
                    SRKError* e = [SRKError new];
                    e.sqlQuery = sql;
                    e.errorMessage = [NSString stringWithUTF8String:sqlite3_errmsg([SharkORM handleForDatabase:dbName])];
                    [[[SRKGlobals sharedObject] delegate] databaseError:e];
                    
                }
            }
        }
        
        sqlite3_finalize(statement);
        
    }
    
}

+(void)addEntityRelationship:(SRKRelationship*)r inDatabase:(NSString *)dbName {
    
    /* standard relationship allocation */
    [[[SRKGlobals sharedObject] systemEntityRelationships] addObject:r];
    [self indexFieldInTable:[r.targetClass description] columnName:r.targetProperty inDatabase:dbName];
    
    /* now create the inverse of the relationship to allow one-to-many optimisation */
    [self indexFieldInTable:[r.sourceClass description] columnName:r.sourceProperty inDatabase:dbName];
    
}

+(void)prepareFTSTableForClass:(Class)classDecl withPropertyList:(NSArray*)properties {
    
    NSMutableString* propertiesList = [NSMutableString new];
    for (NSString* p in properties) {
        if (propertiesList.length > 0) {
            [propertiesList appendString:@", "];
        }
        [propertiesList appendString:p];
    }
    
    BOOL dropItLikeItsHot = NO;
    if (![FTSRegistry registryForTable:[classDecl description]]) {
        dropItLikeItsHot = YES;
    } else {
        FTSRegistry* reg = [FTSRegistry registryForTable:[classDecl description]];
        if (![reg.columns isEqualToString:[NSString stringWithString:propertiesList]]) {
            dropItLikeItsHot = YES;
        }
        [reg remove];
    }
    
    if (dropItLikeItsHot) {
        
        [SharkORM executeSQL:[NSString stringWithFormat:@"DROP TABLE fts_%@;", [classDecl description]] inDatabase:nil];
        [SharkORM executeSQL:[NSString stringWithFormat:@"CREATE VIRTUAL TABLE fts_%@ USING fts3(%@);",[classDecl description],propertiesList] inDatabase:nil];
        
        FTSRegistry* reg = [FTSRegistry new];
        reg.tableName = [classDecl description];
        reg.uptodate = NO;
        reg.columns = propertiesList;
        [reg commit];
        
        [SharkORM executeSQL:[NSString stringWithFormat:@"INSERT INTO fts_%@(docid,%@) SELECT Id, %@ FROM %@;", [classDecl description],propertiesList,propertiesList,[classDecl description]] inDatabase:nil];
        
    }
    
}

+(void)refactorTableFromEntityDefinition:(NSDictionary*)definition forTable:(NSString*)table inDatabase:(NSString *)dbName primaryKeyAsString:(BOOL)pkIsString {
    
    /* check the table even exists */
    if ([[[SRKGlobals sharedObject] primaryKeys] objectForKey:table] == nil) {
        if (pkIsString) {
            [SharkORM createTableNamed:table withPrimaryKeyType:SRK_PRIKEY_GUID inDatabase:dbName];
        } else {
            [SharkORM createTableNamed:table withPrimaryKeyType:SRK_PRIKEY_INTEGER inDatabase:dbName];
        }
        
    }
    
    /* build a list of all the fields that no longer exist in the table */
    NSMutableDictionary* currentFields = [[[SRKGlobals sharedObject] tableSchemas] objectForKey:table];
    
    /* add in any new fields */
    NSMutableDictionary* newFields = [NSMutableDictionary new];
    
    for (NSString* f in definition.allKeys) {
        if ([currentFields objectForKey:f] == nil) {
            /* this one needs adding */
            [newFields setObject:[definition objectForKey:f] forKey:f];
        } else {
            /* this column exists! But is it the correct type? */
            if (![[self sqliteTypeForColumnStorageType:[(NSNumber*)[definition valueForKey:f] intValue]] isEqualToString:[self currentSqliteTypeForColumn:f inTable:table]]) {
                /* the type has changed */
                [self changeColumnTypeInTable:table columnName:f originalType:[self currentEntityTypeForColumn:f inTable:table] originalStorage:[self currentSqliteTypeForColumn:f inTable:table] newColumnType:[(NSNumber*)[definition valueForKey:f] intValue] newStorage:[self sqliteTypeForColumnStorageType:[(NSNumber*)[definition valueForKey:f] intValue]] inDatabase:dbName];
            }
        }
    }
    
    /* now create the fields */
    /* now we check to see if there is a default value for this new column */
    Class entityClass = NSClassFromString(table);
    if (!entityClass) {
        entityClass = NSClassFromString([[SRKGlobals sharedObject] getFQNameForClass:table]);
    }
    NSDictionary* defaultValues = [entityClass defaultValuesForEntity];
    
    for (NSString* s in newFields.allKeys) {
        id value = nil;
        if (defaultValues && [defaultValues objectForKey:s]) {
            value = [defaultValues objectForKey:s];
        }
        [SharkORM addColumnToTable:table columnName:s columnType:[(NSNumber*)[newFields valueForKey:s] intValue] inDatabase:dbName withDefaultValue:value];
    }
    
    /* change the types of columns */
    
}

+(void)removeMissingFieldsFromEntityDefinition:(NSDictionary*)definition forTable:(NSString*)table inDatabase:(NSString *)dbName {
    
    /* check the table even exists */
    if ([[[SRKGlobals sharedObject] primaryKeys] objectForKey:table] == nil) {
        [SharkORM createTableNamed:table withPrimaryKeyType:SRK_PRIKEY_INTEGER inDatabase:dbName];
    }
    
    /* build a list of all the fields that no longer exist in the table */
    NSMutableDictionary* currentFields = [[[SRKGlobals sharedObject] tableSchemas] objectForKey:table];
    NSMutableArray* nonPresentFields = [NSMutableArray new];
    
    for (NSString* f in currentFields.allKeys) {
        if ([definition objectForKey:f] == nil) {
            if (![f isEqualToString:SRK_DEFAULT_PRIMARY_KEY_NAME]) {
                [nonPresentFields addObject:f];
            }
        }
    }
    
    for (NSString* f in nonPresentFields) {
        [SharkORM removeColumnFromTable:table columnName:f inDatabase:dbName];
    }
    
}

void dateFromString(sqlite3_context *context, int argc, sqlite3_value **argv)
{
    switch( sqlite3_value_type(argv[0]) )
    {
        case SQLITE_TEXT:
        {
            const char* date = (const char*)sqlite3_value_text(argv[0]);
            NSString* strVal = [NSString stringWithUTF8String:date];
            NSNumber* numVal = [NSNumber numberWithInt:0];
            
            /* check to see if this field is a valid full date */
            NSDateFormatter *dateFormat = [[NSDateFormatter alloc] init];
            [dateFormat setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
            NSDate* dValue = [dateFormat dateFromString:(NSString*)strVal];
            if (dValue) {
                if ([dValue isKindOfClass:[NSDate class]]) {
                    numVal = [NSNumber numberWithDouble:[dValue timeIntervalSince1970]];
                } else {
                    numVal = [NSNumber numberWithInt:0];
                }
                
            }
            
            double retVal = [numVal doubleValue];
            if (retVal == 0) {
                
                sqlite3_result_null(context);
                break;
                
            } else {
                
                sqlite3_result_double(context, retVal);
                break;
                
            }
            
        }
        default:
        {
            sqlite3_result_null(context);
            break;
        }
    }
}

void stringFromDate(sqlite3_context *context, int argc, sqlite3_value **argv);

void stringFromDate(sqlite3_context *context, int argc, sqlite3_value **argv)
{
    switch( sqlite3_value_numeric_type(argv[0]) )
    {
        case SQLITE_FLOAT:
        {
            double date = sqlite3_value_double(argv[0]);
            
            NSDate * dte = [NSDate dateWithTimeIntervalSince1970:(double)date];
            
            /* check to see if this field is a valid full date */
            NSDateFormatter *dateFormat = [[NSDateFormatter alloc] init];
            [dateFormat setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
            NSString* dValue = [dateFormat stringFromDate:dte];
            
            sqlite3_result_text(context, [dValue UTF8String], -1, NULL);
            
            break;
        }
        case SQLITE_INTEGER:
        {
            unsigned int date = sqlite3_value_int(argv[0]);
            
            NSDate * dte = [NSDate dateWithTimeIntervalSince1970:(double)date];
            
            /* check to see if this field is a valid full date */
            NSDateFormatter *dateFormat = [[NSDateFormatter alloc] init];
            [dateFormat setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
            NSString* dValue = [dateFormat stringFromDate:dte];
            
            sqlite3_result_text(context, [dValue UTF8String], -1, NULL);
            
            break;
        }
        default:
        {
            sqlite3_result_null(context);
            break;
        }
    }
}

+(void)registerSqliteExtensionsInDatabase:(NSString*)dbName {
    sqlite3_create_function([SharkORM handleForDatabase:dbName], "dateFromString", 1, SQLITE_ANY, NULL, &dateFromString, 0, 0);
    sqlite3_create_function([SharkORM handleForDatabase:dbName], "stringFromDate", 1, SQLITE_ANY, NULL, &stringFromDate, 0, 0);
}

/*
 ** additional objective c style extensions
 */



+(void)closeDatabaseNamed:(NSString*)dbName {
    if ([SharkORM handleForDatabase:dbName]) {
        sqlite3_close([SharkORM handleForDatabase:dbName]);
        [[SRKGlobals sharedObject] removeHandleForName:dbName];
    }
}

+ (SRKRawResults *)rawQuery:(NSString *)sql {
    
    SRKRawResults* returnValue = [SRKRawResults new];
    returnValue.rawResults = [NSMutableArray new];
    
    sqlite3_stmt* statement;
    sqlite3* dbHandle = [SharkORM defaultHandleForDatabase];
    
    [SRKTransaction blockUntilTransactionFinished];
    
    int prepareResult = sqlite3_prepare_v2(dbHandle, [sql UTF8String], (int)sql.length, &statement, NULL);
    if (prepareResult == SQLITE_OK) {
        
        int status = sqlite3_step(statement);
        
        while (status == SQLITE_ROW) {
            
            @autoreleasepool {
                
                NSMutableDictionary* record = [[NSMutableDictionary alloc] init];
                
                /* loop thorugh the record */
                for (int p=0; p<sqlite3_column_count(statement); p++) {
                    
                    NSString* columnName = [NSString stringWithUTF8String:sqlite3_column_name(statement, p)];
                    SRKUtilities* dba = [SRKUtilities new];
                    columnName = [dba normalizedColumnName:columnName];
                    NSObject* value = [[SRKUtilities new] sqlite3_column_objc:statement column:p];
                    [record setObject:value forKey:columnName];
                    
                }
                
                [returnValue.rawResults addObject:record];
                
                
            }
            
            status = sqlite3_step(statement);
            
        }
        
    } else {
        
        if ([SRKTransaction transactionIsInProgress]) {
            [SRKTransaction failTransactionWithCode:SRKTransactionFailed];
        }
        
        SRKError* e = [SRKError new];
        e.sqlQuery = sql;
        e.errorMessage = [NSString stringWithUTF8String:sqlite3_errmsg(dbHandle)];
        
        /* error in prepare statement */
        if ([[SRKGlobals sharedObject] delegate] && [[[SRKGlobals sharedObject] delegate] respondsToSelector:@selector(databaseError:)]) {
            [[[SRKGlobals sharedObject] delegate] databaseError:e];
        }
        
        returnValue.error = e;
        
    }
    
    sqlite3_finalize(statement);
    
    return returnValue;
    
}

#pragma mark - user object functions


#pragma mark - core sync functionality

+(NSString*)primaryKeyForTable:(NSString*)tableName {
    
    NSString* retVal = @"";
    
    NSString* key = [[[SRKGlobals sharedObject] primaryKeys] objectForKey:tableName];
    if (key) {
        retVal = key;
    }
    
    return retVal;
    
}

+(int)primaryKeyType:(NSString*)tableName {
    
    int retVal = 0;
    
    NSNumber* type = [[[SRKGlobals sharedObject] primaryTypes] objectForKey:tableName];
    if (type) {
        retVal = [type intValue];
    }
    
    return retVal;
    
}

#pragma mark - object entity support

-(BOOL)commitObject:(SRKObject *)entity {
    
    BOOL        succeded = NO;
    
    @autoreleasepool {
        
        int         priKeyType = [SharkORM primaryKeyType:[entity.class description]];
        
        NSString*   className = [entity.class description];
        NSString*   databaseNameForClass = [SharkORM databaseNameForClass:entity.class];
        sqlite3*    databaseHandle = [SharkORM handleForDatabase:databaseNameForClass];
        
        // the following will block if there is a transaction occouring for anything other than a current transaction block
        [SRKTransaction blockUntilTransactionFinished];
        
        if ([SRKTransaction transactionIsInProgress]) {
            
            // check to see if there was an error within the transaction so far and return if there was.
            if ([SRKTransaction currentTransactionStatus] != SRKTransactionPassed) {
                return NO;
            }
            
            // this means we are currently within a transaction, so we need to create an information object to describe what is happening before the commit
            if (!entity.transactionInfo) {
                SRKTransactionInfo* info = [SRKTransactionInfo new];
                info.eventType = entity.exists ? EventUpdate : EventInsert;
                [info copyObjectValuesIntoRestorePoint:entity];
                entity.transactionInfo = info;
            } else {
                entity.transactionInfo.eventType = entity.exists ? EventUpdate : EventInsert;
            }
            
            [SRKTransaction startTransactionForDatabaseConnection:databaseNameForClass];
            [SRKTransaction addReferencedObjectToTransactionList:entity];
            
        }
        
        @synchronized([[SRKGlobals sharedObject] writeLockObject]) {
            
            sqlite3_stmt* statement;
            
            NSString* fieldNames = @"";
            NSString* placeholders = @"";
            NSMutableArray* keys = [[NSMutableArray alloc] init];
            for (NSString* key in [entity fieldNames]) {
                
                [keys addObject:key];
                
                if ([fieldNames length]) {
                    fieldNames = [fieldNames stringByAppendingString:@", "];
                    placeholders = [placeholders stringByAppendingString:@", "];
                }
                
                fieldNames = [fieldNames stringByAppendingString:key];
                placeholders = [placeholders stringByAppendingString:@"?"];
                
            }
            
            NSString* sql = [NSString stringWithFormat:@"INSERT OR REPLACE INTO %@ (%@) VALUES (%@);", className , fieldNames, placeholders];
            
            if (sqlite3_prepare_v2([SharkORM handleForDatabase:databaseNameForClass], [sql UTF8String], (int)sql.length, &statement, NULL) == SQLITE_OK) {
                
                /* now bind the data into the table */
                
                NSMutableArray* values = [NSMutableArray new];
                for (NSString* key in keys) {
                    id value = [entity getField:key];
                    [values addObject:value ? value : [NSNull null]];
                }
                
                [[SRKUtilities new] bindParameters:values toStatement:statement];
                
                bool keepTrying = YES;
                while (keepTrying) {
                    int result = sqlite3_step(statement);
                    switch (result) {
                        case SQLITE_DONE:
                        {
                            keepTrying = NO;
                            if (priKeyType == SQLITE_INTEGER) {
                                if (!entity.exists) {
                                    [entity setField:SRK_DEFAULT_PRIMARY_KEY_NAME value:@(sqlite3_last_insert_rowid(databaseHandle))];
                                }
                                /* check to see if this object is a fts object and clear the existing row */
                                if ([[entity class] FTSParametersForEntity]) {
                                    [SharkORM executeSQL:[NSString stringWithFormat:@"DELETE FROM fts_%@ WHERE docid = %@", [[entity class] description], [entity getField:SRK_DEFAULT_PRIMARY_KEY_NAME]] inDatabase:nil];
                                }
                            } else {
                                /* check to see if this object is a fts object and clear the existing row */
                                if ([[entity class] FTSParametersForEntity]) {
                                    [SharkORM executeSQL:[NSString stringWithFormat:@"DELETE FROM fts_%@ WHERE docid = '%@'", [[entity class] description], [entity getField:SRK_DEFAULT_PRIMARY_KEY_NAME]] inDatabase:nil];
                                }
                            }
                            if (!entity.exists) {
                                /* now we need to register this object with the default registry, first check to see if the user wants a default domain */
                                entity.exists = YES;
                                if ([SharkORM getSettings].defaultManagedObjects) {
                                    [entity setManagedObjectDomain:[SharkORM getSettings].defaultObjectDomain];
                                }
                            }
                            succeded = YES;
                            
                        }
                            break;
                        case SQLITE_LOCKED:
                        {
                            NSString* err = [NSString stringWithUTF8String:sqlite3_errmsg(databaseHandle)];
                            NSLog(@"%@", err);
                            sleep(0.1);
                            sqlite3_reset(statement);
                        }
                            break;
                        case SQLITE_BUSY:
                        {
                            NSString* err = [NSString stringWithUTF8String:sqlite3_errmsg(databaseHandle)];
                            NSLog(@"%@", err);
                            sleep(0.1);
                            sqlite3_reset(statement);
                        }
                            break;
                        default:
                        {
                            
                            // check we are not ignoring errors in the commit options.
                            if (entity.commitOptions.raiseErrors) {
                                
                                if (entity.transactionInfo) {
                                    // we are in a transaction, and it's gone south so mark the transaction as failed
                                    [SRKTransaction failTransactionWithCode:SRKTransactionFailed];
                                }
                                
                                /* error in prepare statement */
                                if ([[SRKGlobals sharedObject] delegate] && [[[SRKGlobals sharedObject] delegate] respondsToSelector:@selector(databaseError:)]) {
                                    
                                    SRKError* e = [SRKError new];
                                    e.sqlQuery = sql;
                                    e.errorMessage = [NSString stringWithUTF8String:sqlite3_errmsg(databaseHandle)];
                                    [[[SRKGlobals sharedObject] delegate] databaseError:e];
                                    
                                }
                            }
                            
                        }
                            break;
                    }
                }
                
            } else {
                
                // check we are not ignoring errors in the commit options.
                if (entity.commitOptions.raiseErrors) {
                    
                    if (entity.transactionInfo) {
                        // we are in a transaction, and it's gone south so mark the transaction as failed
                        [SRKTransaction failTransactionWithCode:SRKTransactionFailed];
                    }
                    
                    // an error occoured
                    /* error in prepare statement */
                    if ([[SRKGlobals sharedObject] delegate] && [[[SRKGlobals sharedObject] delegate] respondsToSelector:@selector(databaseError:)]) {
                        
                        SRKError* e = [SRKError new];
                        e.sqlQuery = sql;
                        e.errorMessage = [NSString stringWithUTF8String:sqlite3_errmsg(databaseHandle)];
                        [[[SRKGlobals sharedObject] delegate] databaseError:e];
                        
                    }
                    
                }
            }
            
            sqlite3_finalize(statement);
            
            /* update the FTS table if required */
            /* check to see if this object is a fts object and clear the existing row */
            if ([[entity class] FTSParametersForEntity]) {
                NSMutableString* propertiesList = [NSMutableString new];
                
                for (NSString* p in [[entity class] FTSParametersForEntity]) {
                    if (propertiesList.length > 0) {
                        [propertiesList appendString:@", "];
                    }
                    [propertiesList appendString:p];
                }
                
                if ([entity.class FTSParametersForEntity] != nil) {
                    if (priKeyType == SQLITE_INTEGER) {
                        [SharkORM executeSQL:[NSString stringWithFormat:@"INSERT INTO fts_%@(docid, %@) SELECT Id, %@ FROM %@ WHERE Id = %@", [[entity class] description],propertiesList,propertiesList, [[entity class] description], [entity getField:SRK_DEFAULT_PRIMARY_KEY_NAME]] inDatabase:nil];
                    } else {
                        [SharkORM executeSQL:[NSString stringWithFormat:@"INSERT INTO fts_%@(docid, %@) SELECT Id, %@ FROM %@ WHERE Id = '%@'", [[entity class] description],propertiesList,propertiesList, [[entity class] description], [entity getField:SRK_DEFAULT_PRIMARY_KEY_NAME]] inDatabase:nil];
                    }
                }
                
            }
            
        }
        
        [entity setBase];
        
    }
    
    // if we are not within a transaction then execute any supplied blocks within the commit object
    if (succeded && entity.commitOptions.postCommitBlock && ![SRKTransaction transactionIsInProgress]) {
        entity.commitOptions.postCommitBlock();
    }
    
    return succeded;
    
}

-(BOOL)removeObject:(SRKObject *)entity {
    
    __block BOOL    succeded = NO;
    NSString* databaseNameForClass = [SharkORM databaseNameForClass:entity.class];
    NSString* entityName = [entity.class description];
    
    // the following will block if there is a transaction occouring for anything other than a current transaction block
    [SRKTransaction blockUntilTransactionFinished];
    
    if ([SRKTransaction transactionIsInProgress]) {
        
        // check to see if there was an error within the transaction so far and return if there was.
        if ([SRKTransaction currentTransactionStatus] != SRKTransactionPassed) {
            return NO;
        }
        
        // this means we ar ecurrently within a transaction, so we need to create an information object to describe what is happening before the commit
        if (!entity.transactionInfo) {
            SRKTransactionInfo* info = [SRKTransactionInfo new];
            info.eventType = EventDelete;
            [info copyObjectValuesIntoRestorePoint:entity];
            entity.transactionInfo = info;
        } else {
            entity.transactionInfo.eventType = EventDelete;
        }
        
        [SRKTransaction startTransactionForDatabaseConnection:databaseNameForClass];
        [SRKTransaction addReferencedObjectToTransactionList:entity];
        
    }
    
    @synchronized([[SRKGlobals sharedObject] writeLockObject]) {
        
        sqlite3_stmt* statement;
        
        NSString* sql = [NSString stringWithFormat:@"DELETE FROM %@ WHERE %@ = ?;", entityName , SRK_DEFAULT_PRIMARY_KEY_NAME];
        
        if (sqlite3_prepare_v2([SharkORM handleForDatabase:databaseNameForClass], [sql UTF8String], -1, &statement, nil) == SQLITE_OK) {
            
            [[SRKUtilities new] bindParameters:@[entity.Id] toStatement:statement];
            
            int result = sqlite3_step(statement);
            
            if (result == SQLITE_DONE) {
                [entity setSterilised:YES];
                succeded = YES;
            } else {
                
                // check we are not ignoring errors in the commit options.
                if (entity.commitOptions.raiseErrors) {
                    
                    if (entity.transactionInfo) {
                        // we are in a transaction, and it's gone south so mark the transaction as failed
                        [SRKTransaction failTransactionWithCode:SRKTransactionFailed];
                    }
                    
                    /* error in prepare statement */
                    if ([[SRKGlobals sharedObject] delegate] && [[[SRKGlobals sharedObject] delegate] respondsToSelector:@selector(databaseError:)]) {
                        
                        SRKError* e = [SRKError new];
                        e.sqlQuery = sql;
                        e.errorMessage = [NSString stringWithUTF8String:sqlite3_errmsg([SharkORM handleForDatabase:databaseNameForClass])];
                        [[[SRKGlobals sharedObject] delegate] databaseError:e];
                        
                    }
                    
                }
                
            }
        } else {
            
            // check we are not ignoring errors in the commit options.
            if (entity.commitOptions.raiseErrors) {
                
                if (entity.transactionInfo) {
                    // we are in a transaction, and it's gone south so mark the transaction as failed
                    [SRKTransaction failTransactionWithCode:SRKTransactionFailed];
                }
                
            }
            
        }
        
        sqlite3_finalize(statement);
        
    };
    
    if (succeded) {
        /* check to see if this object is a fts object and clear the existing row */
        if ([[entity class] FTSParametersForEntity]) {
            [SharkORM executeSQL:[NSString stringWithFormat:@"DELETE FROM fts_%@ WHERE docid = %@", [[entity class] description], entity.Id] inDatabase:nil];
        }
        
        // if we are not within a transaction then execute any supplied blocks within the commit object
        if (entity.commitOptions.postRemoveBlock && ![SRKTransaction transactionIsInProgress]) {
            entity.commitOptions.postRemoveBlock();
        }
        
    }
    
    return succeded;
    
}

-(void)replaceUUIDPrimaryKey:(SRKObject *)entity withNewUUIDKey:(NSString*)newPrimaryKey {
    
    __block BOOL    succeded = NO;
    NSString* databaseNameForClass = [SharkORM databaseNameForClass:entity.class];
    NSString* entityName = [entity.class description];
    
    // the following will block if there is a transaction occouring for anything other than a current transaction block
    [SRKTransaction blockUntilTransactionFinished];
    
    if ([SRKTransaction transactionIsInProgress]) {
        
        // check to see if there was an error within the transaction so far and return if there was.
        if ([SRKTransaction currentTransactionStatus] != SRKTransactionPassed) {
            return;
        }
        
        // this means we ar ecurrently within a transaction, so we need to create an information object to describe what is happening before the commit
        if (!entity.transactionInfo) {
            SRKTransactionInfo* info = [SRKTransactionInfo new];
            info.eventType = EventUpdate;
            [info copyObjectValuesIntoRestorePoint:entity];
            entity.transactionInfo = info;
        } else {
            entity.transactionInfo.eventType = EventUpdate;
        }
        
        [SRKTransaction addReferencedObjectToTransactionList:entity];
        [SRKTransaction startTransactionForDatabaseConnection:databaseNameForClass];
        
    }
    
    @synchronized([[SRKGlobals sharedObject] writeLockObject]) {
        
        sqlite3_stmt* statement;
        
        NSString* sql = [NSString stringWithFormat:@"UPDATE %@ SET %@ = ? WHERE %@ = ?;", entityName, SRK_DEFAULT_PRIMARY_KEY_NAME , SRK_DEFAULT_PRIMARY_KEY_NAME];
        
        if (sqlite3_prepare_v2([SharkORM handleForDatabase:databaseNameForClass], [sql UTF8String], -1, &statement, nil) == SQLITE_OK) {
            
            [[SRKUtilities new] bindParameters:@[newPrimaryKey,entity.Id] toStatement:statement];
            
            int result = sqlite3_step(statement);
            
            if (result == SQLITE_DONE) {
                succeded = YES;
            } else {
                
                // check we are not ignoring errors in the commit options.
                if (entity.commitOptions.raiseErrors) {
                    
                    if (entity.transactionInfo) {
                        // we are in a transaction, and it's gone south so mark the transaction as failed
                        [SRKTransaction failTransactionWithCode:SRKTransactionFailed];
                    }
                    
                    /* error in prepare statement */
                    if ([[SRKGlobals sharedObject] delegate] && [[[SRKGlobals sharedObject] delegate] respondsToSelector:@selector(databaseError:)]) {
                        
                        SRKError* e = [SRKError new];
                        e.sqlQuery = sql;
                        e.errorMessage = [NSString stringWithUTF8String:sqlite3_errmsg([SharkORM handleForDatabase:databaseNameForClass])];
                        [[[SRKGlobals sharedObject] delegate] databaseError:e];
                        
                    }
                    
                }
                
            }
        } else {
            
            // check we are not ignoring errors in the commit options.
            if (entity.commitOptions.raiseErrors) {
                
                if (entity.transactionInfo) {
                    // we are in a transaction, and it's gone south so mark the transaction as failed
                    [SRKTransaction failTransactionWithCode:SRKTransactionFailed];
                }
                
            }
            
        }
        
        sqlite3_finalize(statement);
        
    };
    
    if (succeded) {
        
        // update the entity with the new primary key
        [entity setId:(id)newPrimaryKey];
        
        /* check to see if this object is a fts object and clear the existing row */
        if ([[entity class] FTSParametersForEntity]) {
            [SharkORM executeSQL:[NSString stringWithFormat:@"DELETE FROM fts_%@ WHERE docid = %@", [[entity class] description], entity.Id] inDatabase:nil];
        }
        
    }
    
    return;
    
}

+(void)refreshObject:(SRKObject *)entity {
    
    SRKObject* entNew = [[entity.class alloc] initWithPrimaryKeyValue:[entity Id]];
    
    if (entNew) {
        NSArray* fldNames = [entity fieldNames];
        for (NSString* name in fldNames) {
            [entity setField:name value:[entNew getField:name]];
        }
    }
    
}

+(id)getValueFromQuery:query inClass:classDecl {
    
    NSTimeInterval startT = [[NSDate date] timeIntervalSince1970];
    NSTimeInterval finishT = [[NSDate date] timeIntervalSince1970];
    __block NSTimeInterval parseT = [[NSDate date] timeIntervalSince1970];
    __block NSTimeInterval firstResultT = [[NSDate date] timeIntervalSince1970];
    __block NSTimeInterval lockwaitT = [[NSDate date] timeIntervalSince1970];
    
    id resultObject = nil;
    
    NSString *sql = query;
    
    lockwaitT = 0;
    
    sqlite3_stmt* statement;
    
    parseT = [[NSDate date] timeIntervalSince1970];
    
    [SRKTransaction blockUntilTransactionFinished];
    
    if (sqlite3_prepare_v2([SharkORM handleForDatabase:[SharkORM databaseNameForClass:classDecl]], [sql UTF8String], -1, &statement, nil) == SQLITE_OK) {
        
        parseT = [[NSDate date] timeIntervalSince1970] - parseT;
        
        firstResultT = [[NSDate date] timeIntervalSince1970];
        int status = sqlite3_step(statement);
        firstResultT = [[NSDate date] timeIntervalSince1970] - firstResultT;
        
        while (status == SQLITE_ROW) {
            
            @autoreleasepool {
                
                NSMutableDictionary* record = [[NSMutableDictionary alloc] init];
                
                /* loop thorugh the record */
                for (int p=0; p<sqlite3_column_count(statement); p++) {
                    
                    NSString* columnName = [NSString stringWithUTF8String:sqlite3_column_name(statement, p)];
                    SRKUtilities* dba = [SRKUtilities new];
                    columnName = [dba normalizedColumnName:columnName];
                    NSObject* value = [[SRKUtilities new] sqlite3_column_objc:statement column:p];
                    [record setObject:value forKey:columnName];
                    
                }
                
                resultObject = [record allValues].firstObject;
                
            }
            
            status = sqlite3_step(statement);
            
        }
        
    } else {
        
        // notify any running transaction that it has been failed
        [SRKTransaction blockUntilTransactionFinished];
        if ([SRKTransaction transactionIsInProgress]) {
            [SRKTransaction failTransactionWithCode:SRKTransactionFailed];
        }
        
        /* error in prepare statement */
        if ([[SRKGlobals sharedObject] delegate] && [[[SRKGlobals sharedObject] delegate] conformsToProtocol:@protocol(SRKDelegate)] && [[[SRKGlobals sharedObject] delegate] respondsToSelector:@selector(databaseError:)]) {
            
            SRKError* e = [SRKError new];
            e.sqlQuery = sql;
            e.errorMessage = [NSString stringWithUTF8String:sqlite3_errmsg([SharkORM handleForDatabase:classDecl])];
            [[[SRKGlobals sharedObject] delegate] databaseError:e];
            
        }
        
    }
    
    sqlite3_finalize(statement);
    
    
    
    finishT = [[NSDate date] timeIntervalSince1970] - startT;
    
    if ([[SRKGlobals sharedObject] delegate] && [[[SRKGlobals sharedObject] delegate] respondsToSelector:@selector(queryPerformedWithProfile:)]) {
        
        SRKQueryProfile* p = [SRKQueryProfile new];
        p.sqlQuery = sql;
        p.firstResultTime = (int)(firstResultT*1000);
        p.queryTime = (int)(finishT*1000);
        p.parseTime = (int)(parseT*1000);
        p.lockObtainTime = (int)(lockwaitT*1000);
        p.resultsSet = [NSArray arrayWithObject:resultObject];
        
        /* now perform the query plan for this query */
        sqlite3_stmt* plan;
        
        NSString* planStr = [NSString stringWithFormat:@"EXPLAIN QUERY PLAN %@", sql];
        
        if (sqlite3_prepare_v2([SharkORM handleForDatabase:[SharkORM databaseNameForClass:classDecl]], [planStr UTF8String], -1, &plan, nil) == SQLITE_OK) {
            
            int status = sqlite3_step(plan);
            
            NSMutableArray* a = [NSMutableArray new];
            
            while (status == SQLITE_ROW) {
                
                @autoreleasepool {
                    
                    NSMutableDictionary* record = [[NSMutableDictionary alloc] init];
                    
                    /* loop thorugh the record */
                    for (int p=0; p<sqlite3_column_count(plan); p++) {
                        
                        NSString* columnName = [NSString stringWithUTF8String:sqlite3_column_name(plan, p)];
                        SRKUtilities* dba = [SRKUtilities new];
                        columnName = [dba normalizedColumnName:columnName];
                        NSObject* value = [[SRKUtilities new] sqlite3_column_objc:plan column:p];
                        [record setObject:value forKey:columnName];
                        
                    }
                    
                    [a addObject:record];
                    
                }
                
                status = sqlite3_step(plan);
                
            }
            
            p.queryPlan = [NSArray arrayWithArray:a];
            
        }
        
        if ([[[SRKGlobals sharedObject] delegate] respondsToSelector:@selector(queryPerformedWithProfile:)]) {
            [[[SRKGlobals sharedObject] delegate] performSelector:@selector(queryPerformedWithProfile:) withObject:p];
            p = nil;
        }
        
        sqlite3_finalize(plan);
        
    }
    
    return resultObject;
    
}

- (void)handleError:(sqlite3*)db sql:(NSString*)sql {
    
    // notify any running transaction that it has been failed
    [SRKTransaction blockUntilTransactionFinished];
    if ([SRKTransaction transactionIsInProgress]) {
        [SRKTransaction failTransactionWithCode:SRKTransactionFailed];
    }
    
    /* error in prepare statement */
    if ([[SRKGlobals sharedObject] delegate] && [[[SRKGlobals sharedObject] delegate] conformsToProtocol:@protocol(SRKDelegate)] && [[[SRKGlobals sharedObject] delegate] respondsToSelector:@selector(databaseError:)]) {
        
        SRKError* e = [SRKError new];
        e.sqlQuery = sql;
        e.errorMessage = [NSString stringWithUTF8String:sqlite3_errmsg(db)];
        [[[SRKGlobals sharedObject] delegate] databaseError:e];
        
    }
    
}

- (NSMutableArray*)performQuery:(SRKQuery*)query rowBlock:(SQLQueryRowBlock)rowBlock {
    
    NSTimeInterval startT = [[NSDate date] timeIntervalSince1970];
    NSTimeInterval finishT = [[NSDate date] timeIntervalSince1970];
    __block NSTimeInterval parseT = [[NSDate date] timeIntervalSince1970];
    __block NSTimeInterval firstResultT = [[NSDate date] timeIntervalSince1970];
    __block NSTimeInterval lockwaitT = [[NSDate date] timeIntervalSince1970];
    
    if (query && (query.recordPerformance || [[[SRKGlobals sharedObject] delegate] respondsToSelector:@selector(queryPerformedWithProfile:)])) {
        if(!query.performance) {
            query.performance = [SRKQueryProfile new];
        }
    }
    
    NSMutableArray*   getFieldList = [NSMutableArray new];
    NSMutableArray*   fromList = [NSMutableArray new];
    NSString*   tableName = [query.classDecl description];
    
    // always add in the originating class
    [fromList addObject:[query.classDecl description]];
    
    switch (query.queryType) {
            
        case SRK_QUERY_TYPE_FETCH:
            
            /* get primary table fields, but if lightweight object then only get the primary key value */
            
            if (query.lightweightObject && !query.prefetch) {
                
                [getFieldList addObject:[NSString stringWithFormat:SRK_FIELD_NAME_FORMAT, tableName, SRK_DEFAULT_PRIMARY_KEY_NAME, SRK_DEFAULT_PRIMARY_KEY_NAME]];
                
            } else if (query.lightweightObject && query.prefetch) {
                
                [getFieldList addObject:[NSString stringWithFormat:SRK_FIELD_NAME_FORMAT, tableName, SRK_DEFAULT_PRIMARY_KEY_NAME, SRK_DEFAULT_PRIMARY_KEY_NAME]];
                
                for (NSString* qFieldName in query.prefetch) {
                    
                    [getFieldList addObject:[NSString stringWithFormat:SRK_FIELD_NAME_FORMAT, tableName, qFieldName, qFieldName]];
                    
                }
                
            }
            
            else {
                
                for (NSString* qFieldName in ((NSMutableDictionary*)[[[SRKGlobals sharedObject] tableSchemas] objectForKey:tableName]).allKeys) {
                    [getFieldList addObject:[NSString stringWithFormat:SRK_FIELD_NAME_FORMAT, tableName, qFieldName, qFieldName]];
                }
                
            }
            break;
            
        case SRK_QUERY_TYPE_COUNT:
            [getFieldList addObject:@" COUNT(*) "];
            break;
            
        case SRK_QUERY_TYPE_SUM:
            [getFieldList addObject: [NSString stringWithFormat:@" SUM(%@) ", query.sumFieldName]];
            break;
            
        case SRK_QUERY_TYPE_DISTINCT:
            [getFieldList addObject: [NSString stringWithFormat:@" DISTINCT %@ ", query.distinctFieldName]];
            break;
            
        case SRK_QUERY_TYPE_IDS:
            [getFieldList addObject: @" Id "];
            
        default:
            break;
    }
    
    /* see if there are any automatic joins made through object dot notation e.g. "department.name = 'Software'", where department is a property of type Department on Person */
    for (NSString* qFieldName in ((NSMutableDictionary*)[[[SRKGlobals sharedObject] tableSchemas] objectForKey:tableName]).allKeys) {
        
        // we have the fields, now to check their types as to whether they are related objects
        Class class = query.classDecl;
        int propertyType = [class getEntityPropertyType:qFieldName];
        if (propertyType == SRK_PROPERTY_TYPE_ENTITYOBJECT) {
            
            // generate the property name to look for notation
            NSString* component = [NSString stringWithFormat:@"%@.", qFieldName];
            
            // now check the query for signs of object dot notation <property>.<sub property>
            if ([query.whereClause rangeOfString:component].location != NSNotFound || [query.orderBy rangeOfString:component].location != NSNotFound) {
                
                // go and get the relationship->target class for this property
                SRKRelationship* r = [SharkORM entityRelationshipsForProperty:qFieldName inClass:class];
                if (r) {
                    // because the user has referenced an object like "department.name = 'Development' " and not just 'department IN (select ID from Department WHERE name='Development'), we now want to automatically join the table
                    // but we need to rename the join and re-arrange the query to cope with a mixture of both object.value and traditional joins to the exact same tables.
                    [fromList addObject:[NSString stringWithFormat:@" LEFT JOIN %@ as query_auto_join_%@ ON %@.%@ = query_auto_join_%@.%@ ", [r.targetClass description], qFieldName, [r.sourceClass description], qFieldName, [r.targetClass description], SRK_DEFAULT_PRIMARY_KEY_NAME]];
                    
                    // now we need to swap out all instances of the 'component' with the new named version.
                    NSString* namedReplacement = [NSString stringWithFormat:@"query_auto_join_%@.",qFieldName];
                    query.whereClause = [query.whereClause stringByReplacingOccurrencesOfString:component withString:namedReplacement];
                    query.orderBy = [query.orderBy stringByReplacingOccurrencesOfString:component withString:namedReplacement];
                }
                
            }
            
        }
        
    }
    
    /* now see if there is a join condition */
    if (query.joins.count) {
        
        for (SRKJoinObject* join in query.joins) {
            [fromList addObject:[NSString stringWithFormat:@" LEFT JOIN %@ ON %@ ", [join.joinOn description], join.joinWhere]];
            
            /* now build up the additional selects for the joined data */
            
            for (NSString* qFieldName in [[[SRKGlobals sharedObject] tableSchemas] objectForKey:[join.joinOn description]]) {
                [getFieldList addObject:[NSString stringWithFormat:SRK_JOINED_FIELD_NAME_FORMAT, [join.joinOn description], qFieldName, [join.joinOn description],qFieldName]];
            }
        }
        
    }
    
    NSMutableArray* resultsSet = nil;
    
    NSString* sql = @"";
    sql = [NSString stringWithFormat:@"SELECT %@ FROM %@ WHERE %@ ORDER BY %@ LIMIT %i OFFSET %i",[getFieldList componentsJoinedByString:@", "], [fromList componentsJoinedByString:@" "], query.whereClause, query.orderBy, query.limitOf, query.offsetFrom];
    
    /* optimise the query by removing the global default query options */
    NSString* defaultWhere = [NSString stringWithFormat:@"WHERE %@", SRK_DEFAULT_CONDITION];
    NSString* defaultLimit = [NSString stringWithFormat:@"LIMIT %i", SRK_DEFAULT_LIMIT];
    NSString* defaultOffset = [NSString stringWithFormat:@"OFFSET %i", SRK_DEFAULT_OFFSET];
    NSString* defaultOrder = [NSString stringWithFormat:@"ORDER BY %@", SRK_DEFAULT_ORDER];
    
    sql = [sql stringByReplacingOccurrencesOfString:defaultWhere withString:@""];
    
    if (query.offsetFrom == SRK_DEFAULT_OFFSET) {
        sql = [sql stringByReplacingOccurrencesOfString:defaultLimit withString:@""];
    }
    
    sql = [sql stringByReplacingOccurrencesOfString:defaultOffset withString:@""];
    sql = [sql stringByReplacingOccurrencesOfString:defaultOrder withString:@""];
    
    resultsSet = [[NSMutableArray alloc] init];
    
    lockwaitT = 0;
    
    sqlite3_stmt* statement;
    
    parseT = [[NSDate date] timeIntervalSince1970];
    
    [SRKTransaction blockUntilTransactionFinished];
    
    Class entityClass = query.classDecl;
    
    if (sqlite3_prepare_v2([SharkORM handleForDatabase:[SharkORM databaseNameForClass:entityClass]], [sql UTF8String], -1, &statement, nil) == SQLITE_OK) {
        
        if (query.parameters && query.parameters.count) {
            /* loop through the parameters using the bind command, stops injection attacks */
            [[SRKUtilities new] bindParameters:query.parameters toStatement:statement];
        }
        
        parseT = [[NSDate date] timeIntervalSince1970] - parseT;
        
        firstResultT = [[NSDate date] timeIntervalSince1970];
        int status = sqlite3_step(statement);
        firstResultT = [[NSDate date] timeIntervalSince1970] - firstResultT;
        
        while (status == SQLITE_ROW && !(query != nil && query.quit == YES)) {
            
            @autoreleasepool {
                
                rowBlock(statement, resultsSet);
                
            }
            
            status = sqlite3_step(statement);
            
        }
        
    } else {
        
        [self handleError:[SharkORM handleForDatabase:[SharkORM databaseNameForClass:entityClass]] sql:sql];
        
    }
    
    sqlite3_finalize(statement);
    
    finishT = [[NSDate date] timeIntervalSince1970] - startT;
    
    if (query && (query.recordPerformance || [[[SRKGlobals sharedObject] delegate] respondsToSelector:@selector(queryPerformedWithProfile:)])) {
        
        SRKQueryProfile* p = query.performance;
        p.sqlQuery = sql;
        p.firstResultTime = (int)(firstResultT*1000);
        p.queryTime = (int)(finishT*1000);
        p.parseTime = (int)(parseT*1000);
        p.lockObtainTime = (int)(lockwaitT*1000);
        p.resultsSet = resultsSet;
        
        /* now perform the query plan for this query */
        sqlite3_stmt* plan;
        
        NSString* planStr = [NSString stringWithFormat:@"EXPLAIN QUERY PLAN %@", sql];
        
        if (sqlite3_prepare_v2([SharkORM handleForDatabase:[SharkORM databaseNameForClass:entityClass]], [planStr UTF8String], -1, &plan, nil) == SQLITE_OK) {
            
            int status = sqlite3_step(plan);
            
            NSMutableArray* a = [NSMutableArray new];
            
            while (status == SQLITE_ROW) {
                
                @autoreleasepool {
                    
                    NSMutableDictionary* record = [[NSMutableDictionary alloc] init];
                    
                    /* loop thorugh the record */
                    for (int p=0; p<sqlite3_column_count(plan); p++) {
                        
                        NSString* columnName = [NSString stringWithUTF8String:sqlite3_column_name(plan, p)];
                        SRKUtilities* dba = [SRKUtilities new];
                        columnName = [dba normalizedColumnName:columnName];
                        NSObject* value = [[SRKUtilities new] sqlite3_column_objc:plan column:p];
                        [record setObject:value forKey:columnName];
                        
                    }
                    
                    [a addObject:record];
                    
                }
                
                status = sqlite3_step(plan);
                
            }
            
            p.queryPlan = [NSArray arrayWithArray:a];
            
        }
        
        if ([[[SRKGlobals sharedObject] delegate] respondsToSelector:@selector(queryPerformedWithProfile:)]) {
            [[[SRKGlobals sharedObject] delegate] performSelector:@selector(queryPerformedWithProfile:) withObject:p];
            if (query && !query.recordPerformance) {
                query.performance = nil;
                p = nil;
            }
        }
        
        query.performance = p;
        
        sqlite3_finalize(plan);
        
    }
    
    return resultsSet;
    
}

- (NSMutableArray*)fetchEntitySetForQuery:(SRKQuery *)query {
    
    query.queryType = SRK_QUERY_TYPE_FETCH;
    return [self performQuery:query rowBlock:^(sqlite3_stmt *statement, NSMutableArray* resultsSet) {
        
        NSMutableDictionary* record = [[NSMutableDictionary alloc] init];
        
        /* loop thorugh the record */
        for (int p=0; p<sqlite3_column_count(statement); p++) {
            
            NSString* columnName = [NSString stringWithUTF8String:sqlite3_column_name(statement, p)];
            SRKUtilities* dba = [SRKUtilities new];
            columnName = [dba normalizedColumnName:columnName];
            NSObject* value = [[SRKUtilities new] sqlite3_column_objc:statement column:p];
            [record setObject:value forKey:columnName];
            
        }
        
        SRKObject* object = [query.classDecl new];
        
        for (NSString* fieldName in record.allKeys) {
            [object setField:fieldName value:[record valueForKey:fieldName]];
        }
        
        object.exists = YES;
        object.isLightweightObject = query.lightweightObject;
        [object setBase];
        
        if (query.lightweightObject) {
            [object setSterilised:YES]; /* can't commit lightweight objects back into the fold */
        }
        
        if (object) {
            /* now we need to register this object with the default registry, first check to see if the user wants a default domain */
            if ([SharkORM getSettings].defaultManagedObjects) {
                // this will also register the object
                [object setManagedObjectDomain:[SharkORM getSettings].defaultObjectDomain];
            }
            [resultsSet addObject:object];
        }
        
    }];
    
}

-(uint64_t)fetchCountForQuery:(SRKQuery *)query {
    
    query.queryType = SRK_QUERY_TYPE_COUNT;
    NSMutableArray* results = [self performQuery:query rowBlock:^(sqlite3_stmt *statement, NSMutableArray *resultsSet) {
        
        sqlite3_int64 newResult = sqlite3_column_int64(statement, 0);
        [resultsSet addObject:@(newResult)];
        
    }];
    
    if (results.count) {
        NSNumber* countValue = [results objectAtIndex:0];
        return countValue.unsignedLongLongValue;
    } else {
        return 0;
    }
    
}

-(double)fetchSumForQuery:(SRKQuery *)query field:(NSString *)fieldname {
    
    query.queryType = SRK_QUERY_TYPE_SUM;
    query.sumFieldName = fieldname;
    
    NSMutableArray* results = [self performQuery:query rowBlock:^(sqlite3_stmt *statement, NSMutableArray *resultsSet) {
        
        double newResult = sqlite3_column_double(statement, 0);
        [resultsSet addObject:@(newResult)];
        
    }];
    
    if (results.count) {
        NSNumber* countValue = [results objectAtIndex:0];
        return countValue.doubleValue;
    } else {
        return 0;
    }
    
}

-(NSArray*)fetchDistinctForQuery:(SRKQuery *)query field:(NSString *)fieldname {
    
    query.queryType = SRK_QUERY_TYPE_DISTINCT;
    query.distinctFieldName = fieldname;
    
    NSMutableArray* results = [self performQuery:query rowBlock:^(sqlite3_stmt *statement, NSMutableArray *resultsSet) {
        
        id newResult = [[SRKUtilities new] sqlite3_column_objc:statement column:0];
        [resultsSet addObject:newResult];
        
    }];
    
    return [NSArray arrayWithArray:results];
    
}

-(NSArray*)fetchIDsForQuery:(SRKQuery *)query {
    
    query.queryType = SRK_QUERY_TYPE_IDS;
    return [self performQuery:query rowBlock:^(sqlite3_stmt *statement, NSMutableArray *resultsSet) {
        
        [resultsSet addObject:@(sqlite3_column_int(statement, 0))];
        
    }];
    
}

// TODO:  Do the Group By method here in SQL as well.  For now its done in SRKQuery

#pragma mark - Utility methods

BOOL isNillOrNull(NSObject* ob) {
    if (ob) {
        if ([ob isKindOfClass:[NSNull class]]) {
            return YES;
        }
    }
    return NO;
}

@end















