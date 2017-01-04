//
//  NowPlayingView.h
//  BluShepherd
//
//  Created by Simon Fell on 11/26/16.
//  Copyright © 2016 Simon Fell. All rights reserved.
//

#import "StatusWatcherView.h"


@interface NowPlayingView : StatusWatcherView {
    NSURL   *lastURL;
    NSImage *lastCoverArt;
}

@property (readonly) NSString *widgetTitle;
@property (readonly) NSString *title1;
@property (readonly) NSString *title2;
@property (readonly) NSString *title3;
@property (retain) NSImage *coverArt;

@end
