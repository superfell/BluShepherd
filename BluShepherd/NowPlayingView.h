//
//  NowPlayingView.h
//  BluShepherd
//
//  Created by Simon Fell on 11/26/16.
//  Copyright © 2016 Simon Fell. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class Player;

@interface NowPlayingView : NSViewController {
    NSURL   *lastURL;
    NSImage *lastCoverArt;
    NSDictionary *nowPlaying;
}

@property (retain) NSDictionary *nowPlaying;
@property (retain) Player *selectedPlayer;

@property (readonly) NSString *title1;
@property (readonly) NSString *title2;
@property (readonly) NSString *title3;
@property (retain) NSImage *coverArt;

@end
