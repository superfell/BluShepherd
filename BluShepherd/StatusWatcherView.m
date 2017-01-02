//
//  StatusWatcherView.m
//  BluShepherd
//
//  Created by Simon Fell on 1/1/17.
//  Copyright © 2017 Simon Fell. All rights reserved.
//

#import "StatusWatcherView.h"
#import "PlayerList.h"

@interface StatusWatcherView ()

-(void)onNowPlayingUpdated;

@end

@implementation StatusWatcherView

-(Player *)selectedPlayer {
    return player;
}

-(void)setSelectedPlayer:(Player *)selectedPlayer {
    if (player != selectedPlayer) {
        [player.status removeObserver:self forKeyPath:@"lastStatus" context:nil];
        player = selectedPlayer;
        [player.status addObserver:self forKeyPath:@"lastStatus" options:NSKeyValueObservingOptionNew context:nil];
    }
}

- (void)observeValueForKeyPath:(nullable NSString *)keyPath
                      ofObject:(nullable id)object
                        change:(nullable NSDictionary<NSKeyValueChangeKey, id> *)change
                       context:(nullable void *)context {
    if ([keyPath isEqualToString:@"lastStatus"]) {
        [self setNowPlaying:[change objectForKey:NSKeyValueChangeNewKey]];
    }
}

-(NSDictionary *)nowPlaying {
    return self->nowPlaying;
}

-(void)setNowPlaying:(NSDictionary *)np {
    self->nowPlaying = np;
    [self onNowPlayingUpdated];
}

-(void)onNowPlayingUpdated {
}

@end
