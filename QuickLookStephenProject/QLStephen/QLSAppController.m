//
//  QLSAppController.m
//  QLStephen
//
//  Created by Mark Douma on 1/19/2021.
//

#import "QLSAppController.h"
#import "QLSFileMapping.h"
#import "QLSFileAttributes.h"
#import "QLSFileMappingsController.h"
#import <CoreServices/CoreServices.h>
#import <Security/Security.h>

#define MD_DEBUG 0

#if MD_DEBUG
#define MDLog(...) NSLog(__VA_ARGS__)
#else
#define MDLog(...)
#endif

NS_ASSUME_NONNULL_BEGIN

@interface QLSAppController ()

@property (nonatomic, strong) NSMutableSet 			*filenameExtensions;

@property (nonatomic, strong) NSMutableDictionary 	*filenameExtensionsToMappings;

- (void)addItemsAtURLs:(NSArray *)URLs;

// FIXME: find a better way than this?
// FIXME: this is in an attempt to try to get the textfield for newly created file extension to immediately start editing
@property (nonatomic, assign) BOOL 		editing;
@property (nonatomic, assign) NSInteger editingRow;

@end

NS_ASSUME_NONNULL_END

static NSString * const QLSSortDescriptorsKey		= @"QLSSortDescriptors";
static NSString * const QLSFileMappingsKey			= @"QLSFileMappings";
static NSString * const QLSDummyAppURLStringKey		= @"QLSDummyAppURLString";
static NSString * const QLSDummyAppBookmarkDataKey	= @"QLSDummyAppBookmarkData";

// FIXME: allow for sudden termination but still save results

static const NSUInteger obsContext = 11;

enum {
	QLSTagEnable 	= 1,
	QLSTagDisable 	= 2,
};

#define QLSAllIndexes [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, _fileMappings.count)]
#define QLSOldAndNew NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld

@implementation QLSAppController

+ (void)initialize {
	/* dispatch_once() is used here to guard against the rare cases where Cocoa bindings
	 may cause `+initialize` to be called twice: once for this class, and once for the isa-swizzled class:
	 `[NSKVONotifying_MDClassName initialize]`
	 */
	static dispatch_once_t onceToken = 0;
	dispatch_once(&onceToken, ^{
		NSMutableDictionary *defaults = [NSMutableDictionary dictionary];
		[defaults setObject:@[] forKey:QLSFileMappingsKey];
		NSArray *sortDescriptors = @[[[NSSortDescriptor alloc] initWithKey:@"filenameExtension" ascending:YES selector:@selector(localizedStandardCompare:)]];
		NSData *data = [NSKeyedArchiver archivedDataWithRootObject:sortDescriptors];
		if (data) [defaults setObject:data forKey:QLSSortDescriptorsKey];
		[NSUserDefaults.standardUserDefaults registerDefaults:defaults];
		[NSUserDefaultsController.sharedUserDefaultsController setInitialValues:defaults];
	});
}

- (instancetype)init {
	if ((self = [super init])) {
		_filenameExtensionsToMappings = [[NSMutableDictionary alloc] init];
		_fileMappings = [[QLSFileMapping fileMappingsWithDictionaryReps:[NSUserDefaults.standardUserDefaults objectForKey:QLSFileMappingsKey]] mutableCopy];
		if (_fileMappings.count) {
			[_fileMappings addObserver:self toObjectsAtIndexes:QLSAllIndexes forKeyPath:@"filenameExtension" options:QLSOldAndNew context:(void *)&obsContext];
			[_fileMappings addObserver:self toObjectsAtIndexes:QLSAllIndexes forKeyPath:@"enabled" options:QLSOldAndNew context:(void *)&obsContext];
			[_fileMappings addObserver:self toObjectsAtIndexes:QLSAllIndexes forKeyPath:@"kind" options:QLSOldAndNew context:(void *)&obsContext];
			for (QLSFileMapping *fileMapping in _fileMappings) {
				[_filenameExtensionsToMappings setObject:fileMapping forKey:fileMapping.filenameExtension];
			}
		}
		[self addObserver:self forKeyPath:@"fileMappings" options:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld context:(void *)&obsContext];
	}
	return self;
}

- (void)dealloc {
	[self removeObserver:self forKeyPath:@"fileMappings"];
	[_fileMappings removeObserver:self fromObjectsAtIndexes:QLSAllIndexes forKeyPath:@"filenameExtension"];
	[_fileMappings removeObserver:self fromObjectsAtIndexes:QLSAllIndexes forKeyPath:@"enabled"];
	[_fileMappings removeObserver:self fromObjectsAtIndexes:QLSAllIndexes forKeyPath:@"kind"];
}

#pragma mark - <NSApplicationDelegate>
- (void)applicationWillFinishLaunching:(NSNotification *)notification {
	MDLog(@"[%@ %@]", NSStringFromClass([self class]), NSStringFromSelector(_cmd));
	[self updateDummyAppStatus];
	[self updateUI];
	_fileMappingsController.sortDescriptors = [NSKeyedUnarchiver unarchiveObjectWithData:[NSUserDefaults.standardUserDefaults objectForKey:QLSSortDescriptorsKey]];
	[_tableView registerForDraggedTypes:@[(NSString *)kUTTypeFileURL]];
	[_progressIndicator setUsesThreadedAnimation:YES];
}

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
	MDLog(@"[%@ %@]", NSStringFromClass([self class]), NSStringFromSelector(_cmd));
	[NSApp setServicesProvider:self];
}

- (void)applicationWillTerminate:(NSNotification *)notification {
	MDLog(@"[%@ %@]", NSStringFromClass([self class]), NSStringFromSelector(_cmd));
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender {
	MDLog(@"[%@ %@]", NSStringFromClass([self class]), NSStringFromSelector(_cmd));
	return YES;
}

- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender {
	MDLog(@"[%@ %@]", NSStringFromClass([self class]), NSStringFromSelector(_cmd));
	if (_dummyAppStatus == QLSDummyAppStatusUpdateNeeded) {
		// If we need to update the dummy app, wait a bit to finish doing so before terminating
		return NSTerminateLater;
	}
	return NSTerminateNow;
}

#pragma mark - <NSWindowDelegate>
- (void)windowWillClose:(NSNotification *)notification {
	MDLog(@"[%@ %@]", NSStringFromClass([self class]), NSStringFromSelector(_cmd));
	if (_dummyAppStatus == QLSDummyAppStatusUpdateNeeded) {
		[self createUpdateDummyApp:self];
	}
	[NSUserDefaults.standardUserDefaults setObject:[QLSFileMapping dictionaryRepsOfFileMappingsInArray:_fileMappings] forKey:QLSFileMappingsKey];
	[NSUserDefaults.standardUserDefaults setObject:[NSKeyedArchiver archivedDataWithRootObject:_fileMappingsController.sortDescriptors] forKey:QLSSortDescriptorsKey];
}

#pragma mark -
- (void)updateDummyAppStatus {
	_dummyAppStatus = QLSDummyAppStatusNotInstalled;
	if (_dummyAppURL == nil) {
		// set directly to avoid triggering key-value observing if dummy app doesn't actually exist yet
		_dummyAppURL = [[NSFileManager.defaultManager URLForDirectory:NSApplicationDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:YES error:NULL] URLByAppendingPathComponent:@"QLStephen Dummy.app"];
		// avoid using NSBundle's capability to find items, since it can cache stale information
		_dummyAppInfoPlistURL = [_dummyAppURL URLByAppendingPathComponent:@"Contents/Info.plist"];
	}
	if (! [_dummyAppURL checkResourceIsReachableAndReturnError:NULL]) {
		return;
	}
	_dummyAppStatus = QLSDummyAppStatusInstalled;
	// Only have the path control show URL if the dummy app is actually installed;
	// if it is installed, force key value observing to be triggered for the path control:
	self.dummyAppURL = _dummyAppURL;
}

- (void)updateUI {
	MDLog(@"[%@ %@]", NSStringFromClass([self class]), NSStringFromSelector(_cmd));
	_revealInFinderButton.enabled = (_dummyAppStatus != QLSDummyAppStatusNotInstalled) && [_dummyAppURL checkResourceIsReachableAndReturnError:NULL];
	_createUpdateButton.title = (_dummyAppStatus == QLSDummyAppStatusNotInstalled ? NSLocalizedString(@"Create Dummy App", @"") : NSLocalizedString(@"Update Dummy App", @""));
	_createUpdateButton.enabled = (_dummyAppStatus != QLSDummyAppStatusInstalled);
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context {
	MDLog(@"[%@ %@] keyPath == %@, object == %@, change == %@", NSStringFromClass([self class]), NSStringFromSelector(_cmd), keyPath, object, change);
	if (context != (void *)&obsContext) {
		if ([super respondsToSelector:@selector(observeValueForKeyPath:ofObject:change:context:)]) {
			return [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
		}
	}
	// this is primarily to do detect changes that should enable the "Create/Update Dummy App" button
	if ([keyPath isEqualToString:@"fileMappings"]) {
		NSKeyValueChange changeKind = [change[NSKeyValueChangeKindKey] unsignedIntegerValue];
		if (changeKind == NSKeyValueChangeInsertion) {
			NSArray *fileMappings = change[NSKeyValueChangeNewKey];
			for (QLSFileMapping *fileMapping in fileMappings) {
				[fileMapping addObserver:self forKeyPath:@"filenameExtension" options:QLSOldAndNew context:(void *)&obsContext];
				[fileMapping addObserver:self forKeyPath:@"enabled" options:QLSOldAndNew context:(void *)&obsContext];
				[fileMapping addObserver:self forKeyPath:@"kind" options:QLSOldAndNew context:(void *)&obsContext];
			}
			if (fileMappings.count) {
				// FIXME: find a better way?
				NSIndexSet *addedIndexes = change[NSKeyValueChangeIndexesKey];
				self.editing = YES;
				self.editingRow = addedIndexes.firstIndex;
			}
		} else {
			NSArray *fileMappings = change[NSKeyValueChangeOldKey];
			for (QLSFileMapping *fileMapping in fileMappings) {
				[fileMapping removeObserver:self forKeyPath:@"filenameExtension"];
				[fileMapping removeObserver:self forKeyPath:@"enabled"];
				[fileMapping removeObserver:self forKeyPath:@"kind"];
			}
		}
	} else if ([keyPath isEqualToString:@"filenameExtension"]) {
		NSKeyValueChange changeKind = [change[NSKeyValueChangeKindKey] unsignedIntegerValue];
		if (changeKind == NSKeyValueChangeSetting) {
			[_filenameExtensionsToMappings removeObjectForKey:change[NSKeyValueChangeOldKey]];
			[_filenameExtensionsToMappings setObject:object forKey:change[NSKeyValueChangeNewKey]];
		}
	}
	
	if (_dummyAppStatus == QLSDummyAppStatusInstalled) {
		_dummyAppStatus = QLSDummyAppStatusUpdateNeeded;
		[self updateUI];
	}
}

#pragma mark -
- (void)addItemsAtURLs:(NSArray *)URLs {
	NSMutableArray *mFailures = [NSMutableArray array];
	NSMutableArray *mFileMappings = [NSMutableArray array];
	NSError *error = nil;
	for (NSURL *URL in URLs) {
		// ignore attempts to add invalid item types (directories, files with no filename extension)
		// ignore attempts to add duplicates of existing filename extensions
		NSNumber *isDir = nil;
		if (URL.pathExtension.length == 0 ||
			([URL getResourceValue:&isDir forKey:NSURLIsDirectoryKey error:NULL] && isDir.boolValue) ||
			_filenameExtensionsToMappings[URL.pathExtension] != nil) {
			continue;
		}
		if (! [QLSFileAttributes attributesForItemAtURL:URL].isTextFile) {
			[mFailures addObject:URL];
			continue;
		}
		QLSFileMapping *fileMapping = [QLSFileMapping fileMappingWithURL:URL error:&error];
		if (fileMapping) [mFileMappings addObject:fileMapping];
	}
	if (mFailures.count) {
		NSString *messageText = nil;
		if (mFailures.count == 1) {
			messageText = [NSString stringWithFormat:NSLocalizedString(@"The “%@” file could not be added because it is not a text-based document.", @""), [[mFailures objectAtIndex:0] lastPathComponent]];
		} else {
			if (mFailures.count < URLs.count) {
				messageText = [NSString stringWithFormat:NSLocalizedString(@"%@ of %@ items could not be added because they are not text-based documents.", @""), @(mFailures.count), @(URLs.count)];
			} else {
				messageText = [NSString stringWithFormat:NSLocalizedString(@"%@ items could not be added because they are not text-based documents.", @""), @(mFailures.count)];
			}
		}
		NSAlert *alert = [[NSAlert alloc] init];
		alert.messageText = messageText;
		[alert addButtonWithTitle:NSLocalizedString(@"OK", @"")];
		[alert beginSheetModalForWindow:_window completionHandler:^(NSModalResponse returnCode) { return; }];
	}
	[_fileMappingsController addObjects:mFileMappings];
}

#pragma mark - Service call:
- (void)previewTextFiles:(NSPasteboard *)pboard userData:(NSString *)data error:(NSString **)errorString {
	MDLog(@"[%@ %@]", NSStringFromClass([self class]), NSStringFromSelector(_cmd));
	NSArray *URLs = [pboard readObjectsForClasses:@[[NSURL class]] options:@{NSPasteboardURLReadingFileURLsOnlyKey: @YES}];
	if (errorString) *errorString = nil;
	if (! URLs.count) return;
	[self addItemsAtURLs:URLs];
}

#pragma mark - <NSTableViewDataSource>
- (NSDragOperation)tableView:(NSTableView *)tableView validateDrop:(id <NSDraggingInfo>)draggingInfo proposedRow:(NSInteger)row proposedDropOperation:(NSTableViewDropOperation)dropOperation {
	[draggingInfo setDraggingFormation:NSDraggingFormationList]; // ??
	NSArray *URLs = [draggingInfo.draggingPasteboard readObjectsForClasses:@[[NSURL class]] options:@{NSPasteboardURLReadingFileURLsOnlyKey: @YES}];
	[_tableView setDropRow:-1 dropOperation:NSTableViewDropOn];
	NSArray *acceptableURLs = [URLs objectsAtIndexes:[URLs indexesOfObjectsPassingTest:^BOOL(id obj, NSUInteger idx, BOOL *stop) {
		return [(NSURL *)obj pathExtension].length && ! [[NSSet setWithArray:_filenameExtensionsToMappings.allKeys] containsObject:[(NSURL *)obj pathExtension].lowercaseString];
	}]];
	return (acceptableURLs.count == 0 ? NSDragOperationNone : NSDragOperationEvery);
}

- (BOOL)tableView:(NSTableView *)tableView acceptDrop:(id <NSDraggingInfo>)draggingInfo row:(NSInteger)row dropOperation:(NSTableViewDropOperation)dropOperation {
	NSArray *URLs = [draggingInfo.draggingPasteboard readObjectsForClasses:@[[NSURL class]] options:@{NSPasteboardURLReadingFileURLsOnlyKey: @YES}];
	[self performSelector:@selector(addItemsAtURLs:) withObject:URLs afterDelay:0];
	return YES;
}

#pragma mark - <NSTableViewDelegate>
- (void)tableViewSelectionDidChange:(NSNotification *)notification {
//	MDLog(@"[%@ %@]", NSStringFromClass([self class]), NSStringFromSelector(_cmd));
	if (_editing) {
		MDLog(@"[%@ %@] we're editing", NSStringFromClass([self class]), NSStringFromSelector(_cmd));
		_editing = NO;
		NSInteger columnIndex = [_tableView columnWithIdentifier:@"filenameExtension"];
		NSView *view = [_tableView viewAtColumn:columnIndex row:_editingRow makeIfNecessary:YES];
//		MDLog(@"[%@ %@] view == %@", NSStringFromClass([self class]), NSStringFromSelector(_cmd), view);
		// FIXME: cannot seem to get the filename extension textfield to immediately start editing
		[_window makeFirstResponder:[(NSTableCellView *)view textField]];
//		[_tableView editColumn:columnIndex row:_editingRow withEvent:nil select:YES];
	}
}

#pragma mark - <NSTextFieldDelegate>
- (void)control:(NSControl *)control didFailToValidatePartialString:(NSString *)string errorDescription:(nullable NSString *)errorDescription {
	NSAlert *alert = [[NSAlert alloc] init];
	if (errorDescription) alert.messageText = errorDescription;
	[alert addButtonWithTitle:NSLocalizedString(@"OK", @"")];
	[alert beginSheetModalForWindow:_window completionHandler:^(NSModalResponse returnCode) { return; }];
}

- (BOOL)control:(NSControl *)control textShouldEndEditing:(NSText *)fieldEditor {
	MDLog(@"[%@ %@]", NSStringFromClass([self class]), NSStringFromSelector(_cmd));
	QLSFileMapping *editedMapping = _fileMappingsController.selectedObjects.lastObject;
	// Only allow editing to finish if no other fileMapping (except possibly the one we're editing) has the newly edited filenameExtension
	// Also, make sure the filename extension is not an empty string
	if ((_filenameExtensionsToMappings[fieldEditor.string.lowercaseString] == editedMapping ||
		 _filenameExtensionsToMappings[fieldEditor.string.lowercaseString] == nil) &&
		fieldEditor.string.length) {
		return YES;
	}
	NSAlert *alert = [[NSAlert alloc] init];
	if (fieldEditor.string.length == 0) {
		alert.messageText = NSLocalizedString(@"Filename extensions must have at least one character.", @"");
	} else {
		alert.messageText = [NSString stringWithFormat:NSLocalizedString(@"You already have a mapping for the “%@” filename extension.", @""), fieldEditor.string.lowercaseString];
	}
	[alert addButtonWithTitle:NSLocalizedString(@"OK", @"")];
	[alert beginSheetModalForWindow:_window completionHandler:^(NSModalResponse returnCode) { return; }];
	return NO;
}

#pragma mark -
- (IBAction)toggleEnabled:(id)sender {
	MDLog(@"[%@ %@]", NSStringFromClass([self class]), NSStringFromSelector(_cmd));
	NSInteger tag = [sender tag];
	for (QLSFileMapping *mapping in _fileMappingsController.selectedObjects) {
		mapping.enabled = (tag == QLSTagEnable);
	}
}

- (BOOL)createDummyAppAndReturnError:(NSError **)outError {
	if (outError) *outError = nil;
	NSURL *ourDummyAppURL = [NSBundle.mainBundle URLForResource:@"QLStephen Dummy" withExtension:@"app"];
	if (ourDummyAppURL == nil) {
		// FIXME: handle this error
		return NO;
	}
	return [NSFileManager.defaultManager copyItemAtURL:ourDummyAppURL toURL:_dummyAppURL error:outError];
}

- (BOOL)updateDummyAppAndReturnError:(NSError **)outError {
	if (outError) *outError = nil;
	NSMutableDictionary *mInfoPlist = [NSMutableDictionary dictionaryWithContentsOfURL:_dummyAppInfoPlistURL];
	if (mInfoPlist == nil) {
		// FIXME: better error handling
		return NO;;
	}
	// FIXME: avoid allowing duplicates in the UI
	NSArray *enabledMappings = [_fileMappings objectsAtIndexes:[_fileMappings indexesOfObjectsPassingTest:^BOOL(id obj, NSUInteger idx, BOOL *stop) {
		return [(QLSFileMapping *)obj isEnabled];
	}]];
	NSMutableArray *mEntries = [NSMutableArray array];
	for (QLSFileMapping *mapping in enabledMappings) {
		[mEntries addObject:mapping.exportedTypeInfoPlistRep];
	}
	[mInfoPlist setObject:mEntries forKey:(id)kUTExportedTypeDeclarationsKey];
	if (! [mInfoPlist writeToURL:_dummyAppInfoPlistURL atomically:NO]) {
		// FIXME: better error handling
		return NO;
	}
	return YES;
}

// TODO: allow choosing developer identity from keychain?
- (BOOL)codesignDummyAppAndReturnError:(NSError **)outError {
	if (outError) *outError = nil;
	// FIXME: make sure they actually have /usr/bin/codesign available (is it installed by default w/o having dev tools?)
	NSTask *task = [[NSTask alloc] init];
	task.launchPath = @"/usr/bin/codesign";
	task.arguments = @[@"-f", @"--sign", @"-", @"--deep", _dummyAppURL.path];
	task.standardOutput = [NSPipe pipe];
	task.standardError = [NSPipe pipe];
	[task launch];
	NSData *stdOutData = [[[task standardOutput] fileHandleForReading] readDataToEndOfFile];
	if (stdOutData.length) {
		NSString *string = [[NSString alloc] initWithData:stdOutData encoding:NSUTF8StringEncoding];
		NSLog(@"%@", string);
	}
	NSString *errorString = nil;
	NSData *stdErrorData = [[[task standardError] fileHandleForReading] readDataToEndOfFile];
	if (stdErrorData.length) {
		errorString = [[NSString alloc] initWithData:stdErrorData encoding:NSUTF8StringEncoding];
		NSLog(@"%@", errorString);
	}
	[task waitUntilExit];
	
	if (! task.isRunning) {
		int status = task.terminationStatus;
		if (status) {
			if (outError) *outError = [NSError errorWithDomain:NSPOSIXErrorDomain code:status userInfo:nil];
			return NO;
		}
	}
	// touch bundle
	if (! [_dummyAppURL setResourceValue:[NSDate date] forKey:NSURLContentModificationDateKey error:outError]) {
		return NO;
	}
	// force LaunchServices to re-examine claimed file types
	OSStatus status = LSRegisterURL((__bridge CFURLRef)_dummyAppURL, YES);
	if (status) {
		if (outError) *outError = [NSError errorWithDomain:NSOSStatusErrorDomain code:status userInfo:nil];
		return NO;
	}
	return YES;
}

- (IBAction)createUpdateDummyApp:(id)sender {
	MDLog(@"[%@ %@]", NSStringFromClass([self class]), NSStringFromSelector(_cmd));
	[_progressIndicator startAnimation:nil];
	_progressField.stringValue = (_dummyAppStatus == QLSDummyAppStatusNotInstalled ? NSLocalizedString(@"Creating Dummy App…", @"") : NSLocalizedString(@"Updating Dummy App…", @""));
	// Since this method can be called automatically at app termination time, we need to make sure
	// that the app doesn't terminate before the async block has had time to run, otherwise the
	// dummy app won't be properly updated.
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
		NSError *error = nil;
		BOOL success = YES;
		if (self.dummyAppStatus == QLSDummyAppStatusNotInstalled) {
			success = [self createDummyAppAndReturnError:&error];
		}
		if (success && (self.dummyAppStatus == QLSDummyAppStatusNotInstalled || self.dummyAppStatus == QLSDummyAppStatusUpdateNeeded)) {
			success = [self updateDummyAppAndReturnError:&error];
			if (success) [self codesignDummyAppAndReturnError:&error];
		}
		dispatch_async(dispatch_get_main_queue(), ^{
			if (! success) {
				NSLog(@"[%@ %@] failed to install/update/codesign app; error == %@", NSStringFromClass([self class]), NSStringFromSelector(_cmd), error);
				return;
			}
			[self updateDummyAppStatus];
			[self updateUI];
			[self.progressIndicator stopAnimation:nil];
			[self.progressField setStringValue:@""];
			if (sender == self) {
				// continue with app termination
				[NSApp replyToApplicationShouldTerminate:YES];
			}
		});
	});
}

- (IBAction)revealInFinder:(id)sender {
	if (_dummyAppURL) [NSWorkspace.sharedWorkspace activateFileViewerSelectingURLs:@[_dummyAppURL]];
}

#pragma mark - <NSMenuDelegate>
- (BOOL)validateMenuItem:(NSMenuItem *)menuItem {
	SEL action = menuItem.action;
	if (action == @selector(toggleEnabled:)) {
		NSArray *selectedObjects = _fileMappingsController.selectedObjects;
		if (selectedObjects.count == 0) {
			menuItem.title = NSLocalizedString(@"Disable", @"");
			menuItem.tag = QLSTagDisable;
		} else if (selectedObjects.count == 1) {
			QLSFileMapping *fileMapping = [selectedObjects objectAtIndex:0];
			menuItem.title = [NSString stringWithFormat:(fileMapping.isEnabled ? NSLocalizedString(@"Disable “%@”", @"") : NSLocalizedString(@"Enable “%@”", @"")), fileMapping.filenameExtension];
			menuItem.tag = (fileMapping.isEnabled ? QLSTagDisable : QLSTagEnable);
		} else {
			NSUInteger enabledCount = [[selectedObjects indexesOfObjectsPassingTest:^BOOL(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
				return [(QLSFileMapping *)obj isEnabled];
			}] count];
			NSUInteger disabledCount = selectedObjects.count - enabledCount;
			if (enabledCount > disabledCount) {
				menuItem.title = [NSString stringWithFormat:NSLocalizedString(@"Disable %@ items", @""), @(selectedObjects.count)];
				menuItem.tag = QLSTagDisable;
			} else {
				menuItem.title = [NSString stringWithFormat:NSLocalizedString(@"Enable %@ items", @""), @(selectedObjects.count)];
				menuItem.tag = QLSTagEnable;
			}
		}
		return _fileMappingsController.selectionIndexes.count > 0;
	}
	return YES;
}

@end
