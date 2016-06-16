//
//  SharkORMUtilities.h
//  SharkORM
//
//  Copyright © 2016 SharkSync. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "sqlite3.h"
#import "SharkORM.h"

@interface SRKUtilities : NSObject

+ (NSString*)generateGUID;
- (NSString *)originalColumnName:(NSString *)columnName;
- (NSString *)normalizedColumnName:(NSString *)columnName;
- (NSString *)propertyNameFromSelector:(SEL)selector forObject:(SRKObject*)object;
- (id)sqlite3_column_objc:(sqlite3_stmt *)stmt column:(int)i;
- (SEL)generateSetSelectorForPropertyName:(NSString*)fieldname;
- (void)bindParameters:(NSArray*)params toStatement:(sqlite3_stmt*)statement;
- (NSString*)formatQuery:(NSString*)query withArguments:(NSMutableArray*)arguments;
- (NSDictionary*)objectifyQueryString:(NSString*)format;
- (NSDictionary*)paramatiseQueryString:(NSString*)format;

@end
