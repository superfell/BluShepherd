//
//  StatusWatcherView.h
//  BluShepherd
//
//  Created by Simon Fell on 1/1/17.
//  Copyright © 2017 Simon Fell. All rights reserved.
//

#import <Cocoa/Cocoa.h>

// StatusWatcherView is a base class that deals with watching for status changes
// from the selected player.

@class Player;

@interface StatusWatcherView : NSViewController {
    Player *player;
    NSDictionary *nowPlaying;
}

@property (retain) Player *selectedPlayer;
@property (retain) NSDictionary *nowPlaying;

@end
