//
//  HighlightButton.h
//  BluShepherd
//
//  Created by Simon Fell on 12/4/16.
//  Copyright © 2016 Simon Fell. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface HighlightButton : NSButton

@property (retain) NSTrackingArea *highlightArea;
@property (retain) NSImage *highlightImage;
@property (retain) NSImage *regularImage;
@end
