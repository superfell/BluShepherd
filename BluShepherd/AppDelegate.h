//
//  AppDelegate.h
//  BluShepherd
//
//  Created by Simon Fell on 11/26/16.
//  Copyright © 2016 Simon Fell. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class Player;

@interface AppDelegate : NSObject <NSApplicationDelegate>

@property (retain) Player *selectedPlayer;

-(IBAction)play:(id)sender;
-(IBAction)pause:(id)sender;

@end

