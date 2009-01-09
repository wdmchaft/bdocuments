//
//  BDocumentCloud.h
//  BDocuments
//
//  Created by Jesse Grosjean on 9/29/08.
//  Copyright 2008 Hog Bay Software. All rights reserved.
//

#import <Blocks/Blocks.h>
#import "BDocuments.h"


@interface BDocumentCloud : NSObject {
	NSString *serviceRootURLString;
	NSString *localRootURLString;
	NSString *localDocumentsPath;
	NSString *localDocumentShadowsPath;
	NSString *localDocumentsConflictsPath;
}

#pragma mark Class Methods

+ (id)sharedInstance;
+ (NSString *)stringByURLEncodingStringParameter:(NSString *)str;

#pragma mark Sync

@property(retain) NSString *serviceRootURLString;
@property(retain) NSString *localRootURLString;
@property(readonly) NSString *localDocumentsPath;
@property(readonly) NSString *localDocumentShadowsPath;

- (NSDictionary *)GETDocuments:(NSError **)error;
- (NSDictionary *)POSTDocument:(NSDictionary *)document error:(NSError **)error;
- (NSDictionary *)PUTDocument:(NSDictionary *)document forKey:(NSString *)key error:(NSError **)error;
- (NSDictionary *)GETDocumentForKey:(NSString *)key error:(NSError **)error;

- (void)sync:(NSError **)bigError;

@end
