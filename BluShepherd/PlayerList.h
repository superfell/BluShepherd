//
//  PlayerList.h
//  BluShepherd
//
//  Created by Simon Fell on 11/26/16.
//  Copyright © 2016 Simon Fell. All rights reserved.
//

#import <Foundation/Foundation.h>

extern NSString *notificationPlayerSelection;
extern NSString *prefClearOnPlayNow;


@interface PlayerStatus : NSObject<NSNetServiceDelegate>

@property (retain) NSNetService *service;
@property (retain) NSMutableArray *toUpdate;
@property (retain) NSMutableArray *onResolved;

@property (retain) NSDictionary *lastStatus;
@property (retain) NSDictionary *lastSyncStatus;

@property (assign) BOOL playing;

-(void)urlWithPath:(NSString *)path block:(void(^)(NSURL *url))block;

-(void)sendRequest:(NSString *)path completionHandler:(void(^)(NSData *data, NSURLResponse * response, NSError *error))block;

@end

@interface Player : NSObject<NSCopying>

@property (retain) NSImage *icon;
@property (retain) NSString *type;
@property (retain) NSString *name;
@property (readonly) NSNetService *service;

@property (retain) PlayerStatus *status;

-(void)play:(void(^)(NSString *state))block;
-(void)pause:(void(^)(NSString *state))block;
-(void)playItems:(NSString *)urlPath clearPlaylist:(BOOL)clear;
-(void)repeatMode:(NSInteger)mode;

-(IBAction)startPlay:(id)sender;
-(IBAction)pausePlay:(id)sender;

-(IBAction)backOneTrack:(id)sender;
-(IBAction)forwardOneTrack:(id)sender;
-(IBAction)shuffleOn:(id)sender;
-(IBAction)shuffleOff:(id)sender;

@end

@interface PlayerList : NSObject<NSNetServiceBrowserDelegate, NSCollectionViewDataSource>

@property (retain) NSArray *players;
@property (retain) NSNetServiceBrowser *disco;

@property (weak) IBOutlet NSCollectionView *collectionView;

@end

@interface PlayerView : NSView 
@end
