//
//  PlayerList.m
//  BluShepherd
//
//  Created by Simon Fell on 11/26/16.
//  Copyright © 2016 Simon Fell. All rights reserved.
//

#import "PlayerList.h"
#import "NSNetService-Util.h"

@implementation Player

@synthesize icon, name, type, service;

-(id)initWithService:(NSNetService *)s {
    self = [super init];
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
    if (self.type == nil) {
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

-(void)fetchSyncStatus {
    NSArray *addr = [self.service addressesAndPorts];
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"http://%@:%ld/SyncStatus", [addr[0] address], (long)self.service.port]];
    NSLog(@"starting request for %@", url);
    NSURLSessionTask *t = [[NSURLSession sharedSession] dataTaskWithURL:url completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        NSLog(@"result %@ %@", error, response);
    }];
    [t resume];
}


- (void)netServiceDidResolveAddress:(NSNetService *)sender {
    NSLog(@"didResolve %@ %ld %@ %@", sender, sender.port, sender.hostName, sender.addresses);
    [self fetchSyncStatus];
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
    NSNib *player = [[NSNib alloc] initWithNibNamed:@"Player" bundle:nil];
    [self.collectionView registerNib:player forItemWithIdentifier:@"Player"];
    self.collectionView.dataSource = self;
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
    NSLog(@"item %@ %@ %@", collectionView, self.collectionView, indexPath);
    NSCollectionViewItem *item = [collectionView makeItemWithIdentifier:@"Player" forIndexPath:indexPath];
    Player *p = self.players[[indexPath item]];
    [item setRepresentedObject:p];
    NSLog(@"collectionView item:%@ %@ %@", indexPath, p, item);
    return item;
}

@end
