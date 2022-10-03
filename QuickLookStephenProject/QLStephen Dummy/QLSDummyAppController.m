//
//  QLSDummyAppController.m
//  QLStephen Dummy
//
//  Created by Mark Douma on 1/19/2021.
//

#import "QLSDummyAppController.h"

@implementation QLSDummyAppController

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
	NSAlert *alert = [[NSAlert alloc] init];
	// FIXME: better wording?
	alert.messageText = NSLocalizedString(@"This is a dummy app that you’re not really supposed to run.", @"");
	alert.informativeText = NSLocalizedString(@"Its sole purpose is to declare that certain file extensions are text, thereby allowing the QLStephen.qlgenerator to preview those files.", @"");
	[alert addButtonWithTitle:NSLocalizedString(@"Quit", @"")];
	[alert runModal];
	[NSApp terminate:nil];
}

@end
