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

#import "SRKGlobals.h"
#import "SharkORM.h"
#import "Sqlite3.h"

static SRKGlobals* this;

@interface SRKGlobals ()

@property void** handles;
@property (strong) NSMutableDictionary*     databaseHandleIndex;
@property (strong) SRKSettings*             sharkORMSettings;
@property (strong) NSMutableArray*          sharkSystemEntityRelationships;
@property (strong) NSMutableDictionary*     sharkTableSchemas;
@property (strong) NSMutableDictionary*     sharkPrimaryKeys;
@property (strong) NSMutableDictionary*     sharkPrimaryTypes;
@property (strong) NSObject*                SRK_LOCK_WRITE;
@property (strong) id<SRKDelegate>          ormDelegate;
@property (copy) SRKGlobalEventCallback     insertCallbackBlock;
@property (copy) SRKGlobalEventCallback     updateCallbackBlock;
@property (copy) SRKGlobalEventCallback     deleteCallbackBlock;
@property (strong) NSMutableDictionary*     fqnClassNames;

@end

@implementation SRKGlobals

+ (instancetype)sharedObject {
    if (!this) {
        this = [SRKGlobals new];
    }
    return this;
}

- (instancetype)init {
    self = [super init];
    if(self){
        _handles = malloc(255*sizeof(sqlite3*));
        if (!_SRK_LOCK_WRITE) {
            _SRK_LOCK_WRITE = [NSObject new];
        }
        
        if (!_databaseHandleIndex) {
            _databaseHandleIndex = [NSMutableDictionary new];
        }
        
        if (!_sharkSystemEntityRelationships) {
            _sharkSystemEntityRelationships = [[NSMutableArray alloc] init];
        }
        
        /* now cache the schemas for fast joins and efficient queries */
        if (!_sharkTableSchemas) {
            _sharkTableSchemas = [[NSMutableDictionary alloc] init];
        }
        
        if (!_sharkPrimaryKeys) {
            _sharkPrimaryKeys = [[NSMutableDictionary alloc] init];
        }
        
        if (!_sharkPrimaryTypes) {
            _sharkPrimaryTypes = [[NSMutableDictionary alloc] init];
        }
        
        if (!_fqnClassNames) {
            _fqnClassNames = [[NSMutableDictionary alloc] init];
        }
    }
    return self;
}

- (int)countOfHandles {
    @synchronized (self.databaseHandleIndex) {
        return (int)self.databaseHandleIndex.count;
    }
}

- (void*)defaultHandle {
    if ([self countOfHandles]) {
        return self.handles[0];
    }
    return nil;
}

- (NSString *)defaultDatabaseName {
    
    for (NSString* key in self.databaseHandleIndex.allKeys.copy) {
        if ([((NSNumber*)[self.databaseHandleIndex objectForKey:key]) intValue] == 0) {
            return key;
        }
    }
    
    return nil;
}

- (void*)handleForIndex:(int)index {
    return self.handles[index];
}

- (void*)handleForName:(NSString*)key {
    
    if ([self.databaseHandleIndex objectForKey:key]) {
        NSNumber* n = [self.databaseHandleIndex objectForKey:key];
        return [self handleForIndex:n.intValue];
    }
    return nil;
    
}

- (void)addHandle:(void*)handle forDBName:(NSString*)dbName {
    self.handles[[self countOfHandles]] = handle;
    [self.databaseHandleIndex setObject:@(self.databaseHandleIndex.allKeys.count) forKey:dbName];
}

- (void)setDelegate:(id<SRKDelegate>)delegate {
    
    self.ormDelegate = delegate;
    
    /* now ask the delegate for the alternative settings */
    if (delegate && [[delegate class] respondsToSelector:@selector(getCustomSettings)]) {
        self.sharkORMSettings = [[delegate class] getCustomSettings];
    } else if (delegate && [delegate respondsToSelector:@selector(getCustomSettings)]) {
        self.sharkORMSettings = [delegate getCustomSettings];
    }
    
    if(!self.sharkORMSettings) {
        self.sharkORMSettings = [SRKSettings new];
    }
    
}

- (id<SRKDelegate>)delegate {
    @synchronized (self.ormDelegate) {
        return self.ormDelegate;
    }
}

- (SRKSettings *)settings {
    @synchronized (_sharkORMSettings) {
        return self.sharkORMSettings;
    }
}

- (void)removeHandleForName:(NSString*)key {
    [self.databaseHandleIndex removeObjectForKey:key];
}

- (id)writeLockObject {
    return self.SRK_LOCK_WRITE;
}

- (NSMutableDictionary*)tableSchemas {
    @synchronized (_sharkTableSchemas) {
        return _sharkTableSchemas;
    }
}

- (NSMutableDictionary*)primaryKeys {
    @synchronized (_sharkPrimaryKeys) {
        return _sharkPrimaryKeys;
    }
}

- (NSMutableDictionary*)primaryTypes {
    @synchronized (_sharkPrimaryTypes) {
        return _sharkPrimaryTypes;
    }
}

- (NSMutableArray*)systemEntityRelationships {
    @synchronized (_sharkSystemEntityRelationships) {
        return _sharkSystemEntityRelationships;
    }
}

- (NSArray*)systemEntityRelationshipsReadOnly {
    @synchronized (_sharkSystemEntityRelationships) {
        return [NSArray arrayWithArray:_sharkSystemEntityRelationships];
    }
}

- (void)setInsertCallback:(SRKGlobalEventCallback)callback {
    self.insertCallbackBlock = callback;
}

- (SRKGlobalEventCallback)getInsertCallback {
    return self.insertCallbackBlock;
}

- (void)setUpdateCallback:(SRKGlobalEventCallback)callback {
    self.updateCallbackBlock = callback;
}

- (SRKGlobalEventCallback)getUpdateCallback {
    return self.updateCallbackBlock;
}

- (void)setDeleteCallback:(SRKGlobalEventCallback)callback {
    self.deleteCallbackBlock = callback;
}

- (SRKGlobalEventCallback)getDeleteCallback {
    return self.deleteCallbackBlock;
}

- (void)setFQNameForClass:(NSString*)shortName fullName:(NSString*)fullName {
    @synchronized (_fqnClassNames) {
        [_fqnClassNames setObject:fullName forKey:shortName];
    }
}

- (NSString*)getFQNameForClass:(NSString*)shortName {
    @synchronized (_fqnClassNames) {
        return [_fqnClassNames objectForKey:shortName];
    }
}


@end
