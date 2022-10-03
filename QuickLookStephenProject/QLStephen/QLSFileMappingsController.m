//
//  QLSFileMappingsController.m
//  QLStephen
//
//  Created by Mark Douma on 1/20/2021.
//

#import "QLSFileMappingsController.h"

#define MD_DEBUG 0

#if MD_DEBUG
#define MDLog(...) NSLog(__VA_ARGS__)
#else
#define MDLog(...)
#endif

static NSString * const QLSShowRemoveAlertKey	= @"QLSShowRemoveAlert";

@implementation QLSFileMappingsController

+ (void)initialize {
	/* dispatch_once() is used here to guard against the rare cases where Cocoa bindings
	 may cause `+initialize` to be called twice: once for this class, and once for the isa-swizzled class:
	 `[NSKVONotifying_MDClassName initialize]`
	 */
	static dispatch_once_t onceToken = 0;
	dispatch_once(&onceToken, ^{
		NSMutableDictionary *defaults = [NSMutableDictionary dictionary];
		[defaults setObject:@YES forKey:QLSShowRemoveAlertKey];
		[NSUserDefaults.standardUserDefaults registerDefaults:defaults];
		[NSUserDefaultsController.sharedUserDefaultsController setInitialValues:defaults];
	});
}

- (void)remove:(id)sender {
	MDLog(@"[%@ %@]", NSStringFromClass([self class]), NSStringFromSelector(_cmd));
	if ([[NSUserDefaults.standardUserDefaults objectForKey:QLSShowRemoveAlertKey] boolValue]) {
		NSAlert *alert = [[NSAlert alloc] init];
		alert.messageText = (self.selectionIndexes.count == 1 ? NSLocalizedString(@"Are you sure you want to remove the selected file mapping?", @"") : NSLocalizedString(@"Are you sure you want to remove the selected file mappings?", @""));
		alert.informativeText = NSLocalizedString(@"This cannot be undone.", @"");
		[alert addButtonWithTitle:NSLocalizedString(@"Remove", @"")];
		[alert addButtonWithTitle:NSLocalizedString(@"Cancel", @"")];
		alert.showsSuppressionButton = YES;
		[alert beginSheetModalForWindow:NSApp.mainWindow completionHandler:^(NSModalResponse returnCode) {
			if (returnCode == NSAlertFirstButtonReturn) {
				if (alert.suppressionButton.state == NSOnState) {
					[NSUserDefaults.standardUserDefaults setObject:@NO forKey:QLSShowRemoveAlertKey];
				}
				[super remove:sender];
			}
		}];
	} else {
		[super remove:sender];
	}
}

- (IBAction)resetWarnings:(id)sender {
	[NSUserDefaults.standardUserDefaults removeObjectForKey:QLSShowRemoveAlertKey];
}

@end
