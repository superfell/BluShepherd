//
//  LibraryDataSource.m
//  BluShepherd
//
//  Created by Simon Fell on 11/27/16.
//  Copyright © 2016 Simon Fell. All rights reserved.
//

#import "LibraryDataSource.h"
#import "PlayerList.h"
#import "AppDelegate.h"
#import <XMLDictionary/XMLDictionary.h>

@interface LibraryAlbum()
-(void)fetchCoverArt:(Player *)p;

@property (assign) BOOL needsArt;
@end

@implementation LibraryAlbum

-(id)initWithDictionary:(NSDictionary *)v {
    self = [super init];
    if (![v isKindOfClass:[NSDictionary class]]) {
        NSLog(@"initWithDict called with %@", v);
    }
    self.title = [v objectForKey:@"title"];
    self.artist = [v objectForKey:@"art"];
    self.needsArt = YES;
    return self;
}

-(void)fetchCoverArt:(Player *)p {
    if (self.needsArt) {
        self.needsArt = NO;
        [p urlWithPath:[NSString stringWithFormat:@"Artwork?service=LocalMusic&album=%@&artist=%@",
                        [self.title stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]],
                        [self.artist stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]]]
                 block:^(NSURL *url) {
                     NSURLSession *s = ((AppDelegate *)(NSApp.delegate)).cachingSession;
                     NSURLSessionTask *t = [s dataTaskWithURL:url
                                            completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
                                                NSHTTPURLResponse *r = (NSHTTPURLResponse *)response;
                                                if ([r statusCode] != 200) {
                                                    NSLog(@"Got error reading artwork %ld \\ %@", [r statusCode], [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]);
                                                }
                                                NSImage *i = [[NSImage alloc] initWithData:data];
                                                dispatch_async(dispatch_get_main_queue(), ^() {
                                                    self.coverArt = i;
                                                });
                                            }];
                     [t resume];
                 }];
    }
}

@end

@interface LibraryDataSource()
-(void)fetchAlbums;
@end

@implementation LibraryDataSource

- (Player *)selectedPlayer {
    return selectedPlayer;
}

- (void)setSelectedPlayer:(Player *)p {
    if (selectedPlayer != p) {
        selectedPlayer = p;
        self.albums = @[];
        [self fetchAlbums];
    }
}

- (NSInteger)collectionView:(NSCollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    NSInteger c = self.albums.count;
    NSLog(@"numberOfItems returning %ld", c);
    return c;
}

- (NSCollectionViewItem *)collectionView:(NSCollectionView *)collectionView itemForRepresentedObjectAtIndexPath:(NSIndexPath *)indexPath {
    NSCollectionViewItem *item = [collectionView makeItemWithIdentifier:@"Album" forIndexPath:indexPath];
    LibraryAlbum *a = self.albums[[indexPath item]];
    [a fetchCoverArt:selectedPlayer];
    [item setRepresentedObject:a];
    
//    NSLog(@"itemForObject at %ld returning %@/%@ %@", [indexPath item], a.artist, a.title, item);
    return item;
}

-(void)fetchAlbums {
    [selectedPlayer urlWithPath:@"Albums?service=LocalMusic" block:^(NSURL *url) {
        NSURLSessionTask *t = [[NSURLSession sharedSession] dataTaskWithURL:url
                                                      completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
                                                          NSDictionary *d = [NSDictionary dictionaryWithXMLData:data];
                                                          NSArray *sections = [[d objectForKey:@"sections"] objectForKey:@"section"];
                                                          NSMutableArray *albums = [NSMutableArray array];
                                                          for(NSDictionary *section in sections) {
                                                              id album = [section objectForKey:@"album"];
                                                              // album may be an array if there's more than one album in the section
                                                              // or a dictionary of the one album in the section.
                                                              if ([album isKindOfClass:[NSArray class]]) {
                                                                  for(NSDictionary *a in album) {
                                                                      [albums addObject:[[LibraryAlbum alloc] initWithDictionary:a]];
                                                                  }
                                                              } else {
                                                                  [albums addObject:[[LibraryAlbum alloc] initWithDictionary:album]];
                                                              }
                                                          }
                                                          
                                                          NSArray *sorted = [albums sortedArrayUsingComparator:^NSComparisonResult(LibraryAlbum *a, LibraryAlbum *b) {
                                                              NSComparisonResult r = [a.artist compare:b.artist];
                                                              if (r == NSOrderedSame) {
                                                                  r = [a.title compare:b.title];
                                                              }
                                                              return r;
                                                          }];
                                                          dispatch_async(dispatch_get_main_queue(), ^() {
                                                              NSLog(@"Updating library albums to %ld items", sorted.count);
                                                              self.albums = sorted;
                                                              [self.collectionView reloadData];
                                                          });
                                                      }];
        [t resume];
    }];
}
@end

@implementation LibraryAlbumView

-(void)awakeFromNib {
    self.wantsLayer = true;
    self.layer.backgroundColor = CGColorCreateGenericGray(0.92f, 1.0f);
    self.layer.borderWidth = 1.5f;
    self.layer.borderColor = CGColorCreateGenericGray(0.78f, 1.0f);
}

@end
