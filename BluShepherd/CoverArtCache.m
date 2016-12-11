//
//  CoverArtCache.m
//  BluShepherd
//
//  Created by Simon Fell on 12/4/16.
//  Copyright © 2016 Simon Fell. All rights reserved.
//

#import "CoverArtCache.h"
#include <sys/stat.h>

static NSString *metaFilename = @"meta.dict";

static NSString *keyFilename = @"fn";
static NSString *keyLength = @"len";

@interface CacheItem()
-(id)initFromDictionary:(NSDictionary *)d;

@property (readwrite,atomic) NSDate *cachedLastAccess;
@end

@implementation CacheItem

-(id)initFromDictionary:(NSDictionary *)d {
    self = [super init];
    self.filename = [d objectForKey:keyFilename];
    self.length = [[d objectForKey:keyLength] unsignedIntegerValue];
    return self;
}

-(NSDictionary *)asDict {
    return [NSDictionary dictionaryWithObjectsAndKeys:
            self.filename,                                      keyFilename,
            [NSNumber numberWithUnsignedInteger:self.length],   keyLength,
            nil];
}

-(NSDate *)lastAccess {
    if (self.cachedLastAccess != nil) {
        return self.cachedLastAccess;
    }
    struct stat output;
    stat([self.filename fileSystemRepresentation], &output);
    struct timespec accessTime = output.st_atimespec;
    NSDate *aDate = [NSDate dateWithTimeIntervalSince1970:accessTime.tv_sec];
    self.cachedLastAccess = aDate;
    return aDate;
}

@end

@interface LoadRequest : NSObject
@property (retain) NSURL *url;
@property (copy) void(^callback)(NSImage *);
@property (retain) CacheItem *item;
@property (retain) NSData *cachedData;
@end

@implementation LoadRequest
@end

@interface CoverArtCache()

@property (retain) NSTimer *metaWriterTimer;
@property (retain) NSString *dir;

@property (retain) NSLock *lock;
@property (assign) BOOL dirty;
@property (retain) NSMutableDictionary *meta;       // url -> dictionary persistable version
@property (retain) NSMutableDictionary *metaItems;  // url -> cacheItem
@property (retain) NSMutableArray *queue;           // items waiting to be loaded.

-(CacheItem *)cached:(NSURL *)url;
-(NSData *)load:(CacheItem *)item;

-(void)add:(NSData *)data withKey:(NSURL *)url replacing:(CacheItem *)existing;
-(NSString *)writeData:(NSData *)d;

-(void)writeMeta;

@end


@implementation CoverArtCache

-(id)init {
    self = [super init];
    // Configuring NSURLSession
    NSURLSessionConfiguration *cfg = [[NSURLSessionConfiguration defaultSessionConfiguration] copy];
    cfg.HTTPMaximumConnectionsPerHost = 2;
    cfg.HTTPShouldSetCookies = NO;
    cfg.timeoutIntervalForRequest = 15;
    cfg.requestCachePolicy = NSURLRequestReloadIgnoringLocalCacheData;
    self.session = [NSURLSession sessionWithConfiguration:cfg];
    self.lock = [[NSLock alloc] init];
    NSArray *cacheDirs = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    NSString *bundleName = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleIdentifier"];
    self.dir = [[[cacheDirs firstObject] stringByAppendingPathComponent:bundleName] stringByAppendingPathComponent:@"coverArt"];
    NSLog(@"Initializing coverArt cache at %@", self.dir);
    [[NSFileManager defaultManager] createDirectoryAtPath:self.dir withIntermediateDirectories:YES attributes:nil error:nil];
    NSDictionary *d = [NSDictionary dictionaryWithContentsOfFile:[self.dir stringByAppendingPathComponent:metaFilename]];
    if (d == nil) {
        self.meta = [[NSMutableDictionary alloc] init];
    } else {
        self.meta = [d mutableCopy];
    }
    self.metaItems = [[NSMutableDictionary alloc] init];
    self.queue = [NSMutableArray arrayWithCapacity:64];
    self.metaWriterTimer = [NSTimer scheduledTimerWithTimeInterval:5.0 target:self selector:@selector(writeMeta) userInfo:nil repeats:YES];
    return self;
}

-(void)flush {
    [self writeMeta];
}

-(void)writeMeta {
    BOOL isDirty;
    NSDictionary *dict;
    NSUInteger numItems;
    [self.lock lock];
    isDirty = self.dirty;
    if (isDirty) {
        dict = [self.meta copy];
        self.dirty = NO;
    }
    numItems = [self.meta count];
    [self.lock unlock];
    if (isDirty) {
        [dict writeToFile:[self.dir stringByAppendingPathComponent:metaFilename] atomically:YES];
    }
    int32_t hit = OSAtomicAdd32(0, &cacheHit);
    int32_t add = OSAtomicAdd32(0, &cacheAdd);
    if (hit > 0 || add > 0) {
        NSLog(@"CoverArtCache: %ld items, %d hits, %d new items", (unsigned long)numItems, hit, add);
        OSAtomicAdd32(-hit, &cacheHit);
        OSAtomicAdd32(-add, &cacheAdd);
    }
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^() {
        [self expire];
    });
}

-(void)fetchImage:(NSURL *)url cacheItem:(CacheItem *)cached cachedData:(NSData *)cachedData handler:(void(^)(NSImage *))handler {
    NSURLSessionTask *t = [self.session dataTaskWithURL:url
                                      completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        OSAtomicAdd32(-1, &fetching);
        NSHTTPURLResponse *r = (NSHTTPURLResponse *)response;
        if ([r statusCode] != 200) {
            NSLog(@"Got error reading artwork %ld %@ \\ %@", [r statusCode], error, [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]);
        } else {
            if ([data length] < 128) {
                NSLog(@"got %ld bytes for %@", [data length], url);
            }
            if ((cachedData == nil) ||(![data isEqualToData:cachedData])) {
                OSAtomicIncrement32(&cacheAdd);
                NSImage *i = [[NSImage alloc] initWithData:data];
                handler(i);
                [self add:data withKey:url replacing:cached];
            }
        }
        [self.lock lock];
        LoadRequest *next = [self.queue lastObject];
        if (next != nil) {
            [self.queue removeLastObject];
        }
        [self.lock unlock];
        if (next != nil) {
            [self fetchImage:next.url cacheItem:next.item cachedData:next.cachedData handler:next.callback];
        }
      }];
    [t resume];
}

-(void)loadImage:(NSURL *)url completionHandler:(void (^)(NSImage *image))handler {
    CacheItem *cached = [self cached:url];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT,0), ^() {
        NSData *cachedData = [self load:cached];
        if (cachedData != nil) {
            NSImage *i = [[NSImage alloc] initWithData:cachedData];
            OSAtomicIncrement32(&cacheHit);
            handler(i);
        }
        int32_t fetchCount = OSAtomicAdd32(1, &fetching);
        if (fetchCount > 2) {
            LoadRequest *r = [[LoadRequest alloc] init];
            r.url = url;
            r.callback = handler;
            r.cachedData = cachedData;
            r.item = cached;
            [self.lock lock];
            // jump to the head of the queue, newer requests for images are more likely to be
            // shown to the user than older ones. [the queue is actioned in reverse order].
            [self.queue addObject:r];
            [self.lock unlock];
            return;
        }
        [self fetchImage:url cacheItem:cached cachedData:cachedData handler:handler];
    });
}

-(CacheItem *)cachedWithKey:(NSString *)k {
    if (k == nil) {
        return nil;
    }
    [self.lock lock];
    CacheItem *i = [self.metaItems objectForKey:k];
    if (i == nil) {
        NSDictionary *d  = [self.meta objectForKey:k];
        if (d != nil) {
            i = [[CacheItem alloc] initFromDictionary:d];
            i.url = k;
            [self.metaItems setObject:i forKey:k];
        }
    }
    [self.lock unlock];
    return i;
}

-(CacheItem *)cached:(NSURL *)url {
    NSString *k = [url absoluteString];
    return [self cachedWithKey:k];
}

-(NSData *)load:(CacheItem *)i {
    NSData *d = [[NSData alloc] initWithContentsOfFile:[self.dir stringByAppendingPathComponent:i.filename]];
    if (d != nil) {
        i.used = YES;
    }
    return d;
}

-(void)add:(NSData *)data withKey:(NSURL *)url replacing:(CacheItem *)existing {
    CacheItem *i = [[CacheItem alloc] init];
    i.filename = [self writeData:data];
    i.length = [data length];
    i.used = YES;
    i.url = [url absoluteString];
    NSDictionary *d = [i asDict];
    NSString *k = [url absoluteString];
    [self.lock lock];
    [self.meta setObject:d forKey:k];
    [self.metaItems setObject:i forKey:k];
    self.dirty = YES;
    [self.lock unlock];
    if (existing != nil) {
        [[NSFileManager defaultManager] removeItemAtPath:[self.dir stringByAppendingPathComponent:existing.filename] error:nil];
    }
}

// writeData writes the supplied NSData to a new unqiue file in self.dir and returns the filename of the new file.
-(NSString *)writeData:(NSData *)data {
    NSString *tempFileTemplate = [self.dir stringByAppendingPathComponent:@"cover_XXXXXX"];
    const char *tempFileTemplateCString = [tempFileTemplate fileSystemRepresentation];
    char *tempFileNameCString = (char *)malloc(strlen(tempFileTemplateCString) + 1);
	strcpy(tempFileNameCString, tempFileTemplateCString);
    int fileDescriptor = mkstemp(tempFileNameCString);
    
    NSString *fn = [[[NSFileManager defaultManager] stringWithFileSystemRepresentation:tempFileNameCString length:strlen(tempFileNameCString)] lastPathComponent];
    
    free(tempFileNameCString);
    NSFileHandle *tempFileHandle = [[NSFileHandle alloc] initWithFileDescriptor:fileDescriptor closeOnDealloc:NO];
    [tempFileHandle writeData:data];
    [tempFileHandle closeFile];
    return fn;
}

-(void)expire {
    NSNumber *ms = [[NSUserDefaults standardUserDefaults] objectForKey:@"Covers_MaxCacheSize"];
    if ([ms unsignedLongValue] == 0) {
        ms = [NSNumber numberWithUnsignedLong:1024L * 1024 * 1024 * 4];  // 4 Gb.
    }
    NSNumber *me = [[NSUserDefaults standardUserDefaults] objectForKey:@"Covers_MaxCacheEntries"];
    if ([me integerValue] == 0) {
        me = [NSNumber numberWithInteger:1024 * 8];
    }
    [self.lock lock];
    NSMutableDictionary *metaCopy = [self.meta mutableCopy];
    NSMutableDictionary *metaItemsCopy = [self.metaItems mutableCopy];
    [self.lock unlock];
    __block unsigned long totalBytes = 0;
    for (NSDictionary *i in [metaCopy allValues]) {
        totalBytes += [[i objectForKey:keyLength] longValue];
    }
    bool(^needsExpiry)(float factor) = ^bool(float factor) {
        return ([metaCopy count] > (factor *[me integerValue])) || (totalBytes > (factor *[ms unsignedLongValue]));
    };
    if (!needsExpiry(1.0f)) {
        return;
    }
    NSLog(@"enties %ld / %ld, size %ld / %ld", [metaCopy count], [me integerValue], totalBytes / 1024 / 1024, [ms unsignedLongValue] / 1024 / 1024);
    NSMutableArray *expirable = [NSMutableArray array];
    for (NSString *k in metaCopy) {
        CacheItem *ci = [metaItemsCopy objectForKey:k];
        if (ci == nil || !ci.used) {
            if (ci == nil) {
                ci = [self cachedWithKey:k];
            }
            [expirable addObject:ci];
        }
    }
    // if we're going to expire stuff, lets get some headroom
    const float expireFactory = 0.95f;
    void(^expireFrom)(NSMutableArray *a) = ^(NSMutableArray *a) {
        [a sortUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"lastAccess" ascending:NO]]];
        while (needsExpiry(expireFactory) && a.count > 0) {
            CacheItem *toExpire = [a lastObject];
            [self.lock lock];
            [self.meta removeObjectForKey:toExpire.url];
            [self.metaItems removeObjectForKey:toExpire.url];
            [self.lock unlock];
            [[NSFileManager defaultManager] removeItemAtPath:[self.dir stringByAppendingPathComponent:toExpire.filename] error:nil];
            [metaCopy removeObjectForKey:toExpire.url];
            [metaItemsCopy removeObjectForKey:toExpire.url];
            totalBytes -= toExpire.length;
            [a removeLastObject];
            NSLog(@"removing expired item %@ size %ld", toExpire.filename, toExpire.length);
        }
    };
    expireFrom(expirable);
    if (!needsExpiry(expireFactory)) {
        return;
    }
    expirable = [[metaItemsCopy allValues] mutableCopy];
    expireFrom(expirable);
}

@end

