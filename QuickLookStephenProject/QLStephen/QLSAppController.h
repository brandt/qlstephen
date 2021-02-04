//
//  QLSAppController.h
//  QLStephen
//
//  Created by Mark Douma on 1/19/2021.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@class QLSFileMappingsController;

typedef NS_ENUM(NSUInteger, QLSDummyAppStatus) {
	QLSDummyAppStatusNotInstalled	= 0,
	QLSDummyAppStatusInstalled		= 1,
	QLSDummyAppStatusUpdateNeeded	= 2,
};

@interface QLSAppController : NSObject <NSApplicationDelegate, NSTableViewDelegate, NSTableViewDataSource, NSMenuDelegate, NSWindowDelegate, NSTextFieldDelegate>

@property (strong) IBOutlet NSWindow 				*window;
@property (weak) IBOutlet NSTableView 				*tableView;
@property (weak) IBOutlet QLSFileMappingsController *fileMappingsController;
@property (weak) IBOutlet NSButton 					*revealInFinderButton;
@property (weak) IBOutlet NSButton 					*createUpdateButton;

@property (weak) IBOutlet NSTextField 				*progressField;
@property (weak) IBOutlet NSProgressIndicator 		*progressIndicator;

@property (nonatomic, strong) NSMutableArray 		*fileMappings;

@property (assign) 			  QLSDummyAppStatus 	dummyAppStatus;
@property (nonatomic, strong, nullable) NSURL		*dummyAppURL;
@property (nonatomic, strong, nullable) NSURL		*dummyAppInfoPlistURL;


- (IBAction)revealInFinder:(id)sender;
- (IBAction)createUpdateDummyApp:(id)sender;
- (IBAction)toggleEnabled:(id)sender;

@end

NS_ASSUME_NONNULL_END
