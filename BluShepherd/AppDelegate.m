//
//  AppDelegate.m
//  BluShepherd
//
//  Created by Simon Fell on 11/26/16.
//  Copyright © 2016 Simon Fell. All rights reserved.
//

#import "AppDelegate.h"
#import "PlayerList.h"
#import "NowPlayingView.h"

@interface AppDelegate ()

@property (weak) IBOutlet NSWindow *window;
@property (weak) IBOutlet NSView *nowPlayingView;

@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    // Insert code here to initialize your application
    NowPlayingView *npv = [[NowPlayingView alloc] initWithNibName:nil bundle:nil];
    [self.nowPlayingView addSubview:[npv view]];
    
    [[NSNotificationCenter defaultCenter] addObserverForName:notificationPlayerSelection object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *n) {
        Player *p = [n object];
        npv.selectedPlayer = p;
        [p fetchStatus:^(NSDictionary *s) {
            NSLog(@"Player Status %@", s);
            npv.nowPlaying = s;
        }];
    }];
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
    // Insert code here to tear down your application
}

@end
