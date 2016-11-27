//
//  NowPlayingView.m
//  BluShepherd
//
//  Created by Simon Fell on 11/26/16.
//  Copyright © 2016 Simon Fell. All rights reserved.
//

#import "NowPlayingView.h"
#import "PlayerList.h"

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

+ (NSSet *)keyPathsForValuesAffectingCoverArtUrl {
    return [NSSet setWithObjects:@"selectedPlayer", @"nowPlaying", nil];
}

+ (NSSet *)keyPathsForValuesAffectingCoverArt {
    return [NSSet setWithObjects:@"selectedPlayer", @"nowPlaying", nil];
}

- (void)viewDidLoad {
    [super viewDidLoad];
//    self.view.wantsLayer = true;
  //  self.view.layer.backgroundColor = CGColorGetConstantColor(kCGColorBlack);
    // Do view setup here.
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

-(NSURL *)coverArtUrl {
    if (self.selectedPlayer == nil || self.nowPlaying == nil) {
        return nil;
    }
    NSURL *res = [NSURL URLWithString:[self.nowPlaying objectForKey:@"image"] relativeToURL:[self.selectedPlayer urlWithPath:@""]];
    return res;
}

-(NSDictionary *)nowPlaying {
    return self->nowPlaying;
}

-(void)setNowPlaying:(NSDictionary *)np {
    self->nowPlaying = np;
    NSURL *art = self.coverArtUrl;
    if ([art isEqual:lastURL]) {
        return;
    }
    NSURLSessionTask *t = [[NSURLSession sharedSession] dataTaskWithURL:art
                                                      completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
                                                          NSImage *i = [[NSImage alloc] initWithData:data];
                                                          dispatch_async(dispatch_get_main_queue(), ^() {
                                                              lastURL = art;
                                                              self.coverArt = i;
                                                          });
                                                      }];
    [t resume];
}

@end
