//
//  SRKQuery+Private.h
//  SharkORM
//
//  Copyright © 2016 SharkSync. All rights reserved.
//

#ifndef SRKQuery_Private_h
#define SRKQuery_Private_h

#import "SharkORM.h"

@interface SRKQuery ()

@property (strong) Class						classDecl;
@property (strong) NSString*					whereClause;
@property (strong) NSString*					orderBy;
@property (strong) NSMutableArray*				joins;
@property int									limitOf;
@property int									offsetFrom;
@property int									batchSize;
@property (strong) NSArray*						parameters;
@property (strong) NSString*					specificSqlStatement;
@property (strong) NSString*					domainToBeAppended;
@property BOOL									quit;
@property BOOL									excludeResultsFromCache;
@property BOOL									recordPerformance;
@property BOOL									lightweightObject;
@property BOOL									fts;
@property (atomic, strong) NSArray*				prefetch;
@property (nonatomic, retain) SRKQueryProfile*	performance;
@property int									queryType;
@property (strong) NSString*					sumFieldName;
@property (strong) NSString*					groupFieldName;
@property (strong) NSString*					distinctFieldName;

- (SRKQuery*)entityclass:(Class)entityClass;
- (id)fetchSpecificValueWithQuery:(NSString*)query;

@end

#endif /* SRKQuery_Private_h */
