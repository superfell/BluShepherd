//
//  PlayerList.h
//  BluShepherd
//
//  Created by Simon Fell on 11/26/16.
//  Copyright © 2016 Simon Fell. All rights reserved.
//

#import <Foundation/Foundation.h>

extern NSString *notificationPlayerSelection;

@interface Player : NSObject<NSNetServiceDelegate, NSCopying>

@property (retain) NSImage *icon;
@property (retain) NSString *type;
@property (retain) NSString *name;
@property (retain) NSNetService *service;
@property (retain) NSArray *toUpdate;
@property (retain) NSMutableArray *onResolved;

@property (retain) NSDictionary *lastStatus;
@property (retain) NSDictionary *lastSyncStatus;

-(void)urlWithPath:(NSString *)path block:(void(^)(NSURL *url))block;

-(void)fetchSyncStatus;
-(void)fetchStatus:(void(^)(NSDictionary *s))block;

-(void)play:(void(^)(NSString *state))block;
-(void)pause:(void(^)(NSString *state))block;

-(void)playItems:(NSString *)urlPath;

@property (assign) BOOL playing;

@end

@interface PlayerList : NSObject<NSNetServiceBrowserDelegate, NSCollectionViewDataSource>

@property (retain) NSArray *players;
@property (retain) NSNetServiceBrowser *disco;

@property (weak) IBOutlet NSCollectionView *collectionView;

@end

@interface PlayerView : NSView 
@end
