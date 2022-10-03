//
//  QLSFilenameExtensionFormatter.m
//  QLStephen
//
//  Created by Mark Douma on 1/23/2021.
//

#import "QLSFilenameExtensionFormatter.h"

@implementation QLSFilenameExtensionFormatter

- (NSString *)stringForObjectValue:(id)obj {
	return  obj;
}

- (BOOL)getObjectValue:(id *)obj forString:(NSString *)string errorDescription:(NSString **)errorDescription {
	if (obj == nil) return NO;
	*obj = string.lowercaseString;
	return YES;
}

- (BOOL)isPartialStringValid:(NSString **)partialStringPtr proposedSelectedRange:(NSRangePointer)proposedSelRangePtr originalString:(NSString *)origString originalSelectedRange:(NSRange)origSelRange errorDescription:(NSString **)errorDescription {
	if (partialStringPtr == nil) return NO;
	if ([*partialStringPtr rangeOfString:@"."].location == NSNotFound) {
		return YES;
	} else {
		if (errorDescription) *errorDescription = NSLocalizedString(@"Filename extensions cannot contain a period.", @"");
		return NO;
	}
}

@end
