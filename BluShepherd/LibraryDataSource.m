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
#import "CoverArtCache.h"
#import <XMLDictionary/XMLDictionary.h>

@interface LibraryAlbum()
-(void)fetchCoverArt:(Player *)p;

@property (assign) BOOL needsArt;
@property (retain) NSArray *theSongs;

@end

static NSCharacterSet *queryChars;

@implementation LibraryAlbum

+(NSSet *)keyPathsForValuesAffectingSongs {
    return [NSSet setWithObject:@"theSongs"];
}

+(void)initialize {
    NSMutableCharacterSet *cs = [[NSCharacterSet URLQueryAllowedCharacterSet] mutableCopy];
    // sigh, URLQueryAllowedCharacterSet doesn't actually seem to be correct.
    [cs removeCharactersInString:@"&+"];
    queryChars = cs;
}

-(id)initWithDictionary:(NSDictionary *)v player:(Player *)p {
    self = [super init];
    if (![v isKindOfClass:[NSDictionary class]]) {
        NSLog(@"initWithDict called with %@", v);
    }
    self.title = [v objectForKey:@"title"];
    self.artist = [v objectForKey:@"art"];
    self.player = p;
    self.needsArt = YES;
    return self;
}

-(NSString *)encodedTitle {
    return [self.title stringByAddingPercentEncodingWithAllowedCharacters:queryChars];
}

-(NSString *)encodedArtist {
    return [self.artist stringByAddingPercentEncodingWithAllowedCharacters:queryChars];
}

-(void)fetchCoverArt:(Player *)p {
    if (self.needsArt) {
        self.needsArt = NO;
        [p.status urlWithPath:[NSString stringWithFormat:@"Artwork?service=LocalMusic&album=%@&artist=%@",
                        [self encodedTitle],
                        [self encodedArtist]]
                 block:^(NSURL *url) {
                     CoverArtCache *s = [AppDelegate delegate].coverCache;
                     [s loadImage:url completionHandler:^(NSImage *i) {
                         dispatch_async(dispatch_get_main_queue(), ^() {
                             self.coverArt = i;
                         });
                     }];
                 }];
    }
}

-(void)playNow:(id)sender {
    NSString *path = [NSString stringWithFormat:@"Add?playnow=1&where=nextAlbum&service=LocalMusic&album=%@&artist=%@",
                        [self encodedTitle],
                        [self encodedArtist]];
    [self.player playItems:path clearPlaylist:[[NSUserDefaults standardUserDefaults] boolForKey:prefClearOnPlayNow]];
}

-(void)playNext:(id)sender {
    NSString *path = [NSString stringWithFormat:@"Add?playnow=-1&where=nextAlbum&service=LocalMusic&album=%@&artist=%@",
                      [self encodedTitle],
                      [self encodedArtist]];
    [self.player playItems:path clearPlaylist:NO];
}

-(void)playLast:(id)sender {
    NSString *path = [NSString stringWithFormat:@"Add?playnow=-1&where=last&service=LocalMusic&album=%@&artist=%@",
                      [self encodedTitle],
                      [self encodedArtist]];
    [self.player playItems:path clearPlaylist:NO];
}

-(IBAction)openInBliss:(id)sender {
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"/album/%@/%@", [self encodedArtist], [self encodedTitle]]
                        relativeToURL:[NSURL URLWithString:[[NSUserDefaults standardUserDefaults] stringForKey:@"BlissURL"]]];
    [[NSWorkspace sharedWorkspace] openURL:url];
}

-(void)fetchSongs {
    NSURLSession *s = [AppDelegate delegate].session;
    NSString *path = [NSString stringWithFormat:@"Songs?service=LocalMusic&album=%@&artist=%@", [self encodedTitle], [self encodedArtist]];
    [self.player.status urlWithPath:path block:^(NSURL *url) {
        NSURLSessionTask *t = [s dataTaskWithURL:url completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
            NSDictionary *d = [NSDictionary dictionaryWithXMLData:data];
            id songs = [d valueForKeyPath:@"album.song"];
            if ([songs isKindOfClass:[NSDictionary class]]) {
                songs = [NSArray arrayWithObject:songs];
            }
            dispatch_async(dispatch_get_main_queue(), ^() {
                self.theSongs = songs;
                self.fetchingSongs = NO;
            });
        }];
        [t resume];
    }];
}

-(NSArray *)songs {
    if (self.theSongs == nil && !self.fetchingSongs) {
        self.fetchingSongs = YES;
        [self fetchSongs];
    }
    return self.theSongs;
}


@end

@interface LibraryCollectionViewItem : NSCollectionViewItem

-(IBAction)showDetails:(id)sender;

@end

@implementation LibraryCollectionViewItem

-(IBAction)showDetails:(id)sender {
    NSViewController *vc = [[NSViewController alloc] initWithNibName:@"AlbumPopup" bundle:nil];
    vc.representedObject = self.representedObject;

    NSPopover *p = [[NSPopover alloc] init];
    p.contentSize = NSMakeSize(350 ,400);
    p.behavior = NSPopoverBehaviorTransient;
    p.animates = YES;
    p.contentViewController = vc;
    
    // Convert point to main window coordinates
    NSRect entryRect = [sender convertRect:[sender bounds] toView:[[NSApp mainWindow] contentView]];
    [p showRelativeToRect:entryRect ofView:[[NSApp mainWindow] contentView] preferredEdge:NSMaxXEdge];
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
        self.filteredAlbums = @[];
        [self fetchAlbums];
    }
}

-(void)applyFilter {
    if (self.filterText.length == 0) {
        self.filteredAlbums = self.albums;
    } else {
        NSPredicate *p = [NSPredicate predicateWithFormat:@"title CONTAINS[c] %@ OR artist CONTAINS[c] %@", self.filterText, self.filterText];
        self.filteredAlbums = [self.albums filteredArrayUsingPredicate:p];
    }
    [self.collectionView reloadData];
}

-(IBAction)search:(id)sender {
    self.filterText = [[sender stringValue] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    [self applyFilter];
}

- (NSInteger)collectionView:(NSCollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    NSInteger c = self.filteredAlbums.count;
    return c;
}

- (NSCollectionViewItem *)collectionView:(NSCollectionView *)collectionView itemForRepresentedObjectAtIndexPath:(NSIndexPath *)indexPath {
    NSCollectionViewItem *item = [collectionView makeItemWithIdentifier:@"Album" forIndexPath:indexPath];
    LibraryAlbum *a = self.filteredAlbums[[indexPath item]];
    [a fetchCoverArt:selectedPlayer];
    [item setRepresentedObject:a];
    return item;
}

-(void)fetchAlbums {
    [selectedPlayer.status urlWithPath:@"Albums?service=LocalMusic" block:^(NSURL *url) {
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
                                                                      [albums addObject:[[LibraryAlbum alloc] initWithDictionary:a player:selectedPlayer]];
                                                                  }
                                                              } else {
                                                                  [albums addObject:[[LibraryAlbum alloc] initWithDictionary:album player:selectedPlayer]];
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
                                                              [self applyFilter];
                                                              
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
