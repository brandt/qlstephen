//
//  QLSFileMapping.m
//  QLStephen
//
//  Created by Mark Douma on 1/19/2021.
//

#import "QLSFileMapping.h"

#define MD_DEBUG 0

#if MD_DEBUG
#define MDLog(...) NSLog(__VA_ARGS__)
#else
#define MDLog(...)
#endif

NS_ASSUME_NONNULL_BEGIN

static NSString * const QLSEnabledKey				= @"enabled";
static NSString * const QLSFilenameExtensionKey		= @"filenameExtension";
static NSString * const QLSKindKey					= @"kind";

NS_ASSUME_NONNULL_END


@implementation QLSFileMapping

+ (nullable instancetype)fileMappingWithURL:(NSURL *)URL error:(NSError **)outError {
	return [[[self class] alloc] initWithURL:URL error:outError];
}

- (nullable instancetype)initWithURL:(NSURL *)URL error:(NSError **)outError {
	if ((self = [super init])) {
		// FIXME: better error handling
		if (outError) *outError = nil;
		_filenameExtension = URL.pathExtension;
		if (_filenameExtension.length == 0) {
			// FIXME: better error handling
			return nil;
		}
		_kind = [NSString stringWithFormat:NSLocalizedString(@"%@ File", @""), _filenameExtension.capitalizedString];
		_enabled = YES;
	}
	return self;
}

- (instancetype)init {
	MDLog(@"[%@ %@]", NSStringFromClass([self class]), NSStringFromSelector(_cmd));
	if ((self = [super init])) {
		_enabled = YES;
		_filenameExtension = @"ext";
		_kind = @"Ext File";
	}
	return self;
}

+ (instancetype)fileMappingWithDictionaryRep:(NSDictionary *)dictionaryRep {
	return [[[self class] alloc] initWithDictionaryRep:dictionaryRep];
}

- (instancetype)initWithDictionaryRep:(NSDictionary *)dictionaryRep {
	if ((self = [super init])) {
		_enabled = [dictionaryRep[QLSEnabledKey] boolValue];
		_filenameExtension = dictionaryRep[QLSFilenameExtensionKey];
		_kind = dictionaryRep[QLSKindKey];
	}
	return self;
}

+ (NSArray *)fileMappingsWithDictionaryReps:(NSArray *)dictionaryReps {
	NSMutableArray *fileMappings = [NSMutableArray array];
	for (NSDictionary *dictionaryRep in dictionaryReps) {
		QLSFileMapping *fileMapping = [QLSFileMapping fileMappingWithDictionaryRep:dictionaryRep];
		if (fileMapping) [fileMappings addObject:fileMapping];
	}
	return fileMappings;
}

- (NSDictionary *)dictionaryRep {
	return @{ QLSEnabledKey: @(_enabled),
			  QLSFilenameExtensionKey: _filenameExtension,
			  QLSKindKey: _kind };
}

- (NSDictionary *)exportedTypeInfoPlistRep {
	// TODO: make sure UTI is a valid string
	return @{(__bridge NSString *)kUTTypeConformsToKey:@[(__bridge NSString *)kUTTypePlainText],
			 (__bridge NSString *)kUTTypeDescriptionKey: _kind,
			 (__bridge NSString *)kUTTypeIdentifierKey: [NSString stringWithFormat:@"com.whomwah.%@", _filenameExtension.lowercaseString],
			 (__bridge NSString *)kUTTypeTagSpecificationKey: @{ (__bridge NSString *)kUTTagClassFilenameExtension: @[_filenameExtension] }
	};
}

+ (NSArray *)dictionaryRepsOfFileMappingsInArray:(NSArray *)fileMappings {
	NSMutableArray *mDictionaryReps = [NSMutableArray array];
	for (QLSFileMapping *fileMapping in fileMappings) {
		[mDictionaryReps addObject:fileMapping.dictionaryRep];
	}
	return mDictionaryReps;
}

- (NSString *)description {
	NSMutableString *description = [NSMutableString stringWithFormat:@"%@", [super description]];
	[description appendFormat:@", filenameExtension == %@", _filenameExtension];
	[description appendFormat:@", isEnabled == %@", (_enabled ? @"YES" : @"NO")];
	[description appendFormat:@", kind == %@", _kind];
	return description;
}

@end
