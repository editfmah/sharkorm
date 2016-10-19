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



#import "SRKTransactionGroup.h"
#import "SRKObject+Private.h"
#import "SRKDefinitions.h"
#import "SharkORM+Private.h"
#import "sqlite3.h"
#import "SRKRegistry.h"
#import "SRKGlobals.h"

static NSMutableDictionary* transactionForThread = nil;

@implementation SRKTransactionGroup

+ (void)updateObjectForTransactionId:(NSString*)identifier withIndex:(NSNumber*)indexPosition newPrimaryKeyValue:(NSNumber*)pkValue {
	if (transactionForThread) {
		SRKTransactionGroup* t = [transactionForThread objectForKey:identifier];
		if (t) {
			@synchronized(t.transactionItems) {
				SRKTransactionElement* item = [t.transactionItems objectAtIndex:indexPosition.integerValue];
				[item.originalObject setField:SRK_DEFAULT_PRIMARY_KEY_NAME value:pkValue];
			}
		}
	}
}

+ (BOOL)isEfectiveTransaction {
	if (!transactionForThread) {
		transactionForThread = [NSMutableDictionary new];
	}
	return [transactionForThread objectForKey:[NSString stringWithFormat:@"%@", [NSThread currentThread].description]] ? YES : NO;
}

+ (SRKTransactionGroup*)createNewCollection {
	
	SRKTransactionGroup* t = [SRKTransactionGroup new];
	return t;
	
}

+ (SRKTransactionGroup*)createEffectiveCollection {
	if (!transactionForThread) {
		transactionForThread = [NSMutableDictionary new];
	}
	@synchronized(transactionForThread) {
		SRKTransactionGroup* t = nil;
		t = [transactionForThread objectForKey:[NSString stringWithFormat:@"%@", [NSThread currentThread].description]];
		if (!t) {
			t = [SRKTransactionGroup new];
			[transactionForThread setObject:t forKey:[NSString stringWithFormat:@"%@", [NSThread currentThread].description]];
		}
		return t;
	}
}

+ (void)clearEffectiveTransaction {
	@synchronized(transactionForThread) {
		[transactionForThread removeObjectForKey:[NSString stringWithFormat:@"%@", [NSThread currentThread].description]];
	}
}

- (id)init {
	self = [super init];
	if (self) {
		self.transactionItems = [NSMutableArray new];
		self.usedDatabases = [NSMutableArray new];
		self.startTransactionStatement = SRK_START_TRANSACTION_STATEMENT;
		self.commitTransactionStatement = SRK_COMMIT_TRANSACTION_STATEMENT;
		self.rollbackTransactionStatement = SRK_ROLLBACK_TRANSACTION_STATEMENT;
		self.transactionClosed = NO;
	}
	return self;
}


- (void)addItem:(SRKTransactionElement *)item {
	@synchronized(self.usedDatabases) {
		if (![self.usedDatabases containsObject:item.database]) {
			[self.usedDatabases addObject:item.database];
		}
	}
	@synchronized(self.transactionItems) {
		[self.transactionItems addObject:item];
	}
}

- (id)commit {
	
	BOOL        succeded = YES;
	
	@autoreleasepool {
		
		
		/* loop the transactions per database file */
		@synchronized([[SRKGlobals sharedObject] writeLockObject]) {
			
			for (NSString* databaseNameForClass in self.usedDatabases) {
				if (succeded) {
					sqlite3*    databaseHandle = [SharkORM handleForDatabase:databaseNameForClass];
					[SharkORM executeSQL:self.startTransactionStatement inDatabase:databaseNameForClass];
					@synchronized(self.transactionItems) {
						
						for (SRKTransactionElement* item in self.transactionItems) {
							@autoreleasepool {
								if (succeded) {
									if (item.database == databaseNameForClass) {
										sqlite3_stmt* statement;
										int priKeyType = [SharkORM primaryKeyType:[item.originalObject.class description]];
										if (sqlite3_prepare_v2([SharkORM handleForDatabase:databaseNameForClass], [item.statementSQL UTF8String], (int)item.statementSQL.length, &statement, NULL) == SQLITE_OK) {
											/* now bind the data into the table */
											int idx = 1;
											for (id value in item.parameters) {
												if ([value isKindOfClass:[NSNumber class]]) {
													CFNumberType numberType = CFNumberGetType((CFNumberRef)(NSNumber*)value);
													if (numberType == kCFNumberSInt64Type || numberType == kCFNumberLongLongType) {
														sqlite3_bind_int64(statement, idx, [(NSNumber*)value longLongValue]);
													} else {
														sqlite3_bind_double(statement, idx, [(NSNumber*)value doubleValue]);
													}
													
                                                } else if ([value isKindOfClass:[NSDate class]]) {
                                                    sqlite3_bind_double(statement, idx, [@(((NSDate*)value).timeIntervalSince1970) doubleValue]);
                                                } else if ([value isKindOfClass:[NSString class]]) {
													sqlite3_bind_text16(statement, idx, [(NSString*)value cStringUsingEncoding:NSUTF16StringEncoding],@([(NSString*)value lengthOfBytesUsingEncoding:NSUTF16StringEncoding]).intValue , SQLITE_TRANSIENT);
												} else if ([value isKindOfClass:[NSData class]]) {
													NSData* d = (NSData*)value;
													sqlite3_bind_blob(statement, idx, [d bytes], @([d length]).intValue, SQLITE_TRANSIENT);
												}  else {
													sqlite3_bind_null(statement, idx);
												}
												idx++;
											}
											
											int result = sqlite3_step(statement);
											switch (result) {
												case SQLITE_DONE:
												{
													if (priKeyType == SQLITE_INTEGER) {
														if (!item.originalObject.exists) {
															[item.originalObject setField:SRK_DEFAULT_PRIMARY_KEY_NAME value:@(sqlite3_last_insert_rowid(databaseHandle))];
														}
													}
												}
													break;
												case SQLITE_LOCKED:
												{
													succeded = NO;
												}
													break;
												case SQLITE_BUSY:
												{
													succeded = NO;
												}
													break;
												default:
												{
													/* error in upsert statement */
													if ([[SRKGlobals sharedObject] delegate] && [[[SRKGlobals sharedObject] delegate] respondsToSelector:@selector(databaseError:)]) {
														
														SRKError* e = [SRKError new];
														e.sqlQuery = item.statementSQL;
														e.errorMessage = [NSString stringWithUTF8String:sqlite3_errmsg(databaseHandle)];
														[[[SRKGlobals sharedObject] delegate] databaseError:e];
														
													}
													succeded = NO;
													break;
												}
											}
										} else {
											/* error in prepare statement */
											if ([[SRKGlobals sharedObject] delegate] && [[[SRKGlobals sharedObject] delegate] respondsToSelector:@selector(databaseError:)]) {
												
												SRKError* e = [SRKError new];
												e.sqlQuery = item.statementSQL;
												e.errorMessage = [NSString stringWithUTF8String:sqlite3_errmsg(databaseHandle)];
												[[[SRKGlobals sharedObject] delegate] databaseError:e];
												
											}
										}
										
										sqlite3_finalize(statement);
										
									}
								}
							}
						}
					}
					
					/* end of transactions for this database */
					if (succeded) {
						
						/* commit */
						@autoreleasepool {
							[SharkORM executeSQL:self.commitTransactionStatement inDatabase:databaseNameForClass];
						}
						
						self.transactionClosed = YES;
						
						@synchronized(self.transactionItems) {
							
							for (SRKTransactionElement* item in self.transactionItems) {
								
								@autoreleasepool {
									
									[item.originalObject setBase];
									
									/* check to see if this object is a fts object and clear the existing row */
									if ([[item.originalObject class] FTSParametersForEntity]) {
										if ([item.originalObject.Id isKindOfClass:[NSNumber class]]) {
											[SharkORM executeSQL:[NSString stringWithFormat:@"DELETE FROM fts_%@ WHERE docid = %@;", [[item.originalObject class] description], [item.originalObject getField:SRK_DEFAULT_PRIMARY_KEY_NAME]] inDatabase:nil];
										} else {
											[SharkORM executeSQL:[NSString stringWithFormat:@"DELETE FROM fts_%@ WHERE docid = '%@;'", [[item.originalObject class] description], [item.originalObject getField:SRK_DEFAULT_PRIMARY_KEY_NAME]] inDatabase:nil];
										}
									}
									
									if (item.eventType == SharkORMEventInsert) {
										
										NSMutableString* propertiesList = [NSMutableString new];
										for (NSString* p in [[item.originalObject class] FTSParametersForEntity]) {
											if (propertiesList.length > 0) {
												[propertiesList appendString:@", "];
											}
											[propertiesList appendString:p];
										}
										
										if ([item.originalObject.Id isKindOfClass:[NSNumber class]]) {
											[SharkORM executeSQL:[NSString stringWithFormat:@"INSERT INTO fts_%@(docid, %@) SELECT Id, %@ FROM %@ WHERE Id = %@", [[item.originalObject class] description],propertiesList,propertiesList, [[item.originalObject class] description], [item.originalObject getField:SRK_DEFAULT_PRIMARY_KEY_NAME]] inDatabase:nil];
										} else {
											[SharkORM executeSQL:[NSString stringWithFormat:@"INSERT INTO fts_%@(docid, %@) SELECT Id, %@ FROM %@ WHERE Id = '%@'", [[item.originalObject class] description],propertiesList,propertiesList, [[item.originalObject class] description], [item.originalObject getField:SRK_DEFAULT_PRIMARY_KEY_NAME]] inDatabase:nil];
										}
										
										[item.originalObject entityDidInsert];
										if (!item.originalObject.exists) {
											/* now we need to register this object with the default registry, first check to see if the user wants a default domain */
											item.originalObject.exists = YES;
											if ([SharkORM getSettings].defaultManagedObjects) {
												[item.originalObject setManagedObjectDomain:[SharkORM getSettings].defaultObjectDomain];
											}
										}
										item.originalObject.exists = YES;
										
										/* now send out the live message as well as tiggering the local event */
										
										if (![item.originalObject.class entityDoesNotRaiseEvents]) {
											SRKEvent* e = [SRKEvent new];
											e.event = SharkORMEventInsert;
											e.entity = item.originalObject;
											e.changedProperties = item.originalObject.modifiedFieldNames;
											[[SRKRegistry sharedInstance] broadcast:e];
										}
										
										/* clear the modified fields list */
										@synchronized(item.originalObject.changedValues) {
											[item.originalObject.changedValues removeAllObjects];
											[item.originalObject.dirtyFields removeAllObjects];
                                            item.originalObject.dirty = NO;
										}
										
									}
									if (item.eventType == SharkORMEventUpdate) {
										
										NSMutableString* propertiesList = [NSMutableString new];
										for (NSString* p in [[item.originalObject class] FTSParametersForEntity]) {
											if (propertiesList.length > 0) {
												[propertiesList appendString:@", "];
											}
											[propertiesList appendString:p];
										}
										
										if ([item.originalObject.Id isKindOfClass:[NSNumber class]]) {
											[SharkORM executeSQL:[NSString stringWithFormat:@"INSERT INTO fts_%@(docid, %@) SELECT Id, %@ FROM %@ WHERE Id = %@", [[item.originalObject class] description],propertiesList,propertiesList, [[item.originalObject class] description], [item.originalObject getField:SRK_DEFAULT_PRIMARY_KEY_NAME]] inDatabase:nil];
										} else {
											[SharkORM executeSQL:[NSString stringWithFormat:@"INSERT INTO fts_%@(docid, %@) SELECT Id, %@ FROM %@ WHERE Id = '%@'", [[item.originalObject class] description],propertiesList,propertiesList, [[item.originalObject class] description], [item.originalObject getField:SRK_DEFAULT_PRIMARY_KEY_NAME]] inDatabase:nil];
										}
										
										[item.originalObject entityDidUpdate];
										
										/* now send out the live message as well as triggering the local event */
										if (![item.originalObject.class entityDoesNotRaiseEvents]) {
											SRKEvent* e = [SRKEvent new];
											e.event = SharkORMEventUpdate;
											e.entity = item.originalObject;
											e.changedProperties = item.originalObject.modifiedFieldNames;
											[[SRKRegistry sharedInstance] broadcast:e];
										}
										
										/* clear the modified fields list */
										@synchronized(item.originalObject.changedValues) {
											[item.originalObject.changedValues removeAllObjects];
											[item.originalObject.dirtyFields removeAllObjects];
                                            item.originalObject.dirty = NO;
										}
										
									}
									if (item.eventType == SharkORMEventDelete) {
										[item.originalObject entityDidDelete];
										item.originalObject.exists = NO;
										
										/* now send out the live message as well as tiggering the local event */
										
										if (![item.originalObject.class entityDoesNotRaiseEvents]) {
											SRKEvent* e = [SRKEvent new];
											e.event = SharkORMEventDelete;
											e.entity = item.originalObject;
											e.changedProperties = nil;
											[[SRKRegistry sharedInstance] broadcast:e];
										}
										
										/* clear the modified fields list */
										@synchronized(item.originalObject.changedValues) {
											[item.originalObject.changedValues removeAllObjects];
											[item.originalObject.dirtyFields removeAllObjects];
                                            item.originalObject.dirty = NO;
										}
										
										/* now remove the primary key now the event has been broadcast */
										item.originalObject.Id = nil;
									}
									
								}
								
							}
						}
						
						
					} else {
						/* rollback */
						self.transactionClosed = YES;
						
						[SharkORM executeSQL:self.rollbackTransactionStatement inDatabase:databaseNameForClass];
						@synchronized(self.transactionItems) {
							for (SRKTransactionElement* item in self.transactionItems) {
								if (item.eventType == SharkORMEventInsert) {
									[item.originalObject setField:SRK_DEFAULT_PRIMARY_KEY_NAME value:[NSNull null]];
								}
							}
						}
					}
				}
			}
		}
	}
	
	return succeded ? @(succeded) : nil;
	
}

@end
