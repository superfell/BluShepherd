//
//  PlayerList.h
//  BluShepherd
//
//  Created by Simon Fell on 11/26/16.
//  Copyright © 2016 Simon Fell. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface Player : NSObject<NSNetServiceDelegate, NSCopying>
@property (retain) NSImage *icon;
@property (retain) NSString *type;
@property (retain) NSString *name;
@property (retain) NSNetService *service;
@property (retain) NSArray *toUpdate;
-(void)fetchSyncStatus;

@end

@interface PlayerList : NSObject<NSNetServiceBrowserDelegate, NSCollectionViewDataSource>
@property (retain) NSArray *players;
@property (retain) NSNetServiceBrowser *disco;
@property (weak) IBOutlet NSCollectionView *collectionView;

@end

@interface PlayerView : NSView 
@end
