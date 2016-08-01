//
//  SharkORMUtilities.m
//  SharkORM
//
//  Copyright © 2016 SharkSync. All rights reserved.
//

#import "SRKUtilities.h"
#import "SharkORM+Private.h"

@implementation SRKUtilities

+ (NSString*)generateGUID {
	
	return [[NSUUID UUID] UUIDString];
	
}

- (id)sqlite3_column_objc:(sqlite3_stmt *)stmt column:(int)i {
	
	/* detect the column type and convert to an objective_c object */
	
	NSObject* value = nil;
	
	switch (sqlite3_column_type(stmt, i)) {
		case SQLITE_INTEGER:
		{
			value = [NSNumber numberWithLongLong:sqlite3_column_int64(stmt, i)];
			
			/* the result could be a date so check the class  column type */
			const char* tableName = sqlite3_column_table_name(stmt, i);
			if (tableName) {
				NSDictionary* schema = [[SharkORM tableSchemas] objectForKey:[NSString stringWithUTF8String:tableName]];
				if (schema) {
					
					NSString* columnName = [NSString stringWithUTF8String:sqlite3_column_name(stmt, i)];
					
					SRKUtilities* dba = [SRKUtilities new];
					columnName = [dba originalColumnName:columnName];
					
					NSString* type = [schema objectForKey:columnName];
					if (type) {
						if ([type isEqualToString:@"DATETIME"]) {
							value = [NSDate dateWithTimeIntervalSince1970:(NSTimeInterval)[((NSNumber*)value) doubleValue]];
						}
					}
				}
			}
		}
			break;
		case SQLITE_FLOAT:
		{
			
			value = [NSNumber numberWithDouble:sqlite3_column_double(stmt, i)];
			
			/* the result could be a date so check the column type */
			const char* tableName = sqlite3_column_table_name(stmt, i);
			if (tableName) {
				NSDictionary* schema = [[SharkORM tableSchemas] objectForKey:[NSString stringWithUTF8String:tableName]];
				if (schema) {
					
					NSString* columnName = [NSString stringWithUTF8String:sqlite3_column_name(stmt, i)];
					SRKUtilities* dba = [SRKUtilities new];
					columnName = [dba originalColumnName:columnName];
					
					NSString* type = [schema objectForKey:columnName];
					if (type) {
						if ([type isEqualToString:@"DATETIME"]) {
							value = [NSDate dateWithTimeIntervalSince1970:(NSTimeInterval)[((NSNumber*)value) doubleValue]];
						}
					}
				}
			}
		}
			break;
		case SQLITE_TEXT:
		{
			NSData* stringData = [NSData dataWithBytes:sqlite3_column_text16(stmt, i) length:sqlite3_column_bytes16(stmt, i)];
			value = [NSString stringWithCharacters:stringData.bytes length:sqlite3_column_bytes16(stmt, i)/2];
			
			if (![[SharkORM getSettings] useEpochDates] && ((NSString*)value).length == 19) {
				
				/* check to see if this field is a valid full date */
				NSDateFormatter *dateFormat = [[NSDateFormatter alloc] init];
				[dateFormat setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
				NSObject* dValue = [dateFormat dateFromString:(NSString*)value];
				if (dValue) {
					value = dValue;
					break;
				}
				
			}
			
		}
			break;
		case SQLITE_BLOB:
		{
			
			/* performance improvement, do not decode the objects but simply return the NSData object, we can decompress this item later on */
			int sz = sqlite3_column_bytes(stmt, i);
			const void* bytes = sqlite3_column_blob(stmt, i);
			value = [NSData dataWithBytes:bytes length:sz];
			
		}
			break;
		case SQLITE_NULL:
		{
			value = [NSNull null];
		}
			break;
		default:
			break;
	}
	
	if (!value) {
		value = [NSNull null];
	}
	
	
	return value;
	
}

- (void)bindParameters:(NSArray*)params toStatement:(sqlite3_stmt*)statement {
	
	int paramCount = sqlite3_bind_parameter_count(statement);
	int passedIn = @([params count]).intValue;
	
	if(paramCount != passedIn) {
		// error
	}
	
	paramCount = 1;
	for (id p in params) {
		if ([p isKindOfClass:[NSString class]]) {
			
			sqlite3_bind_text16(statement, paramCount, [(NSString*)p cStringUsingEncoding:NSUTF16StringEncoding],@([(NSString*)p lengthOfBytesUsingEncoding:NSUTF16StringEncoding]).intValue , SQLITE_TRANSIENT);
			
		} else if ([p isKindOfClass:[NSNumber class]]) {
			CFNumberType numberType = CFNumberGetType((CFNumberRef)(NSNumber*)p);
			if (numberType == kCFNumberSInt64Type || numberType == kCFNumberLongLongType) {
				sqlite3_bind_int64(statement, paramCount, [((NSNumber*)p) longLongValue]);
			} else {
				sqlite3_bind_double(statement, paramCount, [((NSNumber*)p) doubleValue]);
			}
			
			
		} else if ([p isKindOfClass:[NSNull class]]) {
			
			sqlite3_bind_null(statement, paramCount);
			
		} else if ([p isKindOfClass:[NSDate class]]) {
			
			if ([[SharkORM getSettings] useEpochDates]) {
				
				double dateVal = [((NSDate*)p) timeIntervalSince1970];
				sqlite3_bind_double(statement, paramCount, dateVal);
				
			} else {
				
				NSDateFormatter *dateFormat = [[NSDateFormatter alloc] init];
				[dateFormat setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
				NSString* a = [NSString stringWithFormat:@"%@", [dateFormat stringFromDate:((NSDate*)p)]];
				sqlite3_bind_text16(statement, paramCount, [(NSString*)a cStringUsingEncoding:NSUTF16StringEncoding],@([(NSString*)a lengthOfBytesUsingEncoding:NSUTF16StringEncoding]).intValue, SQLITE_TRANSIENT);
				
			}
			
		} else if ([p isKindOfClass:[NSSet class]]) {
			
			/* now this is interesting, we need to inspect every element a format it appropriately */
			NSString *fmt = @"";
			for (id vParam in ((NSSet*)p).allObjects) {
				if ([vParam isKindOfClass:[NSNumber class]]) {
					fmt = [fmt stringByAppendingFormat:@",%@", vParam];
				} else {
					fmt = [fmt stringByAppendingFormat:@",'%@'", vParam];
				}
			}
			
			if (fmt.length > 0) {
				fmt = [fmt substringFromIndex:1];
			}
			
			sqlite3_bind_text16(statement, paramCount, [(NSString*)fmt cStringUsingEncoding:NSUTF16StringEncoding],@([(NSString*)fmt lengthOfBytesUsingEncoding:NSUTF16StringEncoding]).intValue , SQLITE_TRANSIENT);
			
			
		} else if ([p isKindOfClass:[SRKObject class]]) {
			id obId = ((SRKObject*)p).Id;
			if ([obId isKindOfClass:[NSNumber class]]) {
				CFNumberType numberType = CFNumberGetType((CFNumberRef)(NSNumber*)obId);
				if (numberType == kCFNumberSInt64Type || numberType == kCFNumberLongLongType) {
					sqlite3_bind_int64(statement, paramCount, [((SRKObject*)p).Id longLongValue]);
				} else {
					sqlite3_bind_double(statement, paramCount, [((SRKObject*)p).Id doubleValue]);
				}
			} else {
				NSString* sId = obId;
				sqlite3_bind_text16(statement, paramCount, [sId cStringUsingEncoding:NSUTF16StringEncoding],@([sId lengthOfBytesUsingEncoding:NSUTF16StringEncoding]).intValue , SQLITE_TRANSIENT);
			}
			
		}
		else {
			
			/* default string format */
			NSString* fmt = [NSString stringWithFormat:@"%@", p];
			sqlite3_bind_text16(statement, paramCount, [(NSString*)fmt cStringUsingEncoding:NSUTF16StringEncoding],@([(NSString*)fmt lengthOfBytesUsingEncoding:NSUTF16StringEncoding]).intValue , SQLITE_TRANSIENT);
		}
		paramCount++;
	}
	
	
}

- (SEL)generateSetSelectorForPropertyName:(NSString *)fieldname {
	
	NSString* startChar = [fieldname substringToIndex:1];
	NSString* theRest = [fieldname substringFromIndex:1];
	NSString* selectorName = [NSString stringWithFormat:@"set%@%@:", [startChar uppercaseString], theRest];
	return NSSelectorFromString(selectorName);
	
}

- (NSString *)propertyNameFromSelector:(SEL)selector forObject:(SRKObject *)object {
	
    
    //TODO:  compare the selector to the cached schema, then get the property name from there instead.
	NSMutableString *key = [NSStringFromSelector(selector) mutableCopy];
	
	// Delete "set" and ":" and lowercase first letter
	[key deleteCharactersInRange:NSMakeRange(0, 3)];
	[key deleteCharactersInRange:
	 NSMakeRange([key length] - 1, 1)];
	
	NSString *firstChar = [key substringToIndex:1];
	[key replaceCharactersInRange:NSMakeRange(0, 1)
					   withString:[firstChar lowercaseString]];
	
	if ([SharkORM column:key existsInTable:[object.class description]]) {
		return key;
	}
	
	[key replaceCharactersInRange:NSMakeRange(0, 1)
					   withString:[firstChar uppercaseString]];
	
	if ([SharkORM column:key existsInTable:[object.class description]]) {
		return key;
	}
	
	return nil;
	
}

- (NSString *)originalColumnName:(NSString *)columnName {
	
	NSString* normalizedColumnName = [columnName stringByReplacingOccurrencesOfString:@"result$" withString:@""];
	if ([normalizedColumnName rangeOfString:@"_$_"].location != NSNotFound) {
		normalizedColumnName = [columnName substringFromIndex:[columnName rangeOfString:@"_$_"].location + 2];
	}
	return normalizedColumnName;
	
}

- (NSString *)normalizedColumnName:(NSString *)columnName {
	
	NSString* normalizedColumnName = [columnName stringByReplacingOccurrencesOfString:@"result$" withString:@""];
	return normalizedColumnName;
	
}

- (NSString *)formatQuery:(NSString *)query withArguments:(NSMutableArray *)arguments {
	
	
	for (int i=0; i<arguments.count; i++) {
		
		id a = [arguments objectAtIndex:i];
		
		/* handle conversion of NSDate to ANSI STANDARD REVERSE DATE FORMAT YYYY/MM/DD HH:MM:SS */
		if ([a isKindOfClass:[NSDate class]]) {
			
			if (true) { //[[SharkORM getSettings] useEpochDates]
				NSDateFormatter *dateFormat = [[NSDateFormatter alloc] init];
				[dateFormat setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
				a = [NSString stringWithFormat:@"dateFromString('%@')", [dateFormat stringFromDate:a]];
				[arguments replaceObjectAtIndex:i withObject:a];
			} else {
				NSDateFormatter *dateFormat = [[NSDateFormatter alloc] init];
				[dateFormat setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
				a = [NSString stringWithFormat:@"'%@'", [dateFormat stringFromDate:a]];
				[arguments replaceObjectAtIndex:i withObject:a];
			}
			
		}
	}
	
	NSString* formattedString = query;
	for (NSObject* o in arguments) {
		formattedString = [formattedString stringByReplacingCharactersInRange:[formattedString rangeOfString:@"%@"] withString:[NSString stringWithFormat:@"%@", o]];
	}
	
	
	return formattedString;
}

- (NSDictionary *)objectifyQueryString:(NSString *)format {
	
	NSMutableArray* types = [NSMutableArray new];
	
	NSRange startPosition = NSMakeRange(0, 1);
	
	/* obj-c object type is expected */
	
	while (startPosition.location < format.length) {
		
		if ([[format substringWithRange:startPosition] isEqualToString:@"%"]) {
			
			/* things to check here, first no '\' to delimit, and string long enough to have an format specifier of @,i,b,f,u,l etc.. */
			if (!(startPosition.location > 0 && [[format substringWithRange:NSMakeRange(startPosition.location-1, 1)] isEqualToString:@"\\"]) && startPosition.location < format.length-1) {
				/* this not an escaped % and is not at the end of the string either */
				
				NSString* replacementChar = [format substringWithRange:NSMakeRange(startPosition.location, 2)];
				
				if ([replacementChar isEqualToString:@"%@"]) {
					
					/* NSObject type */
					[types addObject:@"OBJECT"];
					
				} else if ([replacementChar isEqualToString:@"%i"]) {
					
					/* int type */
					[types addObject:@"INT"];
					format = [format stringByReplacingCharactersInRange:NSMakeRange(startPosition.location, 2) withString:@"%@"];
					
				} else if ([replacementChar isEqualToString:@"%f"]) {
					
					/* int type */
					[types addObject:@"FLOAT"];
					format = [format stringByReplacingCharactersInRange:NSMakeRange(startPosition.location, 2) withString:@"%@"];
					
				} else if ([replacementChar isEqualToString:@"%d"]) {
					
					/* int type */
					[types addObject:@"INT"];
					format = [format stringByReplacingCharactersInRange:NSMakeRange(startPosition.location, 2) withString:@"%@"];
					
				} else if ([replacementChar isEqualToString:@"%u"]) {
					
					/* int type */
					[types addObject:@"UINT"];
					format = [format stringByReplacingCharactersInRange:NSMakeRange(startPosition.location, 2) withString:@"%@"];
					
				} else if ([replacementChar isEqualToString:@"%l"]) {
					
					/* int type */
					[types addObject:@"LONG"];
					format = [format stringByReplacingCharactersInRange:NSMakeRange(startPosition.location, 2) withString:@"%@"];
					
				}
				
			}
			
		}
		
		startPosition.location++;
	}
	
	NSMutableDictionary* d = [NSMutableDictionary new];
	[d setObject:types forKey:@"types"];
	[d setObject:format forKey:@"format"];
	
	return [NSDictionary dictionaryWithDictionary:d];
}

- (NSDictionary *)paramatiseQueryString:(NSString *)format {
	
	NSMutableArray* types = [NSMutableArray new];
	
	NSRange startPosition = NSMakeRange(0, 1);
	NSRange remainingRange = NSMakeRange(0, format.length);
	
	/* obj-c object type is expected */
	
	while (remainingRange.location < format.length) {
		
		startPosition = [format rangeOfString:@"%" options:NSLiteralSearch range:remainingRange];
		if (startPosition.location != NSNotFound) {
			startPosition.length = 1;
			remainingRange = NSMakeRange(startPosition.location+1, format.length - (startPosition.location+1));
			if (remainingRange.location >= format.length) {
				break;
			}
		} else {
			break;
		}
		
		
		/* things to check here, first no '\' to delimit, and string long enough to have an format specifier of @,i,b,f,u,l etc.. */
		if (!(startPosition.location > 0 && [[format substringWithRange:NSMakeRange(startPosition.location-1, 1)] isEqualToString:@"\\"]) && startPosition.location < format.length-1) {
			/* this not an escaped % and is not at the end of the string either */
			
			NSString* replacementChar = [format substringWithRange:NSMakeRange(startPosition.location, 2)];
			
			if ([replacementChar isEqualToString:@"%@"]) {
				
				/* NSObject type */
				[types addObject:@"OBJECT"];
				format = [format stringByReplacingCharactersInRange:NSMakeRange(startPosition.location, 2) withString:@"??"];
				
			} else if ([replacementChar isEqualToString:@"%i"]) {
				
				/* int type */
				[types addObject:@"INT"];
				format = [format stringByReplacingCharactersInRange:NSMakeRange(startPosition.location, 2) withString:@"??"];
				
			} else if ([replacementChar isEqualToString:@"%f"]) {
				
				/* int type */
				[types addObject:@"FLOAT"];
				format = [format stringByReplacingCharactersInRange:NSMakeRange(startPosition.location, 2) withString:@"??"];
				
			} else if ([replacementChar isEqualToString:@"%d"]) {
				
				/* int type */
				[types addObject:@"INT"];
				format = [format stringByReplacingCharactersInRange:NSMakeRange(startPosition.location, 2) withString:@"??"];
				
			} else if ([replacementChar isEqualToString:@"%u"]) {
				
				/* int type */
				[types addObject:@"UINT"];
				format = [format stringByReplacingCharactersInRange:NSMakeRange(startPosition.location, 2) withString:@"??"];
				
			} else if ([replacementChar isEqualToString:@"%l"]) {
				
				/* int type */
				[types addObject:@"LONG"];
				format = [format stringByReplacingCharactersInRange:NSMakeRange(startPosition.location, 2) withString:@"??"];
				
			} else if ([replacementChar isEqualToString:@"%f"]) {
				
				/* int type */
				[types addObject:@"DOUBLE"];
				format = [format stringByReplacingCharactersInRange:NSMakeRange(startPosition.location, 2) withString:@"??"];
				
			} else if ([replacementChar isEqualToString:@"%c"]) {
				
				/* int type */
				[types addObject:@"UCHAR"];
				format = [format stringByReplacingCharactersInRange:NSMakeRange(startPosition.location, 2) withString:@"??"];
				
			}
			
		}
		
	}
	
	format = [format stringByReplacingOccurrencesOfString:@"??" withString:@"?"];
	
	NSMutableDictionary* d = [NSMutableDictionary new];
	[d setObject:types forKey:@"types"];
	[d setObject:format forKey:@"format"];
	
	return [NSDictionary dictionaryWithDictionary:d];
	
}

@end
