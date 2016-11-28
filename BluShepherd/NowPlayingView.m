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

- (void)viewDidLoad {
    [super viewDidLoad];
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

-(NSDictionary *)nowPlaying {
    return self->nowPlaying;
}

-(void)setNowPlaying:(NSDictionary *)np {
    self->nowPlaying = np;
    if (self.selectedPlayer != nil && np != nil) {
        [self.selectedPlayer urlWithPath:@"" block:^(NSURL *url) {
            NSURL *art = [NSURL URLWithString:[self.nowPlaying objectForKey:@"image"] relativeToURL:url];
            if (![art isEqual:lastURL]) {
                NSURLSession *s =[NSURLSession sharedSession];
                NSURLSessionTask *t = [s dataTaskWithURL:art
                                       completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
                                           NSImage *i = [[NSImage alloc] initWithData:data];
                                           dispatch_async(dispatch_get_main_queue(), ^() {
                                               lastURL = art;
                                               self.coverArt = i;
                                           });
                                       }];
                [t resume];
            }
        }];
    }
}

@end
