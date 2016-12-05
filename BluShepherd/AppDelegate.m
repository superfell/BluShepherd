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
#import "LibraryDataSource.h"
#import "CoverArtCache.h"

@interface AppDelegate ()

@property (weak) IBOutlet NSWindow *window;
@property (weak) IBOutlet NSView *nowPlayingView;

-(NSURLSession *)createSession;
@end

@implementation AppDelegate

+(AppDelegate *) delegate {
    return [NSApp delegate];
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    self.session = [self createSession];
    self.coverCache = [[CoverArtCache alloc] initWithSession:self.session];

    NowPlayingView *npv = [[NowPlayingView alloc] initWithNibName:nil bundle:nil];
    [self.nowPlayingView addSubview:[npv view]];
    
    [[NSNotificationCenter defaultCenter] addObserverForName:notificationPlayerSelection object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *n) {
        Player *p = [n object];
        npv.selectedPlayer = p;
        self.selectedPlayer = p;
        self.library.selectedPlayer = p;
        [p fetchStatus:^(NSDictionary *s) {
            NSLog(@"Player Status %@", s);
            npv.nowPlaying = s;
        }];
    }];
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
    [self.coverCache flush];
}

-(IBAction)play:(id)sender {
    [self.selectedPlayer play:^(NSString *s) {
        NSLog(@"new state: %@", s);
    }];
}

-(IBAction)pause:(id)sender {
    [self.selectedPlayer pause:^(NSString *s) {
        NSLog(@"new state: %@", s);
    }];
}

-(NSURLSession *)createSession {
    // Configuring NSURLSession
    NSURLSessionConfiguration *cfg = [[NSURLSessionConfiguration defaultSessionConfiguration] copy];
    cfg.HTTPMaximumConnectionsPerHost = 4;
    cfg.HTTPShouldSetCookies = NO;
    cfg.requestCachePolicy = NSURLRequestReloadIgnoringLocalCacheData;
    return [NSURLSession sessionWithConfiguration:cfg];
}

@end
