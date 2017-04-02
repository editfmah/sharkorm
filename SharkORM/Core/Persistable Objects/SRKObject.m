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



#import "SRKObject+Private.h"
#import "SharkORM.h"
#import "SRKEventBlockHolder.h"
#import "SRKRegistry.h"
#import "SRKQuery+Private.h"
#import "SRKDefinitions.h"
#import "SharkORM+Private.h"
#import "SRKUtilities.h"
#import "SRKIndexDefinition+Private.h"
#import "FTSRegistry.h"
#import "SRKLazyLoader.h"
#import "SRKUnsupportedObject.h"
#import "SRKEncryptedObject.h"
#import "SRKObjectChain.h"
#import "SRKGlobals.h"
#import "SRKTransaction+Private.h"
#import "SRKCommitOptions+Private.h"

@implementation SRKObject {
    id cachedPrimaryKeyValue;
}

@synthesize exists, embeddedEntities, context, isMarkedForDeletion, dirty, commitOptions;
@dynamic Id,joinedResults;

static NSMutableDictionary* refactoredEntities;
static NSMutableDictionary* entitiesThatNeedRefactoring;
static NSMutableDictionary* cachedPropertyListForAllClasses;
static int obCount=0;


- (NSDictionary *)joinedResults {
    return [NSDictionary dictionaryWithDictionary:_joinedData];
}

- (NSString*)managedObjectDomain {
    return managedObjectDomain;
}

- (void)rawSetManagedObjectDomain:(NSString *)domain {
    
    managedObjectDomain = domain;
    
}

- (void)setManagedObjectDomain:(NSString *)domain {
    
    if (managedObjectDomain && !domain && self.registeredEventBlocks && self.registeredEventBlocks.count == 0) {
        [[SRKRegistry sharedInstance] remove:self];
    }
    
    if (!managedObjectDomain && domain) {
        managedObjectDomain = domain;
        [[SRKRegistry sharedInstance] registerObject:self];
    }
    managedObjectDomain = domain;
    
}

+(SRKEventHandler*)eventHandler {
    SRKEventHandler* o = [SRKEventHandler new];
    return [o entityclass:[self class]];
}

+(SRKQuery*)fts {
    SRKQuery* q = [SRKFTSQuery new];
    return [q entityclass:[self class]];
}

+(SRKQuery*)query {
    SRKQuery* q = [SRKQuery new];
    return [q entityclass:[self class]];
}

+ (id)firstMatchOf:(NSString *)fieldName withValue:(id)value {
    
    NSString* whereString = [NSString stringWithFormat:@"%@ = %%@", fieldName];
    NSArray* results = [[[[self.class query] whereWithFormat:whereString, value] limit:1] fetch];
    if (results && results.count > 0) {
        
        return [results objectAtIndex:0];
        
    }
    return nil;
}

/* partial classes */
+ (Class)classIsPartialImplementationOfClass {
    return nil;
}

/* live entities */

/*
 *  Live entities implement a shared event model and memory space, this is intended for use where you wish to action ORM events in the UI
 */

- (void)executeEventBlock:(SRKEventBlockHolder*)block {
    @synchronized(block) {
        block.block(block.tempEvent);
        block.tempEvent = nil;
    }
}

- (void)notifyObjectChanges:(SRKEvent*)e {
    
    if (e.entity == self) {
        return;
    }
    
    /* so we have to update the values here with the values in the event object */
    if (e.entity) {
        for (NSString* fieldName in e.entity.fieldNames) {
            [self setFieldRaw:fieldName value:[e.entity getField:fieldName]];
        }
    }
    
}

- (void)triggerInternalEvent:(SRKEvent*)e {
    
    if (self.eventsDelegate && [self.eventsDelegate conformsToProtocol:@protocol(SRKEventDelegate)]) {
        [self.eventsDelegate SRKObjectDidRaiseEvent:e];
    }
    
    /* now check for registered blocks for this object */
    for (SRKEventBlockHolder* bh in self.registeredEventBlocks) {
        if (bh.events & e.event) {
            /* this bit is set */
            bh.tempEvent = e;
            if (bh.updateSelf) {
                [self notifyObjectChanges:e];
            }
            if (bh.useMainThread) {
                [self performSelectorOnMainThread:@selector(executeEventBlock:) withObject:bh waitUntilDone:YES];
            } else {
                [self performSelectorInBackground:@selector(executeEventBlock:) withObject:bh];
            }
        }
    }
    
}

- (void)registerBlockForEvents:(enum SharkORMEvent)events withBlock:(SRKEventRegistrationBlock)block {
    [self registerBlockForEvents:events withBlock:block onMainThread:YES];
}

- (void)registerBlockForEvents:(enum SharkORMEvent)events withBlock:(SRKEventRegistrationBlock)block onMainThread:(BOOL)mainThread {
    [self registerBlockForEvents:events withBlock:block onMainThread:mainThread updateSelfWithEvent:NO];
}

- (void)registerBlockForEvents:(enum SharkORMEvent)events withBlock:(SRKEventRegistrationBlock)block onMainThread:(BOOL)mainThread updateSelfWithEvent:(BOOL)updateSelf {
    
    SRKEventBlockHolder* bh = [SRKEventBlockHolder new];
    bh.events = events;
    bh.block = block;
    bh.useMainThread = mainThread;
    bh.updateSelf = updateSelf;
    
    [self.registeredEventBlocks addObject:bh];
    
    if (!managedObjectDomain) {
        [[SRKRegistry sharedInstance] registerObject:self];
    }
    
}

- (void)clearAllRegisteredBlocks {
    if ((_registeredEventBlocks && _registeredEventBlocks.count > 0) && !managedObjectDomain) {
        [[SRKRegistry sharedInstance] remove:self];
    }
    self.registeredEventBlocks = [NSMutableArray new];
}

/* Primary Key Support */
- (id)Id {
    if (!cachedPrimaryKeyValue) {
        cachedPrimaryKeyValue = [self getField:SRK_DEFAULT_PRIMARY_KEY_NAME];
    }
    return cachedPrimaryKeyValue;
}

- (void)setId:(id)value {
    cachedPrimaryKeyValue = value;
    [self setFieldRaw:SRK_DEFAULT_PRIMARY_KEY_NAME value:value];
}

/* fts parameters */
+ (NSArray*)FTSParametersForEntity {
    return nil;
}

+ (BOOL)entityDoesNotRaiseEvents {
    return NO;
}

/* the following method will need implementing if you want typed collections */

+ (SRKRelationship*)relationshipForProperty:(NSString*)property {
    return nil;
}

+ (SRKRelationship*)joinRelationshipForEntityClass {
    return nil;
}

+ (SRKIndexDefinition*)indexDefinitionForEntity {
    return nil;
}

+ (NSArray*)ignoredProperties {
    return nil;
}

+ (NSDictionary*)defaultValuesForEntity {
    return nil;
}

+ (NSArray *)uniquePropertiesForClass {
    return nil;
}

+ (void)setRevision:(int)revision {
    [SharkORM setEntityRevision:revision forEntity:[[self class] description] inDatabase:[SharkORM databaseNameForClass:[self class]]];
}

+ (void)entityAtRevision:(int)revision {
    
}

/* support for the use of shared/differing database files for classes */
/*
 *      If a class returns @"user" then this entity will be persisted in a sqlite database file named "user.db"
 *      This allows shared access to database files with some differing on a per usage system.
 */

+ (NSString*)storageDatabaseForClass {
    return nil;
}

+ (NSArray *)encryptedPropertiesForClass {
    return nil;
}

+(void)updateCache:(NSMutableDictionary*)list property:(NSString*)propName encoding:(const char*)encoding matches:(NSString*)matches storageType:(int)storageType {
    
    if ([[NSString stringWithUTF8String:encoding] isEqualToString:matches]) {
        [list setObject:@(storageType) forKey:propName];
    }
    
}

+ (int)getEntityPropertyType:(NSString *)propertyName forClass:(Class)entityClass {
    return [entityClass getEntityPropertyType:propertyName];
}

+(int)getEntityPropertyType:(NSString*)propertyName {
    
    /* now look within the entity to get its property types */
    
    if (!cachedPropertyListForAllClasses) {
        cachedPropertyListForAllClasses = [NSMutableDictionary new];
    }
    
    
    NSString* clName = [[self class] description];
    NSMutableDictionary* cachedPropertyList = [cachedPropertyListForAllClasses objectForKey:clName];
    
    if (!cachedPropertyList) {
        
        cachedPropertyList = [NSMutableDictionary new];
        
        /* because we no longer inspect the superclass since 2.0.5+ and the introduction of inheritance,
         we need to set the default PK as NUMBER until it is overwritten if different */
        objc_property_t primaryKeyProperty = class_getProperty([self class], SRK_DEFAULT_PRIMARY_KEY_NAME.UTF8String);
        NSString* primaryKeyPropertyDeclarationType = [NSString stringWithUTF8String:property_getAttributes(primaryKeyProperty)];
        [cachedPropertyList setObject:@([primaryKeyPropertyDeclarationType rangeOfString:@"NSString"].location == NSNotFound ?   SRK_PROPERTY_TYPE_NUMBER : SRK_PROPERTY_TYPE_STRING) forKey:SRK_DEFAULT_PRIMARY_KEY_NAME];
        
        Class c = [self class];
        
        /* this class needs to be tested by the data layer to see if it needs to make any changes */
        unsigned int outCount;
        objc_property_t *properties = class_copyPropertyList(c, &outCount);
        
        NSMutableArray* ignoredProperties = [NSMutableArray arrayWithArray:[[self class] ignoredProperties]];
        [ignoredProperties addObject:SRK_DEFAULT_PRIMARY_KEY_NAME];
        
        for (int i = 0; i < outCount; i++) {
            
            objc_property_t property = properties[i];
            
            const char* name = property_getName(property);
            NSString* propName = [NSString stringWithUTF8String:name];
            NSString* attributes = [NSString stringWithUTF8String:property_getAttributes(property)];
            NSString* declarationType = [NSString stringWithUTF8String:property_getAttributes(property)];
            
            /*
             *  We can no longer detect @dynamic variables to determine what needs to be persisted , as even 'dynamic var'
             *      properties in Swift identify their signature as synthesized.
             *
             *  As of v2.0.6-> a call to +(NSArray*)ignoredProperties on SRKObjects is called to determine what not to persist.
             *
             */
            
            if (!ignoredProperties || ![ignoredProperties containsObject:propName]) {
                
                if ([attributes rangeOfString:@","].location != NSNotFound) {
                    attributes = [attributes substringToIndex:[attributes rangeOfString:@","].location];
                }
                
                if ([attributes rangeOfString:@"T@"].location != NSNotFound) {
                    attributes = [attributes substringFromIndex:[attributes rangeOfString:@"T@"].location+1];
                }
                
                const char* typeEncoding = [attributes UTF8String];
                
                BOOL swiftStaticallyDispatchedVarFound = NO;
                
                /* test for swiftness, and then check to see if the var is dynamic or not, the only way we can */
                if ([self isSwiftClass]) {
                    
                    /*
                     * Awaiting the ability to see if a swift property is dynamic and therefore persistable
                     */
                    
                    //swiftSynthesizedVarFound = YES;
                    //[cachedPropertyList setObject:@(SRK_PROPERTY_TYPE_UNDEFINED) forKey:propName];
                    
                }
                
                if (!swiftStaticallyDispatchedVarFound) {
                    
                    if ([declarationType rangeOfString:[NSString stringWithFormat:@"V%s", name]].location != NSNotFound) {
                        [cachedPropertyList setObject:@(SRK_PROPERTY_TYPE_UNDEFINED) forKey:propName];
                    }
                    
                    [self updateCache:cachedPropertyList property:propName encoding:typeEncoding matches:@"@\"NSString\"" storageType:SRK_PROPERTY_TYPE_STRING];
                    [self updateCache:cachedPropertyList property:propName encoding:typeEncoding matches:@"@\"NSNumber\"" storageType:SRK_PROPERTY_TYPE_NUMBER];
                    [self updateCache:cachedPropertyList property:propName encoding:typeEncoding matches:@"@\"NSDate\"" storageType:SRK_PROPERTY_TYPE_DATE];
                    [self updateCache:cachedPropertyList property:propName encoding:typeEncoding matches:@"@\"UIImage\"" storageType:SRK_PROPERTY_TYPE_IMAGE];
                    [self updateCache:cachedPropertyList property:propName encoding:typeEncoding matches:@"@\"NSImage\"" storageType:SRK_PROPERTY_TYPE_IMAGE];
                    
                    /* we need to check that this array is *NOT* involved in a relationship */
                    if (![c relationshipForProperty:[NSString stringWithUTF8String:name]]) {
                        [self updateCache:cachedPropertyList property:propName encoding:typeEncoding matches:@"@\"NSArray\"" storageType:SRK_PROPERTY_TYPE_ARRAY];
                    } else {
                        [self updateCache:cachedPropertyList property:propName encoding:typeEncoding matches:@"@\"NSArray\"" storageType:SRK_PROPERTY_TYPE_ENTITYOBJECTARRAY];
                    }
                    
                    [self updateCache:cachedPropertyList property:propName encoding:typeEncoding matches:@"@\"NSDictionary\"" storageType:SRK_PROPERTY_TYPE_DICTIONARY];
                    [self updateCache:cachedPropertyList property:propName encoding:typeEncoding matches:@"@\"NSData\"" storageType:SRK_PROPERTY_TYPE_DATA];
                    [self updateCache:cachedPropertyList property:propName encoding:typeEncoding matches:@"@\"NSMutableData\"" storageType:SRK_PROPERTY_TYPE_MUTABLEDATA];
                    [self updateCache:cachedPropertyList property:propName encoding:typeEncoding matches:@"@\"NSMutableArray\"" storageType:SRK_PROPERTY_TYPE_MUTABLEARAY];
                    [self updateCache:cachedPropertyList property:propName encoding:typeEncoding matches:@"@\"NSMutableDictionary\"" storageType:SRK_PROPERTY_TYPE_MUTABLEDIC];
                    [self updateCache:cachedPropertyList property:propName encoding:typeEncoding matches:@"@\"NSURL\"" storageType:SRK_PROPERTY_TYPE_URL];
                    [self updateCache:cachedPropertyList property:propName encoding:typeEncoding matches:@"@\"NSObject\"" storageType:SRK_PROPERTY_TYPE_NSOBJECT];
                    [self updateCache:cachedPropertyList property:propName encoding:typeEncoding matches:@"@" storageType:SRK_PROPERTY_TYPE_NSOBJECT];
                    [self updateCache:cachedPropertyList property:propName encoding:typeEncoding matches:@"Ti" storageType:SRK_PROPERTY_TYPE_INT];
                    [self updateCache:cachedPropertyList property:propName encoding:typeEncoding matches:@"TB" storageType:SRK_PROPERTY_TYPE_BOOL];
                    [self updateCache:cachedPropertyList property:propName encoding:typeEncoding matches:@"Tl" storageType:SRK_PROPERTY_TYPE_LONG];
                    [self updateCache:cachedPropertyList property:propName encoding:typeEncoding matches:@"Tf" storageType:SRK_PROPERTY_TYPE_FLOAT];
                    [self updateCache:cachedPropertyList property:propName encoding:typeEncoding matches:@"Tc" storageType:SRK_PROPERTY_TYPE_BOOL];
                    [self updateCache:cachedPropertyList property:propName encoding:typeEncoding matches:@"Ts" storageType:SRK_PROPERTY_TYPE_SHORT];
                    [self updateCache:cachedPropertyList property:propName encoding:typeEncoding matches:@"Tq" storageType:SRK_PROPERTY_TYPE_LONGLONG];
                    [self updateCache:cachedPropertyList property:propName encoding:typeEncoding matches:@"TC" storageType:SRK_PROPERTY_TYPE_UCHAR];
                    [self updateCache:cachedPropertyList property:propName encoding:typeEncoding matches:@"TI" storageType:SRK_PROPERTY_TYPE_UINT];
                    [self updateCache:cachedPropertyList property:propName encoding:typeEncoding matches:@"TS" storageType:SRK_PROPERTY_TYPE_USHORT];
                    [self updateCache:cachedPropertyList property:propName encoding:typeEncoding matches:@"TL" storageType:SRK_PROPERTY_TYPE_ULONG];
                    [self updateCache:cachedPropertyList property:propName encoding:typeEncoding matches:@"TQ" storageType:SRK_PROPERTY_TYPE_ULONGLONG];
                    [self updateCache:cachedPropertyList property:propName encoding:typeEncoding matches:@"Td" storageType:SRK_PROPERTY_TYPE_DOUBLE];
                    [self updateCache:cachedPropertyList property:propName encoding:typeEncoding matches:@"T*" storageType:SRK_PROPERTY_TYPE_CHARPTR];
                    
                    NSString* className = [[[NSString stringWithUTF8String:typeEncoding] stringByReplacingOccurrencesOfString:@"@\"" withString:@""] stringByReplacingOccurrencesOfString:@"\"" withString:@""];
                    Class testClass = NSClassFromString(className);
                    if (!testClass) {
                        testClass = NSClassFromString([[SRKGlobals sharedObject] getFQNameForClass:className]);
                    }
                    if ([testClass isSubclassOfClass:[SRKObject class]]) {
                        [cachedPropertyList setObject:@(SRK_PROPERTY_TYPE_ENTITYOBJECT) forKey:propName];
                    }
                    
                }
                
            }
            
        }
        
        free(properties);
        
        [cachedPropertyListForAllClasses setObject:cachedPropertyList forKey:[[self class] description]];
        
    }
    
    NSNumber* propertyType = (NSNumber*)[cachedPropertyList objectForKey:propertyName];
    if (propertyType) {
        return [propertyType intValue];
    } else {
        return SRK_PROPERTY_TYPE_UNDEFINED;
    }
    
}

+(int)getStorageType:(int)propertyType {
    
    
    switch (propertyType) {
        case SRK_PROPERTY_TYPE_NUMBER:
            return SRK_COLUMN_TYPE_NUMBER;
            break;
        case SRK_PROPERTY_TYPE_STRING:
            return SRK_COLUMN_TYPE_TEXT;
            break;
        case SRK_PROPERTY_TYPE_IMAGE:
            return SRK_COLUMN_TYPE_IMAGE;
            break;
        case SRK_PROPERTY_TYPE_ARRAY:
            return SRK_COLUMN_TYPE_BLOB;
            break;
        case SRK_PROPERTY_TYPE_DICTIONARY:
            return SRK_COLUMN_TYPE_BLOB;
            break;
        case SRK_PROPERTY_TYPE_DATE:
            return SRK_COLUMN_TYPE_DATE;
            break;
        case SRK_PROPERTY_TYPE_INT:
            return SRK_COLUMN_TYPE_INTEGER;
            break;
        case SRK_PROPERTY_TYPE_BOOL:
            return SRK_COLUMN_TYPE_INTEGER;
            break;
        case SRK_PROPERTY_TYPE_LONG:
            return SRK_COLUMN_TYPE_NUMBER;
            break;
        case SRK_PROPERTY_TYPE_FLOAT:
            return SRK_COLUMN_TYPE_NUMBER;
            break;
        case SRK_PROPERTY_TYPE_CHAR:
            return SRK_COLUMN_TYPE_TEXT;
            break;
        case SRK_PROPERTY_TYPE_SHORT:
            return SRK_COLUMN_TYPE_NUMBER;
            break;
        case SRK_PROPERTY_TYPE_LONGLONG:
            return SRK_COLUMN_TYPE_NUMBER;
            break;
        case SRK_PROPERTY_TYPE_UCHAR:
            return SRK_COLUMN_TYPE_NUMBER;
            break;
        case SRK_PROPERTY_TYPE_UINT:
            return SRK_COLUMN_TYPE_NUMBER;
            break;
        case SRK_PROPERTY_TYPE_USHORT:
            return SRK_COLUMN_TYPE_NUMBER;
            break;
        case SRK_PROPERTY_TYPE_ULONG:
            return SRK_COLUMN_TYPE_NUMBER;
            break;
        case SRK_PROPERTY_TYPE_ULONGLONG:
            return SRK_COLUMN_TYPE_NUMBER;
            break;
        case SRK_PROPERTY_TYPE_DOUBLE:
            return SRK_COLUMN_TYPE_NUMBER;
            break;
        case SRK_PROPERTY_TYPE_CHARPTR:
            return SRK_COLUMN_TYPE_TEXT;
            break;
        case SRK_PROPERTY_TYPE_DATA:
            return SRK_COLUMN_TYPE_BLOB;
            break;
        case SRK_PROPERTY_TYPE_MUTABLEDATA:
            return SRK_COLUMN_TYPE_BLOB;
            break;
        case SRK_PROPERTY_TYPE_MUTABLEARAY:
            return SRK_COLUMN_TYPE_BLOB;
            break;
        case SRK_PROPERTY_TYPE_MUTABLEDIC:
            return SRK_COLUMN_TYPE_BLOB;
            break;
        case SRK_PROPERTY_TYPE_URL:
            return SRK_COLUMN_TYPE_BLOB;
            break;
        case SRK_PROPERTY_TYPE_ENTITYOBJECT:
            return SRK_COLUMN_TYPE_ENTITYCLASS;
            break;
        case SRK_PROPERTY_TYPE_ENTITYOBJECTARRAY:
            return SRK_COLUMN_TYPE_ENTITYCOLLECTION;
            break;
        case SRK_PROPERTY_TYPE_NSOBJECT:
            return SRK_COLUMN_TYPE_BLOB;
            break;
        case SRK_PROPERTY_TYPE_UNDEFINED:
            assert("UNKNOWN DATA TYPE, NO STORAGE TYPE DEFINED");
            break;
        default:
            break;
    }
    
    assert("UNKNOWN DATA TYPE");
    return 0;
    
}


/* below are the two methods that we need to call whenever a get or set is called on the fields */

- (void)setValue:(id)value forKey:(NSString *)key {
    if ([self respondsToSelector:[[SRKUtilities new] generateSetSelectorForPropertyName:key]]) {
        
        /* we now need to convert any inbound object to the correct type as it may be a scalar target */
        if ([value isKindOfClass:[NSNumber class]]) {
            /* this is a number, now work out what the target type is */
            switch ([self.class getEntityPropertyType:key]) {
                case SRK_PROPERTY_TYPE_INT:
                    setPropertyIntIMP(self, [[SRKUtilities new] generateSetSelectorForPropertyName:key], ((NSNumber*)value).intValue);
                    break;
                case SRK_PROPERTY_TYPE_BOOL:
                    setPropertyBoolIMP(self, [[SRKUtilities new] generateSetSelectorForPropertyName:key], ((NSNumber*)value).boolValue);
                    break;
                case SRK_PROPERTY_TYPE_LONG:
                    setPropertyLongIMP(self, [[SRKUtilities new] generateSetSelectorForPropertyName:key], ((NSNumber*)value).longValue);
                    break;
                case SRK_PROPERTY_TYPE_FLOAT:
                    setPropertyFloatIMP(self, [[SRKUtilities new] generateSetSelectorForPropertyName:key], ((NSNumber*)value).floatValue);
                    break;
                case SRK_PROPERTY_TYPE_SHORT:
                    setPropertyShortIMP(self, [[SRKUtilities new] generateSetSelectorForPropertyName:key], ((NSNumber*)value).shortValue);
                    break;
                case SRK_PROPERTY_TYPE_LONGLONG:
                    setPropertyLongLongIMP(self, [[SRKUtilities new] generateSetSelectorForPropertyName:key], ((NSNumber*)value).longLongValue);
                    break;
                case SRK_PROPERTY_TYPE_UINT:
                    setPropertyUIntIMP(self, [[SRKUtilities new] generateSetSelectorForPropertyName:key], ((NSNumber*)value).unsignedIntValue);
                    break;
                case SRK_PROPERTY_TYPE_USHORT:
                    setPropertyUShortIMP(self, [[SRKUtilities new] generateSetSelectorForPropertyName:key], ((NSNumber*)value).unsignedShortValue);
                    break;
                case SRK_PROPERTY_TYPE_ULONG:
                    setPropertyULongIMP(self, [[SRKUtilities new] generateSetSelectorForPropertyName:key], ((NSNumber*)value).unsignedLongValue);
                    break;
                case SRK_PROPERTY_TYPE_ULONGLONG:
                    setPropertyULongLongIMP(self, [[SRKUtilities new] generateSetSelectorForPropertyName:key], ((NSNumber*)value).unsignedLongLongValue);
                    break;
                case SRK_PROPERTY_TYPE_DOUBLE:
                    setPropertyDoubleIMP(self, [[SRKUtilities new] generateSetSelectorForPropertyName:key], ((NSNumber*)value).doubleValue);
                    break;
                default:
                    SuppressPerformSelectorLeakWarning(
                                                       [self performSelector:[[SRKUtilities new] generateSetSelectorForPropertyName:key] withObject:value];
                                                       );
            }
        } else {
            /* not a number */
            SuppressPerformSelectorLeakWarning(
                                               [self performSelector:[[SRKUtilities new] generateSetSelectorForPropertyName:key] withObject:value];
                                               );
        }
        
    }
}

/* getters */

static id propertyIMP(SRKObject* self, SEL _cmd) {
    
    /*  if we have turned up here then the user has tried to get or set a proeprty that does not exist, which is probably a @dynamic property
     *
     *  This can be one of two things:
     *
     *      1.) An NSObject property that is persisted in the database
     *      2.) A Blob object that needs re-inflating to it's original type
     *      3.) A light user object so a subquery is required to fetch the whole object
     *
     *	It connot be an embedded SRKObject, because this would have been handled by propertyEntityIMP
     */
    
    NSString* columnName = NSStringFromSelector(_cmd);
    
    
    /* test to see if this is actually a field or a related object e.g. an entity class */
    for (NSString* f in self.fieldNames) {
        if ([f isEqualToString:columnName]) {
            /* this is a valid field now return the value */
            id columnValue = [self getField:columnName];
            
            /* this could be a blob value so we need to test the column type */
            if ([columnValue isKindOfClass:[NSData class]]) {
                
                /* check to see if the original column is an NSData column, if not this object needs re-inflating */
                if([self.class getEntityPropertyType:columnName] != SRK_PROPERTY_TYPE_DATA && [self.class getEntityPropertyType:columnName] != SRK_PROPERTY_TYPE_MUTABLEDATA) {
                    
                    if ([self.class getEntityPropertyType:columnName] == SRK_PROPERTY_TYPE_IMAGE) {
                        
                        NSData* val = (NSData*)columnValue;
                        //columnValue = [UIImage imageWithData:val];
                        
                        /* store the object so this method is only called the once */
                        [self setFieldRaw:columnName value:columnValue];
                        
                    } else {
                        
                        NSKeyedUnarchiver *unarchiver = [[NSKeyedUnarchiver alloc] initForReadingWithData:columnValue];
                        columnValue = [unarchiver decodeObject];
                        [unarchiver finishDecoding];
                        
                        /* now we need to see if the value is unsupported or encrypted */
                        if ([columnValue isKindOfClass:[SRKUnsupportedObject class]]) {
                            if ([[SRKGlobals sharedObject] delegate] && [[[SRKGlobals sharedObject] delegate] respondsToSelector:@selector(decodeUnsupportedColumnValueForColumn:inEntity:data:)]) {
                                SRKUnsupportedObject* unObj = columnValue;
                                columnValue = [[[SRKGlobals sharedObject] delegate] decodeUnsupportedColumnValueForColumn:columnValue inEntity:[[self class] description]  data:unObj.object];
                            }
                        }
                        
                        if ([columnValue isKindOfClass:[SRKEncryptedObject class]]) {
                            SRKEncryptedObject* encObj = columnValue;
                            columnValue = encObj.decryptObject;
                        }
                        
                        /* store the object so this method is only called the once */
                        [self setFieldRaw:columnName value:columnValue];
                        
                    }
                    
                } else if ([self.class getEntityPropertyType:columnName] == SRK_PROPERTY_TYPE_MUTABLEDATA) {
                    
                    columnValue = [NSMutableData dataWithData:((NSData*)columnValue)];
                    
                }
                
            }
            
            return columnValue;
            
        }
    }
    
    return nil;
    
}

static id propertyEntityIMP(SRKObject* self, SEL _cmd) {
    
    /* if we have turned up here then the user has tried to get or set a proeprty that does not exist, which is probably a @dynamic property */
    
    NSString* columnName = NSStringFromSelector(_cmd);
    
    /* but this could also be a lazy loader or entity so pull the value out directly */
    for (NSString* key in self.embeddedEntities.allKeys) {
        if([key isEqualToString:columnName]){
            if ([[self.embeddedEntities objectForKey:key] isKindOfClass:[SRKObject class]] || [[self.embeddedEntities objectForKey:key] isKindOfClass:[NSArray class]]) {
                /* this is a directly embedded entity */
                return [self.embeddedEntities objectForKey:key];
                
            } else if ([[self.embeddedEntities objectForKey:key] isKindOfClass:[SRKLazyLoader class]]) {
                /* this is a lazy loader, fire it and embed the result */
                
                id result = [((SRKLazyLoader*)[self.embeddedEntities objectForKey:key]) fetchNode];
                if (result) {
                    
                    [self.embeddedEntities setObject:result forKey:key];
                    return result;
                    
                }
                else
                {
                    /* leave the lazy in place */
                    return nil;
                }
                
            }
        }
    }
    
    return [self getField:columnName];
    
}

static id propertyEntityCollectionIMP(SRKObject* self, SEL _cmd) {
    
    /* if we have turned up here then the user has tried to get or set a proeprty that does not exist, which is probably a @dynamic property */
    
    NSString* columnName = NSStringFromSelector(_cmd);
    
    /* but this could also be a lazy loader or entity so pull the value out directly */
    for (NSString* key in self.embeddedEntities.allKeys) {
        if([key isEqualToString:columnName]){
            if ([[self.embeddedEntities objectForKey:key] isKindOfClass:[SRKObject class]] || [[self.embeddedEntities objectForKey:key] isKindOfClass:[NSArray class]]) {
                /* this is a directly embedded entity */
                return [self.embeddedEntities objectForKey:key];
                
            } else if ([[self.embeddedEntities objectForKey:key] isKindOfClass:[SRKLazyLoader class]]) {
                /* this is a lazy loader, fire it and embed the result */
                
                id result = [((SRKLazyLoader*)[self.embeddedEntities objectForKey:key]) fetchNode];
                if (result) {
                    
                    [self.embeddedEntities setObject:result forKey:key];
                    return result;
                    
                }
                else
                {
                    /* leave the lazy in place */
                    return nil;
                }
                
            }
        }
    }
    
    /* test to see if this is actually a field or a related object e.g. an entity class */
    for (NSString* f in self.fieldNames) {
        if ([f isEqualToString:columnName]) {
            /* this is a valid field now return the value */
            return [self getField:columnName];
        }
    }
    
    return nil;
    
}

static char propertyCharIMP(SRKObject* self, SEL _cmd) {
    
    NSObject* o = propertyIMP(self, _cmd);
    
    NSString* columnName = NSStringFromSelector(_cmd);
    
    if (o && ([self.class getEntityPropertyType:columnName] == SRK_PROPERTY_TYPE_CHAR)) {
        return [(NSNumber*)o charValue];
    } else {
        return 0;
    }
    
}

static int propertyIntIMP(SRKObject* self, SEL _cmd) {
    
    NSObject* o = propertyIMP(self, _cmd);
    
    NSString* columnName = NSStringFromSelector(_cmd);
    
    if (o && ([self.class getEntityPropertyType:columnName] == SRK_PROPERTY_TYPE_INT)) {
        return [(NSNumber*)o intValue];
    } else {
        return 0;
    }
    
}

static short propertyShortIMP(SRKObject* self, SEL _cmd) {
    
    NSObject* o = propertyIMP(self, _cmd);
    
    NSString* columnName = NSStringFromSelector(_cmd);
    
    if (o && ([self.class getEntityPropertyType:columnName] == SRK_PROPERTY_TYPE_SHORT)) {
        return [(NSNumber*)o shortValue];
    } else {
        return 0;
    }
    
}

static long propertyLongIMP(SRKObject* self, SEL _cmd) {
    
    NSObject* o = propertyIMP(self, _cmd);
    
    NSString* columnName = NSStringFromSelector(_cmd);
    
    if (o && ([self.class getEntityPropertyType:columnName] == SRK_PROPERTY_TYPE_LONG)) {
        return [(NSNumber*)o longValue];
    } else {
        return 0;
    }
    
}

static long long propertyLongLongIMP(SRKObject* self, SEL _cmd) {
    
    NSObject* o = propertyIMP(self, _cmd);
    
    NSString* columnName = NSStringFromSelector(_cmd);
    
    if (o && ([self.class getEntityPropertyType:columnName] == SRK_PROPERTY_TYPE_LONGLONG)) {
        return [(NSNumber*)o longLongValue];
    } else {
        return 0;
    }
    
}

static unsigned char propertyUCharIMP(SRKObject* self, SEL _cmd) {
    
    NSObject* o = propertyIMP(self, _cmd);
    
    NSString* columnName = NSStringFromSelector(_cmd);
    
    if (o && ([self.class getEntityPropertyType:columnName] == SRK_PROPERTY_TYPE_UCHAR)) {
        return [(NSNumber*)o unsignedCharValue];
    } else {
        return 0;
    }
    
}

static unsigned int propertyUIntIMP(SRKObject* self, SEL _cmd) {
    
    NSObject* o = propertyIMP(self, _cmd);
    
    NSString* columnName = NSStringFromSelector(_cmd);
    
    if (o && ([self.class getEntityPropertyType:columnName] == SRK_PROPERTY_TYPE_UINT)) {
        return [(NSNumber*)o unsignedIntValue];
    } else {
        return 0;
    }
    
}

static unsigned short propertyUShortIMP(SRKObject* self, SEL _cmd) {
    
    NSObject* o = propertyIMP(self, _cmd);
    
    NSString* columnName = NSStringFromSelector(_cmd);
    
    if (o && ([self.class getEntityPropertyType:columnName] == SRK_PROPERTY_TYPE_USHORT)) {
        return [(NSNumber*)o unsignedShortValue];
    } else {
        return 0;
    }
    
}

static unsigned long propertyULongIMP(SRKObject* self, SEL _cmd) {
    
    NSObject* o = propertyIMP(self, _cmd);
    
    NSString* columnName = NSStringFromSelector(_cmd);
    
    if (o && ([self.class getEntityPropertyType:columnName] == SRK_PROPERTY_TYPE_ULONG)) {
        return [(NSNumber*)o unsignedLongValue];
    } else {
        return 0;
    }
    
}



static float propertyFloatIMP(SRKObject* self, SEL _cmd) {
    
    NSObject* o = propertyIMP(self, _cmd);
    
    NSString* columnName = NSStringFromSelector(_cmd);
    
    if (o && ([self.class getEntityPropertyType:columnName] == SRK_PROPERTY_TYPE_FLOAT)) {
        return [(NSNumber*)o floatValue];
    } else {
        return 0;
    }
    
}


static unsigned long long propertyULongLongIMP(SRKObject* self, SEL _cmd) {
    
    NSObject* o = propertyIMP(self, _cmd);
    
    NSString* columnName = NSStringFromSelector(_cmd);
    
    if (o && ([self.class getEntityPropertyType:columnName] == SRK_PROPERTY_TYPE_ULONGLONG)) {
        return [(NSNumber*)o unsignedLongLongValue];
    } else {
        return 0;
    }
    
}

static double propertyDoubleIMP(SRKObject* self, SEL _cmd) {
    
    NSObject* o = propertyIMP(self, _cmd);
    
    NSString* columnName = NSStringFromSelector(_cmd);
    
    if (o && ([self.class getEntityPropertyType:columnName] == SRK_PROPERTY_TYPE_DOUBLE)) {
        return [(NSNumber*)o doubleValue];
    } else {
        return 0;
    }
    
}

static BOOL propertyBoolIMP(SRKObject* self, SEL _cmd) {
    
    NSObject* o = propertyIMP(self, _cmd);
    
    NSString* columnName = NSStringFromSelector(_cmd);
    
    if (o && ([self.class getEntityPropertyType:columnName] == SRK_PROPERTY_TYPE_BOOL)) {
        return [(NSNumber*)o boolValue];
    } else {
        return NO;
    }
    
}

static char* propertyCharPTRIMP(SRKObject* self, SEL _cmd) {
    
    NSObject* o = propertyIMP(self, _cmd);
    
    NSString* columnName = NSStringFromSelector(_cmd);
    
    if (o && ([self.class getEntityPropertyType:columnName] == SRK_PROPERTY_TYPE_LONG)) {
        return (char*)[(NSString*)o UTF8String];
    } else {
        return nil;
    }
    
}


/* setters */

static void setPropertyIMP(SRKObject* self, SEL _cmd, id aValue) {
    
    /* if we have turned up here then the user has tried to get or set a proeprty that does not exist, which is probably a @dynamic property */
    
    // we have an asignment/change to a property value, so we need to establish if we are currently within a transaction
    
    if (!self.transactionInfo && [SRKTransaction transactionIsInProgressForThisThread]) {
        
        // create a transaction object, which will create a restore point for this object were the transaction to fail
        SRKTransactionInfo* info = [SRKTransactionInfo new];
        [info copyObjectValuesIntoRestorePoint:self];
        self.transactionInfo = info;
        
        [SRKTransaction addReferencedObjectToTransactionList:self];
        
    }
    
    NSString* propertyName = [[SRKUtilities new] propertyNameFromSelector:_cmd forObject:self];
    
    /* test to see if this is actually a field or a related object e.g. an entity class */
    for (NSString* f in self.fieldNames) {
        if ([f isEqualToString:propertyName]) {
            
            if (aValue) {
                /* if !SRKObject class */
                if (![aValue isKindOfClass:[SRKObject class]]) {
                    
                    /* check to see if we need to encrypt the value before setting it into entity */
                    NSArray* encryptableProperties = [[self class] encryptedPropertiesForClass];
                    if (encryptableProperties) {
                        for (NSString* propName in encryptableProperties) {
                            if ([propName isEqualToString:propertyName]) {
                                /* it does need to be encrypted, so we put it within a DBEncryptedObject so we know the status of it */
                                SRKEncryptedObject* encOb = [SRKEncryptedObject new];
                                if ([encOb encryptObject:aValue]) {
                                    aValue = encOb;
                                } else {
                                    
                                    /* value could not be encrypted */
                                    
                                }
                            }
                        }
                    }
                    
                    [self setFieldRaw:propertyName value:aValue];
                }
            } else {
                [self setFieldRaw:propertyName value:[NSNull null]];
            }
            
        }
    }
    
    /* now test to see if this is an asignment to or from a relationship, not a field */
    for (SRKRelationship *r in [SharkORM entityRelationships]) {
        if ([[r.sourceClass description] isEqualToString:[[self class] description]]) {
            
            /* now test to see if this is a linked object */
            if ([r.entityPropertyName isEqualToString:propertyName]) {
                
                /* this is a property that is related to another entity */
                
                /* we need to pull out the ID of the assigning parameter and insert it into the hidden field */
                id argument = aValue;
                
                if (argument) {
                    if ([argument isKindOfClass:[SRKObject class]]) {
                        
                        /* store the entity in the cache */
                        [self.embeddedEntities setObject:argument forKey:propertyName];
                        
                        /* if the new entity exists in the table then update the id column */
                        if (((SRKObject*)argument).exists) {
                            [self setFieldRaw:[NSString stringWithFormat:@"%@", propertyName] value:((SRKObject*)argument).Id];
                        }
                        
                    } else if ([argument isKindOfClass:[SRKLazyLoader class]]) {
                        
                        /* we need to stuff this straight into the cache */
                        [self.embeddedEntities setObject:argument forKey:propertyName];
                        
                    }
                } else {
                    
                    /* !argument */
                    
                    [self setFieldRaw:[NSString stringWithFormat:@"%@", propertyName] value:[NSNull null]];
                    
                    /* we need to force the embedded item to be a lazy loader */
                    SRKLazyLoader* ll = [SRKLazyLoader new];
                    ll.parentEntity = self;
                    ll.relationship = r;
                    
                    [self.embeddedEntities setObject:ll forKey:propertyName];
                    
                }
                
                
                
            }
        }
    }
    
    /* mark this property as dirty for live sets */
    [self.dirtyFields setObject:@(1) forKey:propertyName];
    self.dirty = YES;
    
}

static void setPropertyEntityIMP(SRKObject* self, SEL _cmd, id aValue) {
    
    // we have an asignment/change to a property value, so we need to establish if we are currently within a transaction
    
    if (!self.transactionInfo && [SRKTransaction transactionIsInProgressForThisThread]) {
        
        // create a transaction object, which will create a restore point for this object were the transaction to fail
        SRKTransactionInfo* info = [SRKTransactionInfo new];
        [info copyObjectValuesIntoRestorePoint:self];
        self.transactionInfo = info;
        
        [SRKTransaction addReferencedObjectToTransactionList:self];
        
    }
    
    NSString* propertyName = [[SRKUtilities new] propertyNameFromSelector:_cmd forObject:self];
    
    /* test to see if this is actually a field or a related object e.g. an entity class */
    for (NSString* f in self.fieldNames) {
        if ([f isEqualToString:propertyName]) {
            
            if (aValue) {
                /* if !SRKObject class */
                if (![aValue isKindOfClass:[SRKObject class]]) {
                    [self setFieldRaw:propertyName value:aValue];
                } else {
                    
                }
            } else {
                [self setFieldRaw:propertyName value:[NSNull null]];
            }
            
        }
    }
    
    /* now test to see if this is an asignment to or from a relationship, not a field */
    for (SRKRelationship *r in [SharkORM entityRelationships]) {
        if ([[r.sourceClass description] isEqualToString:[[self class] description]]) {
            
            /* now test to see if this is a linked object */
            if ([r.entityPropertyName isEqualToString:propertyName]) {
                
                /* this is a property that is related to another entity */
                
                /* we need to pull out the ID of the assigning parameter and insert it into the hidden field */
                id argument = aValue;
                
                if (argument) {
                    if ([argument isKindOfClass:[SRKObject class]]) {
                        
                        /* store the entity in the cache */
                        [self.embeddedEntities setObject:argument forKey:propertyName];
                        
                        /* if the new entity exists in the table then update the id column */
                        if (((SRKObject*)argument).exists) {
                            [self setFieldRaw:[NSString stringWithFormat:@"%@", propertyName] value:((SRKObject*)argument).Id];
                        } else {
                            /* stil flag this object as dirty so we know it has actualy changed, regardless of not having a PK yet */
                            @synchronized (self.dirtyFields) {
                                [self.dirtyFields setObject:@(1) forKey:propertyName];
                            }
                        }
                        
                    } else if ([argument isKindOfClass:[SRKLazyLoader class]]) {
                        
                        /* we need to stuff this straight into the cache */
                        [self.embeddedEntities setObject:argument forKey:propertyName];
                        
                    }
                } else {
                    
                    /* !argument */
                    
                    [self setFieldRaw:[NSString stringWithFormat:@"%@", propertyName] value:[NSNull null]];
                    
                    /* we need to force the embedded item to be a lazy loader */
                    SRKLazyLoader* ll = [SRKLazyLoader new];
                    ll.parentEntity = self;
                    ll.relationship = r;
                    
                    [self.embeddedEntities setObject:ll forKey:propertyName];
                    
                }
                
                
                
            }
        }
    }
    
    /* mark this property as dirty for live sets */
    [self.dirtyFields setObject:@(1) forKey:propertyName];
    self.dirty = YES;
    
}

static void setPropertyEntityCollectionIMP(SRKObject* self, SEL _cmd, id aValue) {
    
    // we have an asignment/change to a property value, so we need to establish if we are currently within a transaction
    
    if (!self.transactionInfo && [SRKTransaction transactionIsInProgressForThisThread]) {
        
        // create a transaction object, which will create a restore point for this object were the transaction to fail
        SRKTransactionInfo* info = [SRKTransactionInfo new];
        [info copyObjectValuesIntoRestorePoint:self];
        self.transactionInfo = info;
        
        [SRKTransaction addReferencedObjectToTransactionList:self];
        
    }
    
    NSString* propertyName = [[SRKUtilities new] propertyNameFromSelector:_cmd forObject:self];
    
    /* test to see if this is actually a field or a related object e.g. an entity class */
    for (NSString* f in self.fieldNames) {
        if ([f isEqualToString:propertyName]) {
            
            if (aValue) {
                /* if !SRKObject class */
                if (![aValue isKindOfClass:[SRKObject class]]) {
                    [self setFieldRaw:propertyName value:aValue];
                }
            } else {
                [self setFieldRaw:propertyName value:[NSNull null]];
            }
            
        }
    }
    
    /* now test to see if this is an asignment to or from a relationship, not a field */
    for (SRKRelationship *r in [SharkORM entityRelationships]) {
        if ([[r.sourceClass description] isEqualToString:[[self class] description]]) {
            
            /* now test to see if this is a linked object */
            if ([r.entityPropertyName isEqualToString:propertyName]) {
                
                /* this is a property that is related to another entity */
                
                /* we need to pull out the ID of the assigning parameter and insert it into the hidden field */
                id argument = aValue;
                
                if (argument) {
                    if ([argument isKindOfClass:[SRKObject class]]) {
                        
                        /* store the entity in the cache */
                        [self.embeddedEntities setObject:argument forKey:propertyName];
                        
                        /* if the new entity exists in the table then update the id column */
                        if (((SRKObject*)argument).exists) {
                            [self setFieldRaw:[NSString stringWithFormat:@"%@", propertyName] value:((SRKObject*)argument).Id];
                        }
                        
                    } else if ([argument isKindOfClass:[SRKLazyLoader class]]) {
                        
                        /* we need to stuff this straight into the cache */
                        [self.embeddedEntities setObject:argument forKey:propertyName];
                        
                    }
                } else {
                    
                    /* !argument */
                    
                    [self setFieldRaw:[NSString stringWithFormat:@"%@", propertyName] value:[NSNull null]];
                    
                    /* we need to force the embedded item to be a lazy loader */
                    SRKLazyLoader* ll = [SRKLazyLoader new];
                    ll.parentEntity = self;
                    ll.relationship = r;
                    
                    [self.embeddedEntities setObject:ll forKey:propertyName];
                    
                }
                
                
                
            }
        }
    }
    
    /* mark this property as dirty for live sets */
    [self.dirtyFields setObject:@(1) forKey:propertyName];
    self.dirty = YES;
    
}

static void setPropertyBoolIMP(SRKObject* self, SEL _cmd, BOOL aValue) {
    setPropertyIMP(self,_cmd, [NSNumber numberWithBool:aValue]);
}

static void setPropertyCharIMP(SRKObject* self, SEL _cmd, char aValue) {
    setPropertyIMP(self,_cmd, [NSNumber numberWithChar:aValue]);
}

static void setPropertyIntIMP(SRKObject* self, SEL _cmd, int aValue) {
    setPropertyIMP(self,_cmd, [NSNumber numberWithInt:aValue]);
}

static void setPropertyShortIMP(SRKObject* self, SEL _cmd, short aValue) {
    setPropertyIMP(self,_cmd, [NSNumber numberWithShort:aValue]);
}

static void setPropertyLongIMP(SRKObject* self, SEL _cmd, long aValue) {
    setPropertyIMP(self,_cmd, [NSNumber numberWithLong:aValue]);
}

static void setPropertyLongLongIMP(SRKObject* self, SEL _cmd, long long aValue) {
    setPropertyIMP(self,_cmd, [NSNumber numberWithLongLong:aValue]);
}

static void setPropertyUCharIMP(SRKObject* self, SEL _cmd, unsigned char aValue) {
    setPropertyIMP(self,_cmd, [NSNumber numberWithUnsignedChar:aValue]);
}

static void setPropertyUIntIMP(SRKObject* self, SEL _cmd, unsigned int aValue) {
    setPropertyIMP(self,_cmd, [NSNumber numberWithUnsignedInt:aValue]);
}

static void setPropertyUShortIMP(SRKObject* self, SEL _cmd, unsigned short aValue) {
    setPropertyIMP(self,_cmd, [NSNumber numberWithUnsignedShort:aValue]);
}

static void setPropertyULongIMP(SRKObject* self, SEL _cmd, unsigned long aValue) {
    setPropertyIMP(self,_cmd, [NSNumber numberWithUnsignedLong:aValue]);
}

static void setPropertyULongLongIMP(SRKObject* self, SEL _cmd, unsigned long long aValue) {
    setPropertyIMP(self,_cmd, [NSNumber numberWithUnsignedLongLong:aValue]);
}

static void setPropertyFloatIMP(SRKObject* self, SEL _cmd, float aValue) {
    setPropertyIMP(self,_cmd, [NSNumber numberWithFloat:aValue]);
}

static void setPropertyDoubleIMP(SRKObject* self, SEL _cmd, double aValue) {
    setPropertyIMP(self,_cmd, [NSNumber numberWithDouble:aValue]);
}

static void setPropertyCharPTRIMP(SRKObject* self, SEL _cmd, char* aValue) {
    setPropertyIMP(self,_cmd, [NSString stringWithUTF8String:aValue]);
}

// overload this for swift compatibility
+ (NSString*)description {
    NSString* className = NSStringFromClass(self);
    while ([className rangeOfString:@"."].location != NSNotFound) {
        className = [className substringFromIndex:[className rangeOfString:@"."].location+1];
    }
    if ([NSStringFromClass(self) rangeOfString:@"."].location != NSNotFound) {
        [[SRKGlobals sharedObject] setFQNameForClass:className fullName:NSStringFromClass(self)];
    }
    return className;
}

+ (BOOL)isSwiftClass {
    NSString* className = NSStringFromClass(self);
    while ([className rangeOfString:@"."].location != NSNotFound) {
        return YES;
    }
    return NO;
}


+(void)injectPropertyTrapsFor:(NSString*)propName reader:(IMP)r writer:(IMP)w typeEncoding:(const char*)type {
    
    // automatically detect if this is a swift class, because we can't just create new getters and setters we need to replace existing ones
    if ([self.class isSwiftClass]) {
        
        IMP oldMethod = class_replaceMethod([self class], NSSelectorFromString(propName), r, [[NSString stringWithFormat:@"%s@:", type] UTF8String]);
        NSString* setMethod = [NSString stringWithFormat:@"set%@%@:", [[propName substringToIndex:1] uppercaseString], [propName substringFromIndex:1]];
        oldMethod = class_replaceMethod([self class], NSSelectorFromString(setMethod), w, [[NSString stringWithFormat:@"v@:%s",type] UTF8String]);
        
    } else {
        class_addMethod([self class], NSSelectorFromString(propName), r, [[NSString stringWithFormat:@"%s@:", type] UTF8String]);
        NSString* setMethod = [NSString stringWithFormat:@"set%@%@:", [[propName substringToIndex:1] uppercaseString], [propName substringFromIndex:1]];
        class_addMethod([self class], NSSelectorFromString(setMethod), w, [[NSString stringWithFormat:@"v@:%s",type] UTF8String]);
    }
    
}

+(BOOL)isTypeAPrimitive:(int)type {
    
    if (type == SRK_PROPERTY_TYPE_CHAR) {
        
        return YES;
        
    } else if (type == SRK_PROPERTY_TYPE_INT) {
        
        return YES;
        
    } else if (type == SRK_PROPERTY_TYPE_SHORT) {
        
        return YES;
        
    } else if (type == SRK_PROPERTY_TYPE_LONG) {
        
        return YES;
        
    } else if (type == SRK_PROPERTY_TYPE_LONGLONG) {
        
        return YES;
        
    } else if (type == SRK_PROPERTY_TYPE_UCHAR) {
        
        return YES;
        
    } else if (type == SRK_PROPERTY_TYPE_UINT) {
        
        return YES;
        
    } else if (type == SRK_PROPERTY_TYPE_USHORT) {
        
        return YES;
        
    } else if (type == SRK_PROPERTY_TYPE_ULONG) {
        
        return YES;
        
    } else if (type == SRK_PROPERTY_TYPE_ULONGLONG) {
        
        return YES;
        
    } else if (type == SRK_PROPERTY_TYPE_FLOAT) {
        
        return YES;
        
    } else if (type == SRK_PROPERTY_TYPE_DOUBLE) {
        
        return YES;
        
    } else if (type == SRK_PROPERTY_TYPE_BOOL) {
        
        return YES;
        
    }
    
    return NO;
    
}

+ (void)setupOutstandingClasses {
    for (NSString* className in entitiesThatNeedRefactoring) {
        Class class = NSClassFromString(className);
        if (!class) {
            class = NSClassFromString([[SRKGlobals sharedObject] getFQNameForClass:className]);
        }
        [class setupClass];
    }
    entitiesThatNeedRefactoring = nil;
}

+ (void)inspectClass:(Class)class accumulateDefinitions:(NSMutableDictionary*)classDef accumulateRelationships:(NSMutableArray*)relationships accumulateProperties:(NSMutableDictionary*)combinedProperties {
    
    /* this class needs to be tested by the data layer to see if it needs to make any changes */
    unsigned int outCount;
    objc_property_t *properties = class_copyPropertyList(class, &outCount);
    
    for (int i = 0; i < outCount; i++) {
        
        objc_property_t property = properties[i];
        
        NSString* name = [NSString stringWithUTF8String:property_getName(property)];
        int propertyType = [class getEntityPropertyType:name];
        if (propertyType != SRK_PROPERTY_TYPE_UNDEFINED) {
            
            /* now get the actual storage type of the property */
            int storageType = [class getStorageType:propertyType];
            NSNumber* dataType = [NSNumber numberWithInt:storageType];
            
            if (storageType == SRK_COLUMN_TYPE_ENTITYCOLLECTION) {
                
                SRKRelationship* r = [class relationshipForProperty:name];
                if (r) {
                    
                    /* this is a one to many, no need to create a field because it's hooked up to "Id" */
                    
                    /* we've told the layer that the "link" field is to be created so now we will hook up the one-to-many relationship */
                    r.sourceClass = class;
                    r.sourceProperty = name;
                    r.entityPropertyName = name;
                    [relationships addObject:r];
                    
                    [classDef setObject:dataType forKey:name];
                    
                }
                
            }
            
            if(storageType == SRK_COLUMN_TYPE_ENTITYCLASS) {
                
                NSString* attributes = [NSString stringWithUTF8String:property_getAttributes(property)];
                if ([attributes rangeOfString:@","].location != NSNotFound) {
                    attributes = [attributes substringToIndex:[attributes rangeOfString:@","].location];
                }
                
                if ([attributes rangeOfString:@"T@"].location != NSNotFound) {
                    attributes = [attributes substringFromIndex:[attributes rangeOfString:@"T@"].location+1];
                }
                
                const char* typeEncoding = [attributes UTF8String];
                
                NSString* className = [[[NSString stringWithUTF8String:typeEncoding] stringByReplacingOccurrencesOfString:@"@\"" withString:@""] stringByReplacingOccurrencesOfString:@"\"" withString:@""];
                Class testClass = NSClassFromString(className);
                if (!testClass) {
                    testClass = NSClassFromString([[SRKGlobals sharedObject] getFQNameForClass:className]);
                }
                if ([testClass isSubclassOfClass:[SRKObject class]]) {
                    
                    /* ok this is a property based on a entity class linked to the db layer */
                    [classDef setObject:dataType forKey:[NSString stringWithFormat:@"%@", name]];
                    
                    /* we've told the layer that the "link" field is to be created so now we will hook up the one-to-one relationship */
                    SRKRelationship* r = [SRKRelationship new];
                    r.sourceClass = self.class;
                    r.targetClass = NSClassFromString(className);
                    if (!r.targetClass) {
                        r.targetClass = NSClassFromString([[SRKGlobals sharedObject] getFQNameForClass:className]);
                    }
                    r.sourceProperty = [NSString stringWithFormat:@"%@", name];
                    r.targetProperty = SRK_DEFAULT_PRIMARY_KEY_NAME;
                    r.entityPropertyName = [NSString stringWithString:name];
                    r.relationshipType = SRK_RELATE_ONETOONE;
                    
                    [relationships addObject:r];
                    
                }
                
            }
            
            [combinedProperties setObject:@(propertyType) forKey:name];
            [classDef setObject:dataType forKey:name];
            
        }
        
    }
    
    free(properties);
    
}

+ (void)setupClass {
    
    /* this method gets called when a class is registered in the system */
    /* use this method to register this class with the data layer */
    
    if (!refactoredEntities) {
        refactoredEntities = [[NSMutableDictionary alloc] init];
    }
    
    /* now check to see if this entity needs to be refactored */
    
    Class c = [self class];
    
    /* add swift compatibility to this class */
    NSString* strClassName = [c description];
    
    /* check to see if it's a partial class */
    if (c) {
        if ([c isSubclassOfClass:[SRKObject class]]) {
            if ([c conformsToProtocol:@protocol(SRKPartialClassDelegate)]) {
                
                Class fullClass = [[self class] classIsPartialImplementationOfClass];
                if (fullClass) {
                    return;
                }
                
            }
        }
    }
    
    /* call open to ensure there is a database opened for the storage database of this class */
    [SharkORM openDatabaseNamed:[SharkORM databaseNameForClass:[self class]]];
    
    if (![strClassName isEqualToString:@"SRKObject"] && ![strClassName isEqualToString:@"SRKPublicObject"] && ![strClassName isEqualToString:@"SRKPrivateObject"]) {
        
        if ([refactoredEntities objectForKey:strClassName] == nil) {
            
            [refactoredEntities setObject:[NSNull null] forKey:strClassName];
            
            /* get this class's join relationship data and store this */
            SRKRelationship* jr = [[self class] joinRelationshipForEntityClass];
            if (jr) {
                
                jr.sourceClass = c;
                jr.sourceProperty = [NSString stringWithFormat:@"%@", jr.sourceProperty];
                jr.targetProperty = SRK_DEFAULT_PRIMARY_KEY_NAME;
                [SharkORM addEntityRelationship:jr inDatabase:[SharkORM databaseNameForClass:[self class]]];
            }
            
            /* build an array of classes that we need to introspect */
            
            NSMutableDictionary* classDef = [NSMutableDictionary new];
            NSMutableDictionary* combinedProperties = [NSMutableDictionary new];
            NSMutableArray* relationships = [NSMutableArray new];
            
            NSMutableArray* classes = [NSMutableArray new];
            [classes addObject:c];
            Class startClass = [self class];
            while ([[startClass superclass] isSubclassOfClass:[SRKObject class]] && ![[[startClass superclass] description] isEqualToString:@"SRKObject"]) {
                [classes addObject:[startClass superclass]];
                startClass = [startClass superclass];
                if ([[startClass.superclass description] isEqualToString:@"SRKObject"]) {
                    break;
                }
            }
            
            for (Class class in classes) {
                [self inspectClass:class accumulateDefinitions:classDef accumulateRelationships:relationships accumulateProperties:combinedProperties];
            }
            
            /* if this class is a subclass/inherits, then merge back the properties */
            if (classes.count > 1) {
                NSMutableDictionary* cachedProperties = [cachedPropertyListForAllClasses objectForKey:strClassName];
                for (NSString* key in combinedProperties.allKeys) {
                    if (![cachedProperties objectForKey:key]) {
                        [cachedProperties setObject:[combinedProperties objectForKey:key] forKey:key];
                    }
                }
            }
            
            /* hookup all the getters and setters for this class and point them at the statics */
            
            for (NSString* k in classDef.allKeys) {
                
                int type = [c getEntityPropertyType:k];
                
                if (type == SRK_PROPERTY_TYPE_ENTITYOBJECT) {
                    
                    [self injectPropertyTrapsFor:k reader:(IMP)propertyEntityIMP writer:(IMP)setPropertyEntityIMP typeEncoding:"@"];
                    
                } else if (type == SRK_PROPERTY_TYPE_ENTITYOBJECTARRAY) {
                    
                    /* array of entities */
                    
                    [self injectPropertyTrapsFor:k reader:(IMP)propertyEntityCollectionIMP writer:(IMP)setPropertyEntityCollectionIMP typeEncoding:"@"];
                    
                } else if (type == SRK_PROPERTY_TYPE_ARRAY || type == SRK_PROPERTY_TYPE_DATE || type == SRK_PROPERTY_TYPE_DICTIONARY || type == SRK_PROPERTY_TYPE_IMAGE || type == SRK_PROPERTY_TYPE_NUMBER || type == SRK_PROPERTY_TYPE_STRING || type == SRK_PROPERTY_TYPE_DATA || type == SRK_PROPERTY_TYPE_URL || type == SRK_PROPERTY_TYPE_MUTABLEDATA || type == SRK_PROPERTY_TYPE_MUTABLEDIC || type == SRK_PROPERTY_TYPE_MUTABLEARAY || type == SRK_PROPERTY_TYPE_NSOBJECT) {
                    
                    /* NSObject class */
                    
                    [self injectPropertyTrapsFor:k reader:(IMP)propertyIMP writer:(IMP)setPropertyIMP typeEncoding:"@"];
                    
                } else if (type == SRK_PROPERTY_TYPE_CHAR) {
                    
                    [self injectPropertyTrapsFor:k reader:(IMP)propertyCharIMP writer:(IMP)setPropertyCharIMP typeEncoding:"c"];
                    
                } else if (type == SRK_PROPERTY_TYPE_INT) {
                    
                    [self injectPropertyTrapsFor:k reader:(IMP)propertyIntIMP writer:(IMP)setPropertyIntIMP typeEncoding:"i"];
                    
                } else if (type == SRK_PROPERTY_TYPE_SHORT) {
                    
                    [self injectPropertyTrapsFor:k reader:(IMP)propertyShortIMP writer:(IMP)setPropertyShortIMP typeEncoding:"s"];
                    
                } else if (type == SRK_PROPERTY_TYPE_LONG) {
                    
                    [self injectPropertyTrapsFor:k reader:(IMP)propertyLongIMP writer:(IMP)setPropertyLongIMP typeEncoding:"l"];
                    
                } else if (type == SRK_PROPERTY_TYPE_LONGLONG) {
                    
                    [self injectPropertyTrapsFor:k reader:(IMP)propertyLongLongIMP writer:(IMP)setPropertyLongLongIMP typeEncoding:"q"];
                    
                } else if (type == SRK_PROPERTY_TYPE_UCHAR) {
                    
                    [self injectPropertyTrapsFor:k reader:(IMP)propertyUCharIMP writer:(IMP)setPropertyUCharIMP typeEncoding:"C"];
                    
                } else if (type == SRK_PROPERTY_TYPE_UINT) {
                    
                    [self injectPropertyTrapsFor:k reader:(IMP)propertyUIntIMP writer:(IMP)setPropertyUIntIMP typeEncoding:"I"];
                    
                } else if (type == SRK_PROPERTY_TYPE_USHORT) {
                    
                    [self injectPropertyTrapsFor:k reader:(IMP)propertyUShortIMP writer:(IMP)setPropertyUShortIMP typeEncoding:"S"];
                    
                } else if (type == SRK_PROPERTY_TYPE_ULONG) {
                    
                    [self injectPropertyTrapsFor:k reader:(IMP)propertyULongIMP writer:(IMP)setPropertyULongIMP typeEncoding:"L"];
                    
                } else if (type == SRK_PROPERTY_TYPE_ULONGLONG) {
                    
                    [self injectPropertyTrapsFor:k reader:(IMP)propertyULongLongIMP writer:(IMP)setPropertyULongLongIMP typeEncoding:"Q"];
                    
                } else if (type == SRK_PROPERTY_TYPE_FLOAT) {
                    
                    [self injectPropertyTrapsFor:k reader:(IMP)propertyFloatIMP writer:(IMP)setPropertyFloatIMP typeEncoding:"f"];
                    
                } else if (type == SRK_PROPERTY_TYPE_DOUBLE) {
                    
                    [self injectPropertyTrapsFor:k reader:(IMP)propertyDoubleIMP writer:(IMP)setPropertyDoubleIMP typeEncoding:"d"];
                    
                } else if (type == SRK_PROPERTY_TYPE_BOOL) {
                    
                    [self injectPropertyTrapsFor:k reader:(IMP)propertyBoolIMP writer:(IMP)setPropertyBoolIMP typeEncoding:"B"];
                    
                } else if (type == SRK_PROPERTY_TYPE_CHARPTR) {
                    
                    [self injectPropertyTrapsFor:k reader:(IMP)propertyCharPTRIMP writer:(IMP)setPropertyCharPTRIMP typeEncoding:"*"];
                    
                }
                
            }
            
            [SharkORM refactorTableFromEntityDefinition:classDef forTable:strClassName inDatabase:[SharkORM databaseNameForClass:[self class]] primaryKeyAsString:[self getEntityPropertyType:SRK_DEFAULT_PRIMARY_KEY_NAME] == SRK_PROPERTY_TYPE_STRING ? YES : NO];
            
            /* call the entity scripts method, before the remove missing call */
            [self entityAtRevision:[SharkORM getEntityRevision:strClassName inDatabase:[SharkORM databaseNameForClass:[self class]]]];
            
            [SharkORM removeMissingFieldsFromEntityDefinition:classDef forTable:strClassName inDatabase:[SharkORM databaseNameForClass:[self class]]];
            
            /* now register all of the relationships & create all of the default indexes that have been building up */
            for (SRKRelationship* r in relationships) {
                [SharkORM addEntityRelationship:r inDatabase:[SharkORM databaseNameForClass:[self class]]];
            }
            
            /* ask the class for it's indexes so we can clear them up as well */
            SRKIndexDefinition* idxDef = [[self class] indexDefinitionForEntity];
            if (idxDef) {
                if ([self.class uniquePropertiesForClass]) {
                    NSArray* uniqueProperties = [self.class uniquePropertiesForClass];
                    if (uniqueProperties.count == 1) {
                        [idxDef addIndexForProperty:[uniqueProperties objectAtIndex:0] propertyOrder:[[uniqueProperties objectAtIndex:0] isKindOfClass:[NSString class]] ? SRKIndexSortOrderNoCase : SRKIndexSortOrderAscending];
                    } else if (uniqueProperties.count > 1) {
                        [idxDef addIndexForProperty:[uniqueProperties objectAtIndex:0] propertyOrder:[[uniqueProperties objectAtIndex:0] isKindOfClass:[NSString class]] ? SRKIndexSortOrderNoCase : SRKIndexSortOrderAscending secondaryProperty:[uniqueProperties objectAtIndex:1] secondaryOrder:[[uniqueProperties objectAtIndex:1] isKindOfClass:[NSString class]] ? SRKIndexSortOrderNoCase : SRKIndexSortOrderAscending];
                    }
                }
                [idxDef generateIndexesForTable:strClassName inDatabase:[SharkORM databaseNameForClass:[self class]]];
            }
            
            /* now create any FTS virtual tables that might be required */
            NSArray* ftsPropertyList = [[self class] FTSParametersForEntity];
            if (ftsPropertyList) {
                [SharkORM prepareFTSTableForClass:[self class] withPropertyList:ftsPropertyList];
            } else {
                /* check to see if there is a table, and drop it because FTS is turned off */
                [SharkORM executeSQL:[NSString stringWithFormat:@"DROP TABLE fts_%@;",[[self class] description]] inDatabase:nil];
                FTSRegistry* reg = [FTSRegistry registryForTable:[[self class] description]];
                if (reg) {
                    [reg remove];
                }
            }
            
        }
        
    }
    
}

+(void)initialize {
    
    [self setupClass];
    
}

- (id)initWithPrimaryKeyValue:(NSObject*)priKeyValue {
    
    Class originalClass = ((SRKObject*)self).class;
    
    self = [[[[((SRKObject*)self).class query] whereWithFormat:@"Id = %@", priKeyValue] limit:1] fetch].firstObject;
    if (self) {
        exists = YES;
    } else {
        self = [originalClass new];
        if (self) {
            self.Id = (NSNumber*)priKeyValue;
        }
    }
    return self;
    
}

- (id)initWithDictionary:(NSDictionary *)initialValues {
    
    Class originalClass = ((SRKObject*)self).class;
    self = [originalClass new];
    if (self) {
        for (NSString* property in initialValues.allKeys) {
            setPropertyIMP(self, [[SRKUtilities new] generateSetSelectorForPropertyName:property], [initialValues valueForKey:property]);
        }
    }
    return self;
    
}

+ (instancetype)objectWithPrimaryKeyValue:(NSObject*)priKeyValue {
    return [[[[((SRKObject*)self).class query] whereWithFormat:@"Id = %@", priKeyValue] limit:1] fetch].firstObject;
}

- (id)init {
    
    /* before anything, check that this object has been setup, because the orm schema might have been reset */
    if (!refactoredEntities) {
        [self.class setupOutstandingClasses];
    }
    
    self = [super init];
    if (self) {
        
        obCount++;
        
        self.commitOptions = [SRKCommitOptions new];
        self.fieldData = [[NSMutableDictionary alloc] init];
        self.changedValues = [[NSMutableDictionary alloc] init];
        self.dirtyFields = [[NSMutableDictionary alloc] init];
        self.joinedData = [[NSMutableDictionary alloc] init];
        self.preCalculated = nil;
        
        NSString* entityName = self.class.description;
        
        /* now we fill in the field data with NSNull values until they get set by the data layer */
        @synchronized(self.fieldData) {
            for (NSString* key in [SharkORM fieldsForTable:entityName]) {
                [self.fieldData setObject:[NSNull null] forKey:key];
            }
        }
        
        /* now we ask for default values for this entity */
        NSDictionary* defaultValues = [self.class defaultValuesForEntity];
        if (defaultValues) {
            for (NSString* key in defaultValues.allKeys) {
                if ([self.fieldData objectForKey:key]) { /* this field does exist within the current schema */
                    [self.fieldData setObject:[defaultValues objectForKey:key] forKey:key];
                }
            }
        }
        
        self.exists = NO;
        self.embeddedEntities = [NSMutableDictionary new];
        self.registeredEventBlocks = [NSMutableArray new];
        
        /* now loop through any entity relationships there might be for this table */
        for (SRKRelationship* r in [SharkORM entityRelationships]) {
            
            if ([[r.sourceClass description] isEqualToString:entityName]) {
                
                /* this linking is for this table, bung a lazyloader into the property */
                
                SRKLazyLoader* ll = [[SRKLazyLoader alloc] init];
                ll.relationship = r;
                ll.parentEntity = self;
                
                [self.embeddedEntities setObject:ll forKey:r.sourceProperty];
                
            }
            
        }
        
        /* now set a default domain for this object if there is one */
        if ([[SharkORM getSettings] defaultManagedObjects]) {
            [self setManagedObjectDomain:[[SharkORM getSettings] defaultObjectDomain]];
        }
        
    }
    
    return self;
    
}


- (NSObject*)getField:(NSString*)fieldName {
    
    if (_isLightweightObject && !_isLightweightObjectLoaded) {
        
        /* check to see if this field has a value at all, if it does not have a value or even an NSNull then wel need to pull a heavy object from the database */
        @synchronized(_fieldData) {
            @autoreleasepool {
                id value = [_fieldData objectForKey:fieldName];
                if (!value || [value isKindOfClass:[NSNull class]]) {
                    
                    /* there is no point getting the whole object if we won't be using any other values */
                    BOOL retain = [SharkORM getSettings].retainLightweightObjects;
                    if (retain) {
                        SRKObject* ob = [[[[self.class query] whereWithFormat:@"Id = %@", self.Id] limit:1] fetch].firstObject;
                        if (ob) {
                            value = [ob getField:fieldName];
                            for (NSString* f in ob.fieldNames) {
                                if (![_fieldData objectForKey:f] && [ob getField:f]) {
                                    [_fieldData setObject:[ob getField:f] forKey:f];
                                }
                            }
                        }
                        _isLightweightObjectLoaded = YES;
                        @synchronized(self.preCalculated) {
                            writingPreCalculated = YES;
                            self.preCalculated = nil;
                            writingPreCalculated = NO;
                        }
                        
                    } else {
                        
                        /* do a further lightweight fetch for just the single property */
                        value = [[self.class query] fetchSpecificValueWithQuery:[NSString stringWithFormat:@"SELECT %@ FROM %@ WHERE Id = %@ LIMIT 1;",fieldName, self.class.description, self.Id]];
                        if (!value || [value isKindOfClass:[NSNull class]]) {
                            value = nil;
                        }
                        if (value) {
                            [self setFieldRaw:fieldName value:value];
                        }
                        
                    }
                    
                    
                }
                return value;
            }
        }
        return nil;
        
        
    } else if (self.preCalculated) {
        
        @synchronized(self.preCalculated) {
            
            NSObject* retObject = nil;
            
            if (!writingPreCalculated) {
                retObject = [self.preCalculated objectForKey:fieldName];
            } else {
                retObject = [self.preCalculated objectForKey:fieldName];
            }
            
            if (retObject == nil) {
                @synchronized(_joinedData) {
                    retObject = [_joinedData objectForKey:fieldName];
                }
            }
            
            /* return nil if data layer contains null, caught buy setField */
            if ([retObject isKindOfClass:[NSNull class]]) {
                retObject = nil;
            }
            
            return retObject;
            
        }
        
    } else {
        
        // merge original and changed
        
        NSMutableDictionary* mergedData = nil;
        
        @synchronized(_fieldData) {
            mergedData = [_fieldData mutableCopy];
        }
        
        @synchronized(_changedValues) {
            for (NSString* key in _changedValues.allKeys) {
                [mergedData setObject:[_changedValues objectForKey:key] forKey:key];
            }
        }
        
        @synchronized(self.preCalculated) {
            writingPreCalculated = YES;
            self.preCalculated = mergedData;
            writingPreCalculated = NO;
        }
        
        NSObject* retObject = [mergedData objectForKey:fieldName];
        if (retObject == nil) {
            retObject = [_joinedData objectForKey:fieldName];
        }
        
        /* return nil if data layer contains null, caught buy setField */
        if ([retObject isKindOfClass:[NSNull class]]) {
            retObject = nil;
        }
        return retObject;
        
    }
    
}

- (void)setJoinedField:(NSString*)fieldName value:(NSObject*)value {
    
    @synchronized(self.joinedData) {
        [self.joinedData setObject:value forKey:fieldName];
    }
    
}

- (void)setFieldWithoutNotify:(NSString*)fieldName value:(NSObject*)value {
    
    if (self.preCalculated) {
        @synchronized(self.preCalculated) {
            writingPreCalculated = YES;
            self.preCalculated = nil;
            writingPreCalculated = NO;
        }
    }
    
    if (!value) {
        value = [NSNull null];
    }
    
    if ([fieldName rangeOfString:@"_$_"].location != NSNotFound) {
        fieldName = [fieldName stringByReplacingOccurrencesOfString:@"_$_" withString:@"."];
        [self setJoinedField:fieldName value:value];
    } else {
        @synchronized(self.changedValues) {
            [_changedValues setObject:value forKey:fieldName];
            if ([fieldName isEqualToString:SRK_DEFAULT_PRIMARY_KEY_NAME]) {
                cachedPrimaryKeyValue = value;
            }
            [_dirtyFields setObject:@(1) forKey:fieldName];
            self.dirty = YES;
        }
    }
    
}

- (void)setFieldRaw:(NSString*)fieldName value:(NSObject*)value {
    
    @synchronized(self.preCalculated) {
        if (self.preCalculated) {
            self.preCalculated = nil;
        }
    }
    
    if (!value) {
        value = [NSNull null];
    }
    
    if ([fieldName rangeOfString:@"_$_"].location != NSNotFound) {
        fieldName = [fieldName stringByReplacingOccurrencesOfString:@"_$_" withString:@"."];
        [self setJoinedField:fieldName value:value];
    } else {
        @synchronized(self.changedValues) {
            [_changedValues setObject:value forKey:fieldName];
            if ([fieldName isEqualToString:SRK_DEFAULT_PRIMARY_KEY_NAME]) {
                cachedPrimaryKeyValue = value;
            }
            [_dirtyFields setObject:@(1) forKey:fieldName];
            self.dirty = YES;
        }
    }
    
}

- (void)setField:(NSString*)fieldName value:(NSObject*)value {
    
    [self setFieldRaw:fieldName value:value];
    
}

// database functions

- (void)restore {
    
    @synchronized(self.changedValues) {
        [self.changedValues removeAllObjects];
        [self.dirtyFields removeAllObjects];
        self.dirty = NO;
    }
    
}


- (NSArray*)fieldNames {
    
    return [SharkORM fieldsForTable:[self.class description]];
    
}

- (NSArray*)modifiedFieldNames {
    
    @synchronized (self.dirtyFields) {
        
        return _dirtyFields.allKeys;
        
    }
    
}

- (void)setBase {
    
    @synchronized(self.changedValues) {
        @synchronized(self.fieldData) {
            
            for (NSString* key in [self.changedValues allKeys]) {
                
                [self.fieldData setObject:[self.changedValues objectForKey:key] forKey:key];
                
            }
            [self.changedValues removeAllObjects];
            
        }
    }
    
}

- (void)rollback {
    if (self.transactionInfo) {
        [self.transactionInfo restoreValuesIntoObject:self];
        self.transactionInfo = nil;
    }
}

- (NSDictionary*)entityDictionary {
    
    // merge original and changed
    NSMutableDictionary* mergedData = nil;
    
    @synchronized(self.fieldData) {
        mergedData = [self.fieldData mutableCopy];
    }
    
    @synchronized(self.changedValues) {
        for (NSString* key in self.changedValues.allKeys) {
            [mergedData setObject:[self.changedValues objectForKey:key] forKey:key];
        }
    }
    
    return [NSDictionary dictionaryWithDictionary:mergedData];
    
}

- (NSMutableDictionary*)entityContentsAsObjects {
    NSMutableDictionary* contents = [NSMutableDictionary dictionaryWithDictionary:[self entityDictionary]];
    @synchronized (self.embeddedEntities) {
        for (NSString* property in self.embeddedEntities.allKeys) {
            [contents setObject:[self.embeddedEntities objectForKey:property] forKey:property];
        }
    }
    return contents;
}


/*  linked properties need to be intercepted */
/*
 *  we intercept a call for self.entity and set self.__entityId = settingValue.Id
 *
 */

- (void)reloadRelationships {
    
    /* now loop through any entity relationships there might be for this table */
    for (SRKRelationship* r in [SharkORM entityRelationships]) {
        
        if ([[r.sourceClass description] isEqualToString:[self.class description]]) {
            
            SRKLazyLoader* ll = [SRKLazyLoader new];
            ll.relationship = r;
            ll.parentEntity = self;
            
            if (r.entityPropertyName) {
                [self.embeddedEntities setObject:ll forKey:r.entityPropertyName];
            } else {
                
            }
            
        }
        
    }
    
}

- (NSString*)description {
    
    /* format this entry into a dictionary for print out */
    NSMutableDictionary* info = [NSMutableDictionary new];
    
    [info setObject:[self.class description] forKey:@"entity"];
    [info setObject:SRK_DEFAULT_PRIMARY_KEY_NAME forKey:@"pk column"];
    [info setObject:[self Id] ? [self Id] : [NSNull null] forKey:@"pk value"];
    
    // fields
    NSMutableArray* fieldValues = [NSMutableArray new];
    for (NSString* field in self.fieldNames) {
        
        if ([[self getField:field] isKindOfClass:[NSString class]]) {
            
            [fieldValues addObject:@{@"name":field, @"type":@"text", @"value":[self getField:field]}];
            
        } else if ([[self getField:field] isKindOfClass:[NSNumber class]]) {
            
            [fieldValues addObject:@{@"name":field, @"type":@"number", @"value":[self getField:field]}];
            
        } else if ([[self getField:field] isKindOfClass:[NSDate class]]) {
            
            [fieldValues addObject:@{@"name":field, @"type":@"date", @"value":[self getField:field]}];
            
        } else if ([[self getField:field] isKindOfClass:NSClassFromString(TARGET_OS_MAC ? @"NSImage" : @"UIImage")]) {
            
            [fieldValues addObject:@{@"name":field, @"type":@"image", @"value":[self getField:field]}];
            
        } else if ([[self getField:field] isKindOfClass:[NSNull class]]) {
            
            [fieldValues addObject:@{@"name":field, @"type":@"null", @"value":[self getField:field]}];
            
        } else if ([[self getField:field] isKindOfClass:[NSData class]]) {
            
            [fieldValues addObject:@{@"name":field, @"type":@"blob", @"value":[self getField:field]}];
            
        } else {
            
            [fieldValues addObject:@{@"name":field, @"type":@"unset", @"value":[NSNull null]}];
            
        }
        
    }
    [info setObject:fieldValues forKey:@"properties"];
    
    // relationships
    NSMutableArray* matchingRelationships = [NSMutableArray new];
    for (SRKRelationship* r in [SharkORM entityRelationships]) {
        if ([[r.sourceClass description] isEqualToString:[self.class description]]) {
            NSMutableDictionary* d = [NSMutableDictionary new];
            [d setObject:r.entityPropertyName forKey:@"property"];
            [d setObject:[r.targetClass description] forKey:@"target"];
            
            NSObject* thisOb = [self.embeddedEntities objectForKey:r.sourceProperty];
            if (thisOb) {
                if ([thisOb isKindOfClass:[SRKLazyLoader class]]) {
                    [d setObject:@"unloaded" forKey:@"status"];
                } else {
                    [d setObject:@"loaded" forKey:@"status"];
                }
            }
            else {
                /* no lazy or value set for this property */
                [d setObject:@"unloaded" forKey:@"status"];
            }
            
            [matchingRelationships addObject:d];
        }
    }
    [info setObject:matchingRelationships forKey:@"relationships"];
    
    // joined data
    if (self.joinedResults) {
        [info setObject:self.joinedResults forKey:@"joins"];
    }
    
    return [NSString stringWithFormat:@"%@", info];
    
}


- (id)transformInto:(id)targetObject {
    
    id ob = targetObject;
    
    /* used to populate partial classes */
    for (NSString* fieldName in self.fieldNames) {
        
        if ([ob respondsToSelector:[[SRKUtilities new] generateSetSelectorForPropertyName:fieldName]]) {
            
            /*
             *  ok so there are two things this could be, a partial class with matching properties and types or a "bound" object
             */
            
            /* inspect the class */
            
            unsigned int outCount;
            objc_property_t *properties = class_copyPropertyList([targetObject class], &outCount);
            
            for (int i = 0; i < outCount; i++) {
                
                objc_property_t property = properties[i];
                
                const char* name = property_getName(property);
                
                if ([[NSString stringWithUTF8String:name] isEqualToString:fieldName]) {
                    
                    NSString* attributes = [NSString stringWithUTF8String:property_getAttributes(property)];
                    if ([attributes rangeOfString:@","].location != NSNotFound) {
                        attributes = [attributes substringToIndex:[attributes rangeOfString:@","].location];
                    }
                    
                    if ([attributes rangeOfString:@"T@"].location != NSNotFound) {
                        attributes = [attributes substringFromIndex:[attributes rangeOfString:@"T@"].location+1];
                    }
                    
                    const char* typeEncoding = [attributes UTF8String];
                    
                    if ([[NSString stringWithUTF8String:typeEncoding] isEqualToString:@"@\"UIImageView\""]) {
                        SuppressPerformSelectorLeakWarning(
                                                           id ob = [targetObject performSelector:NSSelectorFromString(fieldName)];
                                                           if (ob) {
                                                               [ob performSelector:NSSelectorFromString(@"setImage:") withObject:[self performSelector:NSSelectorFromString(fieldName)]];
                                                           }
                                                           );
                    }
                    
                    else if ([[NSString stringWithUTF8String:typeEncoding] isEqualToString:@"@\"UILabel\""]) {
                        SuppressPerformSelectorLeakWarning(
                                                           id ob = [targetObject performSelector:NSSelectorFromString(fieldName)];
                                                           if (ob) {
                                                               [ob performSelector:NSSelectorFromString(@"setText:") withObject:[self performSelector:NSSelectorFromString(fieldName)]];
                                                           }
                                                           );
                    }
                    
                    else {
                        /* it's a non UI type */
                        SuppressPerformSelectorLeakWarning(
                                                           [ob performSelector:[[SRKUtilities new] generateSetSelectorForPropertyName:fieldName] withObject:[self performSelector:NSSelectorFromString(fieldName)]];
                                                           );
                    }
                }
            }
            
            free(properties);
            
            
        }
        
    }
    
    return ob;
    
}


- (id)copy {
    NSObject *retObj = [self copyWithZone:nil];
    return retObj;
}

- (id)copyWithZone:(NSZone *)zone {
    
    /* create a copy of this object and copy the values in */
    SRKObject* retObj = [self.class new];
    
    /* now we have to loop though self to match up any entity values */
    for (NSString* f in retObj.fieldNames) {
        
        if (![f isEqualToString:SRK_DEFAULT_PRIMARY_KEY_NAME]) {
            SEL aSelector = NSSelectorFromString(f);
            if ([self respondsToSelector:aSelector]) {
                
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
                NSObject* valueObject = [[self performSelector:aSelector] copy];
                if (!valueObject) {
                    valueObject = [NSNull null];
                }
                
                [retObj setField:f value:valueObject];
                [retObj performSelector:[[SRKUtilities new] generateSetSelectorForPropertyName:f] withObject:valueObject];
                
            } else {
                /* this might be a hidden link field e.g. _{objname}Id */
                if ([f rangeOfString:@"_"].location != NSNotFound && [f rangeOfString:@"_"].location == 0) {
                    [retObj setFieldRaw:f value:[self getField:f]];
                }
            }
        }
        
    }
    
    /* update the Id with the value from the source entity */
    [retObj setId:self.Id];
    retObj.exists = self.exists;
    
    return retObj;
}

- (BOOL)__removeRaw {
    
    if (self.sterilised && !self.isLightweightObject) {
        return NO;
    }
    
    if ([self entityWillDelete]) {
        
        if ([[SharkORM new] removeObject:self]) {
            
            [self entityDidDelete];
            // now raise a global event, but only if we are not within a transaction.
            // Because a transaction will also raise the event
            if (!self.transactionInfo) {
                SRKGlobalEventCallback callback = [[SRKGlobals sharedObject] getDeleteCallback];
                if (callback) {
                    callback(self);
                }
            }
            
            self.exists = NO;
            
            /* now send out the live message as well as tiggering the local event */
            
            if (![[self class] entityDoesNotRaiseEvents] && ![SRKTransaction transactionIsInProgress] && self.commitOptions.triggerEvents) {
                SRKEvent* e = [SRKEvent new];
                e.event = SharkORMEventDelete;
                e.entity = self;
                e.changedProperties = nil;
                [[SRKRegistry sharedInstance] broadcast:e];
            }
            
            /* clear the modified fields list */
            @synchronized(self.changedValues) {
                [self.changedValues removeAllObjects];
                [self.dirtyFields removeAllObjects];
                self.dirty = NO;
            }
            
            /* now remove the primary key now the event has been broadcast */
            self.Id = nil;
            
            return YES;
        }
    }
    
    return NO;
    
}

- (BOOL)remove {
    
    if(!self.context) {
        
        [self __removeRaw];
        
    }  else {
        
        self.isMarkedForDeletion = YES;
        
    }
    return YES;
}

- (BOOL)__commitRawWithObjectChain:(SRKObjectChain *)chain {
    
    if (self.sterilised) {
        return NO;
    }
    
    // check to see if we have any embedded entities to ignore, if so add them into the object chain so they appear to have already been processed
    if (self.commitOptions.ignoreEntities && self.commitOptions.ignoreEntities.count > 0) {
        for (SRKObject* ignoredObject in self.commitOptions.ignoreEntities) {
            [chain addObjectToChain:ignoredObject];
        }
    }
    
    // now check to see if all objects are to be ignored
    if (!self.commitOptions.commitChildObjects) {
        for (SRKObject* ignoredObject in self.embeddedEntities) {
            [chain addObjectToChain:ignoredObject];
        }
    }
    
    if (!self.exists) {
        
        /* insert */
        if ([self entityWillInsert]) {
            
            /* check to see if this entity used a string based primary key */
            id currentId = [self Id];
            if (!currentId && [self.class getEntityPropertyType:SRK_DEFAULT_PRIMARY_KEY_NAME] == SRK_PROPERTY_TYPE_STRING) {
                self.Id = (id)[SRKUtilities generateGUID];
            }
            
            /* check to see if any entities have been added into this object, commit them */
            for (SRKObject* o in self.embeddedEntities.allValues) {
                if ([o isKindOfClass:[SRKObject class]]) {
                    // check to see if this object has already appeard in this chain.
                    if (![chain doesObjectExistInChain:o]) {
                        [(SRKObject*)o __commitRawWithObjectChain:[chain addObjectToChain:self]];
                    }
                }
            }
            
            for (SRKRelationship* r in [SharkORM entityRelationships]) {
                if ([[r.sourceClass description] isEqualToString:[self.class description]] && r.relationshipType == SRK_RELATE_ONETOONE) {
                    
                    /* this is a link field that needs to be updated */
                    NSObject* e = [self.embeddedEntities objectForKey:r.entityPropertyName];
                    if(e && [e isKindOfClass:[SRKObject class]]) {
                        [self setField:[NSString stringWithFormat:@"%@",r.entityPropertyName] value:((SRKObject*)e).Id];
                        // if the new .Id value is NULL or .sterilized = TRUE then we need to remove this value.
                        if (((SRKObject*)e).sterilised || ((SRKObject*)e).Id == nil) {
                            [self.embeddedEntities removeObjectForKey:r.entityPropertyName];
                        }
                    }
                    
                }
            }
            
            /* now we need to populate any fields that are based on primatives with their default values */
            for (NSString* f in self.fieldNames) {
                
                int type = [self.class getEntityPropertyType:f];
                if ([self.class isTypeAPrimitive:type] && ![self getField:f]) {
                    [self setFieldRaw:f value:@(0)];
                }
                
            }
            
            
            if([[SharkORM new] commitObject:self]) {
                
                self.exists = YES;
                [self entityDidInsert];
                
                // now raise a global event
                if (!self.transactionInfo) {
                    SRKGlobalEventCallback callback = [[SRKGlobals sharedObject] getInsertCallback];
                    if (callback) {
                        callback(self);
                    }
                }
                
                /* now send out the live message as well as tiggering the local event */
                
                if (![[self class] entityDoesNotRaiseEvents] && ![SRKTransaction transactionIsInProgress] && self.commitOptions.triggerEvents) {
                    
                    SRKEvent* e = [SRKEvent new];
                    e.event = SharkORMEventInsert;
                    e.entity = self;
                    e.changedProperties = self.modifiedFieldNames;
                    [[SRKRegistry sharedInstance] broadcast:e];
                    
                }
                
                /* clear the modified fields list */
                @synchronized(self.changedValues) {
                    [self.changedValues removeAllObjects];
                    [self.dirtyFields removeAllObjects];
                    self.dirty = NO;
                }
                
                return YES;
                
            }
            
            
        }
        
    } else {
        
        /* update */
        
        /* check to see if this entity used a string based primary key */
        id currentId = [self Id];
        if (!currentId && [self.class getEntityPropertyType:SRK_DEFAULT_PRIMARY_KEY_NAME] == SRK_PROPERTY_TYPE_STRING) {
            self.Id = (id)[SRKUtilities generateGUID];
        }
        
        if ([self entityWillUpdate]) {
            
            /* check to see if any entities have been added into this object, commit them, but only if they do not have a PK or any outstanding changes (stops cyclical inserts) */
            
            for (SRKObject* o in self.embeddedEntities.allValues) {
                if ([o isKindOfClass:[SRKObject class]]) {
                    if (!o.Id || o.dirty) {
                        if (![chain doesObjectExistInChain:o]) {
                            [o __commitRawWithObjectChain:[chain addObjectToChain:self]];
                        }
                    }
                }
            }
            
            for (SRKRelationship* r in [SharkORM entityRelationships]) {
                if ([[r.sourceClass description] isEqualToString:[self.class description]] && r.relationshipType == SRK_RELATE_ONETOONE) {
                    
                    /* this is a link field that needs to be updated */
                    NSObject* e = [self.embeddedEntities objectForKey:r.entityPropertyName];
                    if(e && [e isKindOfClass:[SRKObject class]]) {
                        [self setField:[NSString stringWithFormat:@"%@",r.entityPropertyName] value:((SRKObject*)e).Id];
                        // if the new .Id value is NULL or .sterilized = TRUE then we need to remove this value.
                        if (((SRKObject*)e).sterilised || ((SRKObject*)e).Id == nil) {
                            [self.embeddedEntities removeObjectForKey:r.entityPropertyName];
                        }
                    }
                    
                }
            }
            
            if([[SharkORM new] commitObject:self]) {
                
                self.exists = YES;
                [self entityDidUpdate];
                
                // now raise a global event
                if (!self.transactionInfo) {
                    SRKGlobalEventCallback callback = [[SRKGlobals sharedObject] getUpdateCallback];
                    if (callback) {
                        callback(self);
                    }
                }
                /* now send out the live message as well as triggering the local event */
                if (![[self class] entityDoesNotRaiseEvents] && ![SRKTransaction transactionIsInProgress] && self.commitOptions.triggerEvents) {
                    SRKEvent* e = [SRKEvent new];
                    e.event = SharkORMEventUpdate;
                    e.entity = self;
                    e.changedProperties = self.modifiedFieldNames;
                    [[SRKRegistry sharedInstance] broadcast:e];
                }
                /* clear the modified fields list */
                @synchronized(self.changedValues) {
                    [self.changedValues removeAllObjects];
                    [self.dirtyFields removeAllObjects];
                    self.dirty = NO;
                }
                
                return YES;
                
            }
            
        }
        
    }
    
    return NO;
    
}

- (BOOL)commit {
    
    /* make a unique test if neccesary */
    NSArray* uniqueProperties = [self.class uniquePropertiesForClass];
    if (uniqueProperties) {
        NSMutableString* queryString = [NSMutableString new];
        NSMutableArray* propertyValues = [NSMutableArray new];
        for (NSString* property in uniqueProperties) {
            if (!(queryString.length == 0)) {
                [queryString appendString:@" AND "];
            }
            [queryString appendString:[NSString stringWithFormat:@" %@ = %%@ ", property]];
            [propertyValues addObject:[self getField:property] ? [self getField:property] : [NSNull null]];
        }
        if (self.exists) {
            [queryString appendString:@" AND Id != %@"];
            [propertyValues addObject:self.Id];
        }
        if (queryString.length != 0) {
            
        }
        if ([[[self.class query] whereWithFormat:queryString withParameters:propertyValues] count]) {
            return NO;
        }
    }
    
    if(!self.context) {
        
        [self __commitRawWithObjectChain:[SRKObjectChain new]];
        
    } else {
        
        /* raise an error because you have tried to commit an entity that is within a context */
        SRKError* err = [SRKError new];
        err.errorMessage = @"You have attempted to commit an individual entity directly that is part of a context";
        
        if ([[[SRKGlobals sharedObject] delegate] respondsToSelector:@selector(databaseError:)]) {
            [[[SRKGlobals sharedObject] delegate] performSelector:@selector(databaseError:) withObject:err];
        }
        
    }
    return YES;
}

- (BOOL)entityWillInsert {
    return YES;
}
- (BOOL)entityWillUpdate {
    return YES;
}
- (BOOL)entityWillDelete {
    return YES;
}

- (void)entityDidInsert {
    
}

- (void)entityDidUpdate {
    
}

- (void)entityDidDelete {
    
}

- (void)dealloc {
    /* clean up the observers */
    
    obCount--;
    
    if (managedObjectDomain || (self.registeredEventBlocks && self.registeredEventBlocks.count > 0)) {
        [[SRKRegistry sharedInstance] remove:self];
    }
    
    _registeredEventBlocks = nil;
    _fieldData = nil;
    self.preCalculated = nil;
    _joinedData = nil;
    _changedValues = nil;
    _dirtyFields = nil;
    self.dirty = NO;
    _eventsDelegate = nil;
    _creatorFunctionName = nil;
    
}

@end
