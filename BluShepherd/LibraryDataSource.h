//
//  LibraryDataSource.h
//  BluShepherd
//
//  Created by Simon Fell on 11/27/16.
//  Copyright © 2016 Simon Fell. All rights reserved.
//

#import <Foundation/Foundation.h>

@class Player;

@interface LibraryAlbum : NSObject {
}

-(id)initWithDictionary:(NSDictionary *)v player:(Player *)p;

@property (retain) NSString *artist;
@property (retain) NSString *title;
@property (retain) NSImage *coverArt;
@property (retain) Player *player;

-(IBAction)playNow:(id)sender;
-(IBAction)playNext:(id)sender;
-(IBAction)playLast:(id)sender;

@end

@interface LibraryDataSource : NSObject<NSCollectionViewDataSource> {
    Player *selectedPlayer;
}

@property (retain) Player *selectedPlayer;
@property (weak) IBOutlet NSCollectionView *collectionView;
@property (retain) NSArray *albums;

@end

@interface LibraryAlbumView : NSView
@end
