//
//  ControlsView.m
//  BluShepherd
//
//  Created by Simon Fell on 1/1/17.
//  Copyright © 2017 Simon Fell. All rights reserved.
//

#import "ControlsView.h"
#import "PlayerList.h"

@interface ControlsView ()
@property (readonly) NSInteger repeatMode;
@end

static const NSInteger repeat_None = 2;
static const NSInteger repeat_One = 1;
static const NSInteger repeat_All = 0;

@implementation ControlsView

+(NSSet *)keyPathsForValuesAffectingPlaying {
    return [NSSet setWithObject:@"nowPlaying"];
}

+(NSSet *)keyPathsForValuesAffectingShuffling {
    return [NSSet setWithObject:@"nowPlaying"];
}

+(NSSet *)keyPathsForValuesAffectingRepeatImage {
    return [NSSet setWithObject:@"nowPlaying"];
}

-(void)awakeFromNib {
    self.overlayView.wantsLayer = YES;
    self.overlayView.layer.backgroundColor = CGColorCreateCopyWithAlpha([NSColor controlColor].CGColor, 0.75);
}

-(void)onNowPlayingUpdated {
    self.overlayView.hidden = TRUE;
}

-(BOOL)playing {
    return [[self->nowPlaying objectForKey:@"state"] isEqualToString:@"play"];
}

-(BOOL)shuffling {
    return [[self->nowPlaying objectForKey:@"shuffle"] intValue] > 0;
}

-(NSInteger)repeatMode {
    if (self->nowPlaying == nil) {
        return repeat_None;
    }
    NSInteger rm = [[self->nowPlaying objectForKey:@"repeat"] integerValue];
    return rm;
}

-(NSImage *)repeatImage {
    NSInteger rm = self.repeatMode;
    switch (rm) {
    case repeat_None: return [NSImage imageNamed:@"repeat"];
    case repeat_One: return [NSImage imageNamed:@"repeat_1"];
    case repeat_All: return [NSImage imageNamed:@"repeat_on"];
    }
    NSLog(@"Unexpected repeat mode of %ld", (long)rm);
    return [NSImage imageNamed:@"repeat"];
}

-(IBAction)nextRepeatMode:(id)sender {
    NSInteger rm = self.repeatMode - 1;
    if (rm < repeat_All) {
        rm = repeat_None;
    }
    [self.selectedPlayer repeatMode:rm];
}

@end
