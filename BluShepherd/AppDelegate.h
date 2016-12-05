//
//  AppDelegate.h
//  BluShepherd
//
//  Created by Simon Fell on 11/26/16.
//  Copyright © 2016 Simon Fell. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class Player;
@class LibraryDataSource;
@class CoverArtCache;

@interface AppDelegate : NSObject <NSApplicationDelegate>

@property (retain) NSURLSession *session;
@property (retain) CoverArtCache *coverCache;

@property (retain) Player *selectedPlayer;
@property (retain) IBOutlet LibraryDataSource *library;

-(IBAction)play:(id)sender;
-(IBAction)pause:(id)sender;

+(AppDelegate *) delegate;
@end

