//
//  ControlsView.m
//  BluShepherd
//
//  Created by Simon Fell on 1/1/17.
//  Copyright © 2017 Simon Fell. All rights reserved.
//

#import "ControlsView.h"

@interface ControlsView ()

@end

@implementation ControlsView

+(NSSet *)keyPathsForValuesAffectingPlaying {
    return [NSSet setWithObject:@"nowPlaying"];
}

+(NSSet *)keyPathsForValuesAffectingShuffling {
    return [NSSet setWithObject:@"nowPlaying"];
}

-(void)onNowPlayingUpdated {
    NSLog(@"status\n%@\n", self->nowPlaying);
}

-(BOOL)playing {
    return [[self->nowPlaying objectForKey:@"state"] isEqualToString:@"play"];
}

-(BOOL)shuffling {
    return [[self->nowPlaying objectForKey:@"shuffle"] intValue] > 0;
}


@end
