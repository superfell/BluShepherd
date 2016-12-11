//
//  CoverArtCache.h
//  BluShepherd
//
//  Created by Simon Fell on 12/4/16.
//  Copyright © 2016 Simon Fell. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface CoverArtCache : NSObject {
    int32_t cacheHit;
    int32_t cacheAdd;
}

@property (retain) NSURLSession *session;

// loadImage will call the completionHandler with the resulting image
// It may get 2 calls, one with the cached data, and 2nd with the current data
// from the URL.
-(void)loadImage:(NSURL *)url completionHandler:(void (^)(NSImage *image))handler;

// Write out the current metadata if its dirty
-(void)flush;

// Expire old entries from the cache.
-(void)expire;

@end

@interface CacheItem: NSObject

@property (retain, atomic) NSString *url;
@property (retain, atomic) NSString *filename;
@property (assign, atomic) NSUInteger length;
@property (assign, atomic) BOOL used;
@property (readonly) NSDate *lastAccess;

-(NSDictionary *)asDict;
@end
