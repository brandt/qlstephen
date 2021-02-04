//
//  QLSFileMapping.h
//  QLStephen
//
//  Created by Mark Douma on 1/19/2021.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface QLSFileMapping : NSObject

@property (nonatomic, assign, getter=isEnabled) BOOL 		enabled;

@property (nonatomic, copy) 					NSString	*filenameExtension;

@property (nonatomic, copy) 					NSString	*kind;

@property (readonly, nonatomic, weak) NSDictionary *dictionaryRep; // for user defaults

@property (readonly, nonatomic, weak) NSDictionary *exportedTypeInfoPlistRep;	 // for dummy app Info.plist


+ (nullable instancetype)fileMappingWithURL:(NSURL *)URL error:(NSError **)outError;
- (nullable instancetype)initWithURL:(NSURL *)URL error:(NSError **)outError;

+ (instancetype)fileMappingWithDictionaryRep:(NSDictionary *)dictionaryRep;
- (instancetype)initWithDictionaryRep:(NSDictionary *)dictionaryRep;

+ (NSArray *)fileMappingsWithDictionaryReps:(NSArray *)dictionaryReps;
+ (NSArray *)dictionaryRepsOfFileMappingsInArray:(NSArray *)fileMappings;

@end

NS_ASSUME_NONNULL_END
