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
