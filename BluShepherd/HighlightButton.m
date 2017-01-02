//
//  HighlightButton.m
//  BluShepherd
//
//  Created by Simon Fell on 12/4/16.
//  Copyright © 2016 Simon Fell. All rights reserved.
//

#import "HighlightButton.h"

@implementation HighlightButton

-(void)awakeFromNib {
    NSImage *i = [NSImage imageNamed:@"play_album_hover"];
    self.highlightImage =i;
    self.regularImage = self.image;
}

-(void)updateTrackingAreas {
    [super updateTrackingAreas];
    [self removeTrackingArea:self.highlightArea];
    self.highlightArea = [[NSTrackingArea alloc] initWithRect:[self bounds] options:NSTrackingMouseEnteredAndExited | NSTrackingActiveInActiveApp owner:self userInfo:nil];
    [self addTrackingArea:self.highlightArea];
}

-(void)mouseEntered:(NSEvent *)event {
    [super mouseEntered:event];
    self.image = self.highlightImage;
}

-(void)mouseExited:(NSEvent *)event {
    [super mouseExited:event];
    self.image = self.regularImage;
}


@end
