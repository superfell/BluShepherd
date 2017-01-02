//
//  PlayerList.m
//  BluShepherd
//
//  Created by Simon Fell on 11/26/16.
//  Copyright © 2016 Simon Fell. All rights reserved.
//

#import "PlayerList.h"
#import "AppDelegate.h"
#import "CoverArtCache.h"
#import "NSNetService-Util.h"
#import <XMLDictionary/XMLDictionary.h>

NSString *notificationPlayerSelection = @"PlayerSelection";
NSString *prefClearOnPlayNow = @"clearOnPlayNow";

static NSString *selectionIndexPathsKey = @"selectionIndexPaths";

@interface PlayerStatus()
-(void)startStatus;
-(void)clearPlaylist:(void(^)())completionHandler;
@end

@implementation PlayerStatus

-(id)initWithService:(NSNetService *)s {
    self = [super init];
    PlayerStatus *ps = self;
    self.toUpdate = [NSMutableArray arrayWithCapacity:4];
    self.onResolved = [NSMutableArray arrayWithCapacity:4];
    [self.onResolved addObject:^(void) {
        [ps startStatus];
        [ps startSyncStatus];
    }];
    self.service = s;
    self.service.delegate = self;
    [self.service resolveWithTimeout:5];
    return self;
}

-(void)netServiceDidResolveAddress:(NSNetService *)sender {
    void (^b)();
    for (b in self.onResolved) {
        b();
    }
    [self.onResolved removeAllObjects];
}

/* Sent to the NSNetService instance's delegate when an error in resolving the instance occurs. The error dictionary will contain two key/value pairs representing the error domain and code (see the NSNetServicesError enumeration above for error code constants).
 */
-(void)netService:(NSNetService *)sender didNotResolve:(NSDictionary<NSString *, NSNumber *> *)errorDict {
    NSLog(@"didNotResolve %@ %@", sender, errorDict);
}

-(NSURL *)urlWithPath:(NSString *)path {
    NSArray *addr = [self.service addressesAndPorts];
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"http://%@:%ld/%@", [addr[0] address], (long)self.service.port, path]];
    return url;
}

-(void)urlWithPath:(NSString *)path block:(void(^)(NSURL *url))block {
    if ([[self.service addressesAndPorts] count] == 0) {
        [self.onResolved addObject:^() {
            block([self urlWithPath:path]);
        }];
        return;
    }
    block([self urlWithPath:path]);
}

typedef void (^SessionCallback)(NSData *data, NSURLResponse *resp, NSError *error);

-(void)startSyncStatus {
    NSURLSession *s = [AppDelegate delegate].session;
    NSURL *url = [self urlWithPath:@"SyncStatus"];
    __block __weak SessionCallback statusHandler;
    SessionCallback syncStatusHandler = ^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error == nil) {
            NSDictionary *d = [NSDictionary dictionaryWithXMLData:data];
            NSString *type = [d objectForKey:@"_modelName"];
            NSURL *iconUrl = [NSURL URLWithString:[d objectForKey:@"_icon"] relativeToURL:url];
            [[AppDelegate delegate].coverCache loadImage:iconUrl completionHandler:^(NSImage *i) {
                dispatch_async(dispatch_get_main_queue(), ^(void) {
                    if (self.toUpdate != nil) {
                        for (Player *c in self.toUpdate) {
                            c.type = type;
                            c.icon = i;
                        }
                    }
                });
            }];
            NSURL *nextUrl = [NSURL URLWithString:[NSString stringWithFormat:@"SyncStatus?etag=%@&timeout=60", [d objectForKey:@"_etag"]] relativeToURL:url];
            NSLog(@"got SyncStatus update, starting next request to %@", [nextUrl absoluteString]);
            NSURLSessionTask *t = [s dataTaskWithURL:nextUrl completionHandler:statusHandler];
            [t resume];
        } else {
            NSLog(@"result %@ %@", error, response);
        }
    };
    statusHandler = syncStatusHandler;
    NSURLSessionTask *t = [s dataTaskWithURL:url completionHandler:syncStatusHandler];
    [t resume];
}

-(void)startStatus {
    NSURLSession *s = [AppDelegate delegate].session;
    NSURL *url = [self urlWithPath:@"Status"];
    __block __weak SessionCallback statusHandler;
    SessionCallback myStatusHandler = ^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error == nil) {
            NSDictionary *d = [NSDictionary dictionaryWithXMLData:data];
            BOOL playing = [[d objectForKey:@"state"] isEqual:@"play"];
            dispatch_async(dispatch_get_main_queue(), ^() {
                self.lastStatus = d;
                self.playing = playing;
            });
            NSURL *nextUrl = [NSURL URLWithString:[NSString stringWithFormat:@"Status?etag=%@&timeout=60", [d objectForKey:@"_etag"]] relativeToURL:url];
            NSLog(@"got status update, starting next request to %@", [nextUrl absoluteString]);
            NSURLSessionTask *t = [s dataTaskWithURL:nextUrl completionHandler:statusHandler];
            [t resume];
        } else {
            NSLog(@"got error from status Update, restarting long poll: %@", error);
            NSURLSessionTask *t = [s dataTaskWithURL:url completionHandler:statusHandler];
            [t resume];
        }
    };
    statusHandler = myStatusHandler;
    NSURLSessionTask *t = [s dataTaskWithURL:url completionHandler:myStatusHandler];
    [t resume];
}

-(void)sendRequest:(NSString *)path completionHandler:(void(^)(NSData *data, NSURLResponse *response, NSError *berror))block {
    [self urlWithPath:path block:^(NSURL *url) {
        NSURLSession *s = [AppDelegate delegate].session;
        NSURLSessionTask *t = [s dataTaskWithURL:url completionHandler:block];
        [t resume];
    }];
}

-(void)playPause:(NSString *)newState block:(void(^)(NSString *state))block {
    NSURL *url = [self urlWithPath:newState];
    NSURLSession *s = [AppDelegate delegate].session;
    NSURLSessionTask *t = [s dataTaskWithURL:url
                           completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
                               NSDictionary *d = [NSDictionary dictionaryWithXMLData:data];
                               NSString *state =[d objectForKey:@"__text"];
                               BOOL playing = [state isEqualToString:@"play"];
                               dispatch_async(dispatch_get_main_queue(), ^() {
                                   self.playing = playing;
                               });
                               block(state);
                           }];
    [t resume];
}

-(void)clearPlaylist:(void(^)())completionHandler {
    NSURL *url = [self urlWithPath:@"Clear"];
    NSURLSession *s = [AppDelegate delegate].session;
    NSURLSessionTask *t = [s dataTaskWithURL:url completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        completionHandler();
    }];
    [t resume];
}

@end

@implementation Player

-(id)initWithService:(NSNetService *)s {
    self = [super init];
    self.status = [[PlayerStatus alloc] initWithService:s];
    [self.status.toUpdate addObject:self];
    self.name = s.name;
    return self;
}

- (id)copyWithZone:(nullable NSZone *)zone {
    Player *c = [[Player alloc] init];
    c.name = self.name;
    c.status = self.status;
    c.icon = self.icon;
    c.type = self.type;
    if (self.icon == nil) {
        [c.status.toUpdate addObject:c];
    }
    return c;
}

-(NSNetService *)service {
    return self.status.service;
}
            
-(void)play:(void(^)(NSString *state))block {
    [self.status playPause:@"Play" block:block];
}

-(void)pause:(void(^)(NSString *state))block {
    [self.status playPause:@"Pause" block:block];
}

-(void)playItems:(NSString *)urlPath clearPlaylist:(BOOL)clear {
    if (clear) {
        [self.status clearPlaylist:^() {
            [self.status playPause:urlPath block:^(NSString *state) {}];
        }];
    } else {
        [self.status playPause:urlPath block:^(NSString *state) {}];
    }
}

-(IBAction)startPlay:(id)sender {
    [self play:^(NSString *s) {}];
}

-(IBAction)pausePlay:(id)sender {
    [self pause:^(NSString *s) {}];
}

-(IBAction)backOneTrack:(id)sender {
    [self.status sendRequest:@"Back" completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
    }];
}

-(IBAction)forwardOneTrack:(id)sender {
    [self.status sendRequest:@"Skip" completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
    }];
}

-(IBAction)shuffleOn:(id)sender {
    [self.status sendRequest:@"Shuffle?state=1" completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
    }];
}

-(IBAction)shuffleOff:(id)sender {
    [self.status sendRequest:@"Shuffle?state=0" completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
    }];
}

@end

@implementation PlayerList

@synthesize players;

-(void)awakeFromNib {
    NSLog(@"in awakeFromNib");
    self.disco = [NSNetServiceBrowser new];
    self.disco.delegate = self;
    [self.disco searchForServicesOfType:@"_musc._tcp." inDomain:@""];
    self.collectionView.dataSource = self;
    [self.collectionView addObserver:self forKeyPath:selectionIndexPathsKey options:NSKeyValueObservingOptionNew|NSKeyValueObservingOptionOld context:nil];
}

- (void)netServiceBrowserWillSearch:(NSNetServiceBrowser *)browser {
    NSLog(@"willSearch: %@", browser);
}

/* Sent to the NSNetServiceBrowser instance's delegate when the instance's previous running search request has stopped.
 */
- (void)netServiceBrowserDidStopSearch:(NSNetServiceBrowser *)browser {
    NSLog(@"didStop %@", browser);
}

/* Sent to the NSNetServiceBrowser instance's delegate when an error in searching for domains or services has occurred. The error dictionary will contain two key/value pairs representing the error domain and code (see the NSNetServicesError enumeration above for error code constants). It is possible for an error to occur after a search has been started successfully.
 */
- (void)netServiceBrowser:(NSNetServiceBrowser *)browser didNotSearch:(NSDictionary<NSString *, NSNumber *> *)errorDict {
    NSLog(@"didNotSearch: %@ %@", browser, errorDict);
}

/* Sent to the NSNetServiceBrowser instance's delegate for each domain discovered. If there are more domains, moreComing will be YES. If for some reason handling discovered domains requires significant processing, accumulating domains until moreComing is NO and then doing the processing in bulk fashion may be desirable.
 */
- (void)netServiceBrowser:(NSNetServiceBrowser *)browser didFindDomain:(NSString *)domainString moreComing:(BOOL)moreComing {
    NSLog(@"didFindDomain %@ %hhd", domainString, moreComing);
}

/* Sent to the NSNetServiceBrowser instance's delegate for each service discovered. If there are more services, moreComing will be YES. If for some reason handling discovered services requires significant processing, accumulating services until moreComing is NO and then doing the processing in bulk fashion may be desirable.
 */
- (void)netServiceBrowser:(NSNetServiceBrowser *)browser didFindService:(NSNetService *)service moreComing:(BOOL)moreComing {
    NSLog(@"didFindService %@ %hhd", service, moreComing);
    NSLog(@"name %@ type %@ port %ld addresses %@", service.name, service.type, (long)service.port, service.addresses);
    Player *p =[[Player alloc] initWithService:service];
    if ([self.players count] == 0) {
        self.players = [NSArray arrayWithObject:p];
    } else {
        self.players = [self.players arrayByAddingObject:p];
    }
    [self.collectionView reloadData];
    if (self.players.count == 1) {
        [self.collectionView setSelectionIndexes:[NSIndexSet indexSetWithIndex:0]];
    }
}

/* Sent to the NSNetServiceBrowser instance's delegate when a previously discovered domain is no longer available.
 */
- (void)netServiceBrowser:(NSNetServiceBrowser *)browser didRemoveDomain:(NSString *)domainString moreComing:(BOOL)moreComing {
    NSLog(@"didRemoveDomain %@ %hhd", domainString, moreComing);
}

/* Sent to the NSNetServiceBrowser instance's delegate when a previously discovered service is no longer published.
 */
- (void)netServiceBrowser:(NSNetServiceBrowser *)browser didRemoveService:(NSNetService *)service moreComing:(BOOL)moreComing {
    NSLog(@"didRemoveService %@ %hhd", service, moreComing);
    NSArray *playersLeft = [self.players filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"service!=%@", service]];
    self.players = playersLeft;
    [self.collectionView reloadData];
}

- (NSInteger)collectionView:(NSCollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return self.players.count;
}

- (NSCollectionViewItem *)collectionView:(NSCollectionView *)collectionView itemForRepresentedObjectAtIndexPath:(NSIndexPath *)indexPath {
    NSCollectionViewItem *item = [collectionView makeItemWithIdentifier:@"Player" forIndexPath:indexPath];
    Player *p = self.players[[indexPath item]];
    [item setRepresentedObject:p];
    return item;
}

- (void)observeValueForKeyPath:(nullable NSString *)keyPath
                      ofObject:(nullable id)object
                        change:(nullable NSDictionary<NSString*, id> *)change
                       context:(nullable void *)context {
    NSLog(@"Selection update %@ %@", keyPath, change);
    if ([selectionIndexPathsKey isEqualToString:keyPath]) {
        NSIndexPath *path =[[change objectForKey:NSKeyValueChangeNewKey] anyObject];
        NSLog(@"path %@", path);
        NSInteger idx = [path item];
        Player *p = self.players[idx];
        [[NSNotificationCenter defaultCenter] postNotificationName:notificationPlayerSelection object:p];
    }
}

@end

@implementation PlayerView

-(void)awakeFromNib {
    self.wantsLayer = true;
}

@end
