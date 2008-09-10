//
//  BDocument.m
//  BDocuments
//
//  Created by Jesse Grosjean on 10/16/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import "BDocument.h"
#import "BDocuments.h"
#import "BDocumentWindowController.h"


@implementation BDocument

+ (void)initialize {
	[[NSUserDefaults standardUserDefaults] registerDefaults:[NSDictionary dictionaryWithObjectsAndKeys:
		nil]];
}

#pragma mark Document Defaults Repository

static NSMutableArray *documentUserDefautlsArchive = nil;

+ (NSString *)documentUserDefaultsArchivePath {
	return [[[NSFileManager defaultManager] processesApplicationSupportFolder] stringByAppendingPathComponent:@"DocumentsUserDefaults.archive"];
}

+ (NSMutableArray *)documentUserDefautlsArchive {
	if (!documentUserDefautlsArchive) {
		documentUserDefautlsArchive = [NSUnarchiver unarchiveObjectWithFile:[self documentUserDefaultsArchivePath]];
		if (!documentUserDefautlsArchive) {
			documentUserDefautlsArchive = [[NSMutableArray alloc] init];
		}
	}
	return documentUserDefautlsArchive;
}

+ (NSDictionary *)loadDocumentUserDefaultsForDocumentURL:(NSURL *)documentURL {
	NSDictionary *documentUserDefaults = [[[self documentUserDefautlsArchive] filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"BDocumentsDocumentURL = %@", [documentURL path]]] lastObject];
	if (!documentUserDefaults) {
		documentUserDefaults = [NSDictionary dictionary];
	}
	return documentUserDefaults;
}

+ (BOOL)storeDocumentUserDefaults:(NSDictionary *)documentUserDefaults forDocumentURL:(NSURL *)documentURL {
	if (!documentURL) return NO;
	if (!documentUserDefaults) return NO;
	
	NSDictionary *oldDocumentUserDefaults = [[[self documentUserDefautlsArchive] filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"BDocumentsDocumentURL = %@", [documentURL path]]] lastObject];
	if (oldDocumentUserDefaults) {
		[documentUserDefautlsArchive removeObject:oldDocumentUserDefaults];
	}
	
	NSMutableDictionary *newDocumentUserDefaults = [documentUserDefaults mutableCopy];
	[newDocumentUserDefaults setObject:[documentURL path] forKey:@"BDocumentsDocumentURL"];
	[documentUserDefautlsArchive addObject:newDocumentUserDefaults];
	
	return YES;
}

+ (BOOL)synchronizeDocumentUserDefaultsRepository {
	[[NSNotificationCenter defaultCenter] postNotificationName:BDocumentUserDefaultsWillSynchronizeNotification object:self];
	
	NSInteger count = [[self documentUserDefautlsArchive] count];
	NSInteger max = 100;
	
	if (count > max) {
		[documentUserDefautlsArchive removeObjectsInRange:NSMakeRange(0, count - max)]; // keep newer user infos at end of array
	}
	
	if (![NSArchiver archiveRootObject:documentUserDefautlsArchive toFile:[self documentUserDefaultsArchivePath]]) {
		BLogWarning(@"failed to save documentUserDefautlsArchive");
		return NO;
	}
	
	[[NSNotificationCenter defaultCenter] postNotificationName:BDocumentUserDefaultsDidSynchronizeNotification object:self];
	
	return YES;
}

#pragma mark awakeFromNib-like methods

- (void)makeWindowControllers {
	// First make sure to load plugins containing all window controller factories so that NSClassFromString(className) will work bellow for saved window controllers.
	for (BPlugin *each in [[[BExtensionRegistry sharedInstance] configurationElementsFor:@"com.blocks.BDocuments.documentDefaultWindowControllersFactory"] valueForKey:@"plugin"]) {
		NSError *error = nil;
		if (![each loadAndReturnError:&error]) {
			[NSApp presentError:error];
		}
	}

	NSDictionary *documentWindowControllersState = [self documentUserDefaultForKey:BDocumentsWindowControllersDefaultsKey];
	
	for (NSString *eachKey in [documentWindowControllersState keyEnumerator]) {
		NSDictionary *windowControllerState = [documentWindowControllersState objectForKey:eachKey];
		NSString *className = [windowControllerState objectForKey:@"class"];
		if (className) {
			Class class = NSClassFromString(className);
			NSWindowController *windowController = [[class alloc] initWithWindowControllerUserDefaultsKey:eachKey];
			if (windowController) {
				[self addWindowController:windowController];
			}
		}
	}
	
	if ([[self windowControllers] count] == 0) {
		for (BConfigurationElement *each in [[BExtensionRegistry sharedInstance] configurationElementsFor:@"com.blocks.BDocuments.documentDefaultWindowControllersFactory"]) {
			id <BDocumentWindowControllerFactory> windowControllerFactory = [each createExecutableExtensionFromAttribute:@"factory" conformingToClass:nil conformingToProtocol:@protocol(BDocumentWindowControllerFactory) respondingToSelectors:nil];
			NSWindowController *windowController = [windowControllerFactory createDocumentWindowControllerForDocument:self];
			if (windowController) {
				[self addWindowController:windowController];
			}
		}
	}
}

- (void)removeWindowController:(BDocumentWindowController *)windowController {
	NSMutableDictionary *documentWindowControllersState = [self documentUserDefaultForKey:BDocumentsWindowControllersDefaultsKey];
	if ([documentWindowControllersState count] > 1) {
		[documentWindowControllersState removeObjectForKey:[windowController windowControllerUserDefaultsKey]];
	}
	[super removeWindowController:windowController];
}

#pragma mark Printing

- (NSPrintOperation *)printOperationWithSettings:(NSDictionary *)printSettings error:(NSError **)outError {
    if ([[self windowControllers] count] == 0) [self makeWindowControllers];
	
	id windowController = [[self windowControllers] lastObject];
	
	if ([windowController respondsToSelector:@selector(printOperationWithSettings:error:)]) {
		return [windowController printOperationWithSettings:printSettings error:outError];
	}
	
	return nil;
}

#pragma mark Document User Defaults

- (NSDictionary *)defaultDocumentUserDefaults {
	return [NSDictionary dictionary];
}

- (NSDictionary *)documentUserDefaults {
	if (!documentUserDefaults) {
		documentUserDefaults = [[self defaultDocumentUserDefaults] mutableCopy];
	}
	return documentUserDefaults;
}

- (id)documentUserDefaultForKey:(NSString *)key {
	return [[self documentUserDefaults] objectForKey:key];
}

- (void)setDocumentUserDefault:(id)documentUserDefault forKey:(NSString *)key {
	if (documentUserDefault) {
		if ([documentUserDefault conformsToProtocol:@protocol(NSCoding)]) {
			[(id)[self documentUserDefaults] setObject:documentUserDefault forKey:key];
		} else {
			BLogWarning([NSString stringWithFormat:@"%@ cannot be set as document user default because it does not conform to coding protocol", documentUserDefault], nil);
		}
	} else {
		[documentUserDefaults removeObjectForKey:key];
	}
}

- (void)addDocumentUserDefaultsFromDictionary:(NSDictionary *)newDocumentUserDefaults {
	for (NSString *eachKey in [newDocumentUserDefaults keyEnumerator]) {
		[self setDocumentUserDefault:[newDocumentUserDefaults objectForKey:eachKey] forKey:eachKey];
	}
}

- (void)close {
	[BDocument storeDocumentUserDefaults:[self documentUserDefaults] forDocumentURL:[self fileURL]];
	[super close];
}

#pragma mark ODB Editor Suite support

@synthesize fromExternal;
@synthesize externalSender;
@synthesize externalToken;

- (NSString *)displayName {
	if (fromExternal && externalDisplayName != nil) {
		return externalDisplayName;
	}
	return [super displayName];
}

#pragma mark External File Changed Notification

- (void)readChangedFileFromDisk:(NSDate *)newModificationDate {
	NSError *error = nil;
	if (![self revertToContentsOfURL:[self fileURL] ofType:[self fileType] error:&error]) {
		BLogError(@"failed revertToSavedFromURL:ofType:");
		[self presentError:error];
	} else {
		[self setFileModificationDate:newModificationDate];
	}
	[[self undoManager] removeAllActions];
	[self updateChangeCount:NSChangeCleared];	
}

- (void)fileWasChangedExternallyByAnotherApplication:(NSDate *)newModificationDate {
	if ([self isDocumentEdited]) {
		NSString *processName = [[NSProcessInfo processInfo] processName];
		NSString *message = BLocalizedString(@"Warning", nil);
		NSString *informativeText = BLocalizedString(@"The file for this document has been modified by another application. There are also unsaved changes in %@. Do you want to keep the %@ version or revert to the version on disk?", nil);
		NSString *defaultButton = BLocalizedString(@"Keep %@ Version", nil);
		NSString *alternateButton = BLocalizedString(@"Revert", nil);
		NSAlert *alert = [NSAlert alertWithMessageText:message defaultButton:[NSString stringWithFormat:defaultButton, processName] alternateButton:alternateButton otherButton:nil informativeTextWithFormat:informativeText, processName, processName];
		[alert beginSheetModalForWindow:[[NSApp currentDocumentWindowController] window] modalDelegate:self didEndSelector:@selector(fileWasChangedExternallyAlertDidEnd:returnCode:contextInfo:) contextInfo:newModificationDate];
	} else {
		[self readChangedFileFromDisk:newModificationDate];
	}
}

- (void)fileWasChangedExternallyAlertDidEnd:(NSAlert *)alert returnCode:(int)returnCode contextInfo:(void *)contextInfo {
	if (returnCode == NSAlertDefaultReturn) { // keep current version
		[self setFileModificationDate:contextInfo];
	} else { // revert
		[self readChangedFileFromDisk:contextInfo];
	}
}

@end

NSString *BDocumentUserDefaultsWillSynchronizeNotification = @"BDocumentUserDefaultsWillSynchronizeNotification";
NSString *BDocumentUserDefaultsDidSynchronizeNotification = @"BDocumentUserDefaultsDidSynchronizeNotification";