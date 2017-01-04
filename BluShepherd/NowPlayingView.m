//
//  NowPlayingView.m
//  BluShepherd
//
//  Created by Simon Fell on 11/26/16.
//  Copyright © 2016 Simon Fell. All rights reserved.
//

#import "NowPlayingView.h"
#import "PlayerList.h"
#import "AppDelegate.h"
#import "CoverArtCache.h"

@interface NowPlayingView ()

@end

@implementation NowPlayingView

+ (NSSet *)keyPathsForValuesAffectingTitle1 {
    return [NSSet setWithObject:@"nowPlaying"];
}

+ (NSSet *)keyPathsForValuesAffectingTitle2 {
    return [NSSet setWithObject:@"nowPlaying"];
}

+ (NSSet *)keyPathsForValuesAffectingTitle3 {
    return [NSSet setWithObject:@"nowPlaying"];
}

+ (NSSet *)keyPathsForValuesAffectingWidgetTitle {
    return [NSSet setWithObject:@"nowPlaying"];
}

-(NSString *)widgetTitle {
    if ([[self.nowPlaying objectForKey:@"state"] isEqualToString:@"play"]) {
        return @"Now Playing";
    }
    return @"Paused";
}

-(NSString *)title1 {
    return [self.nowPlaying objectForKey:@"title1"];
}

-(NSString *)title2 {
    return [self.nowPlaying objectForKey:@"title2"];
}

-(NSString *)title3 {
    return [self.nowPlaying objectForKey:@"title3"];
}

-(void)onNowPlayingUpdated {
    NSDictionary *np = self->nowPlaying;
    
    if (self.selectedPlayer != nil && np != nil) {
        [self.selectedPlayer.status urlWithPath:@"" block:^(NSURL *url) {
            NSString *image = ((self->nowPlaying != nil) && (self->nowPlaying != [NSNull null])) ? [self->nowPlaying objectForKey:@"image"] : nil;
            if ([image length] == 0) {
                dispatch_async(dispatch_get_main_queue(), ^() {
                    self.coverArt = nil;
                });
                return;
            }
            NSURL *art = [NSURL URLWithString:image relativeToURL:url];
            if (![art isEqual:lastURL]) {
                [[AppDelegate delegate].coverCache loadImage:art completionHandler:^(NSImage *i) {
                       dispatch_async(dispatch_get_main_queue(), ^() {
                           lastURL = art;
                           self.coverArt = i;
                       });
                   }];
            }
        }];
    }
}

@end
