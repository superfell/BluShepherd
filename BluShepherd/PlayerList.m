//
//  PlayerList.m
//  BluShepherd
//
//  Created by Simon Fell on 11/26/16.
//  Copyright © 2016 Simon Fell. All rights reserved.
//

#import "PlayerList.h"
#import "NSNetService-Util.h"
#import <XMLDictionary/XMLDictionary.h>

NSString *notificationPlayerSelection = @"PlayerSelection";

static NSString *selectionIndexPathsKey = @"selectionIndexPaths";

@interface Player()
-(NSURL *)urlWithPath:(NSString *)path;
@end

@implementation Player

@synthesize icon, name, type, service;

-(id)initWithService:(NSNetService *)s {
    self = [super init];
    Player *p = self;
    self.onResolved = [NSMutableArray arrayWithCapacity:4];
    [self.onResolved addObject:^(void) {
        [p fetchSyncStatus];
    }];
    self.name = s.name;
    self.service = s;
    self.service.delegate = self;
    [self.service resolveWithTimeout:5];
    return self;
}

- (id)copyWithZone:(nullable NSZone *)zone {
    Player *c = [[Player alloc] init];
    c.name = self.name;
    c.service = self.service;
    if (self.icon == nil) {
        if (self.toUpdate == nil) {
            self.toUpdate = [NSArray arrayWithObject:c];
        } else {
            self.toUpdate = [self.toUpdate arrayByAddingObject:c];
        }
    } else {
        c.type = self.type;
        c.icon = self.icon;
    }
    return c;
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

-(void)fetchSyncStatus {
    NSURL *url = [self urlWithPath:@"SyncStatus"];
    NSURLSessionTask *t = [[NSURLSession sharedSession] dataTaskWithURL:url
                                                      completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if (error == nil) {
            NSDictionary *d = [NSDictionary dictionaryWithXMLData:data];
            NSURL *iconUrl = [NSURL URLWithString:[d objectForKey:@"_icon"] relativeToURL:url];
            NSURLSessionTask *ticon = [[NSURLSession sharedSession] dataTaskWithURL:iconUrl
                                                                  completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
                NSImage *i = [[NSImage alloc] initWithData:data];
                dispatch_async(dispatch_get_main_queue(), ^(void) {
                    self.type = [d objectForKey:@"_modelName"];
                    self.icon = i;
                    if (self.toUpdate != nil) {
                        for (Player *c in self.toUpdate) {
                            c.type = self.type;
                            c.icon = self.icon;
                       }
                    }
                    self.toUpdate = nil;
                    NSLog(@"Loaded icon %@", self.icon);
                });
            }];
            [ticon resume];
        } else {
            NSLog(@"result %@ %@", error, response);
        }
    }];
    [t resume];
}

-(void)fetchStatus:(void(^)(NSDictionary *s))block {
    if (self.service.addresses.count == 0) {
        [self.onResolved addObject:^() {
            [self fetchStatus:block];
        }];
        return;
    }
    NSURL *url = [self urlWithPath:@"Status"];
    NSURLSessionTask *t = [[NSURLSession sharedSession] dataTaskWithURL:url
                                                      completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
                                                          NSDictionary *d = [NSDictionary dictionaryWithXMLData:data];
                                                          BOOL playing = [[d objectForKey:@"state"] isEqual:@"play"];
                                                          dispatch_async(dispatch_get_main_queue(), ^() {
                                                              self.lastStatus = d;
                                                              self.playing = playing;
                                                          });
                                                          block(d);
                                                      }];
    [t resume];
}

-(void)playPause:(NSString *)newState block:(void(^)(NSString *state))block {
    NSURL *url = [self urlWithPath:newState];
    NSURLSessionTask *t = [[NSURLSession sharedSession] dataTaskWithURL:url
                                                      completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
                                                          NSDictionary *d = [NSDictionary dictionaryWithXMLData:data];
                                                          NSLog(@"%@", d);
                                                          NSString *state =[d objectForKey:@"__text"];
                                                          BOOL playing = [state isEqualToString:@"play"];
                                                          dispatch_async(dispatch_get_main_queue(), ^() {
                                                              self.playing = playing;
                                                          });
                                                          block(state);
                                                      }];
    [t resume];
}

-(void)play:(void(^)(NSString *state))block {
    [self playPause:@"Play" block:block];
}

-(void)pause:(void(^)(NSString *state))block {
    [self playPause:@"Pause" block:block];
}

- (void)netServiceDidResolveAddress:(NSNetService *)sender {
    NSLog(@"didResolve %@ %ld %@ %@", sender, sender.port, sender.hostName, sender.addresses);
    void (^b)();
    for (b in self.onResolved) {
        b();
    }
    [self.onResolved removeAllObjects];
}

/* Sent to the NSNetService instance's delegate when an error in resolving the instance occurs. The error dictionary will contain two key/value pairs representing the error domain and code (see the NSNetServicesError enumeration above for error code constants).
 */
- (void)netService:(NSNetService *)sender didNotResolve:(NSDictionary<NSString *, NSNumber *> *)errorDict {
    NSLog(@"didNotResolve %@ %@", sender, errorDict);
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
//    self.layer.backgroundColor = CGColorGetConstantColor(kCGColorBlack);
}

@end
