//
//  ClickableView.m
//  BluShepherd
//
//  Created by Simon Fell on 12/11/16.
//  Copyright © 2016 Simon Fell. All rights reserved.
//

#import "ClickableView.h"

@implementation ClickableView

-(void)mouseDown:(NSEvent *)event {
    if (event.type != NSLeftMouseDown) {
        [super mouseDown:event];
    }
}

-(void)mouseUp:(NSEvent *)event {
    if (event.type == NSLeftMouseUp) {
        NSPoint pt = [self convertPoint:[event locationInWindow] fromView:nil];
        if (NSPointInRect(pt, self.bounds)) {
            [NSApp sendAction:self.action to:self.target from:self];
        }
    } else {
        [super mouseUp:event];
    }
}

@end
