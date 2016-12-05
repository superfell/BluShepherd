//
//  CoverArtCache.m
//  BluShepherd
//
//  Created by Simon Fell on 12/4/16.
//  Copyright © 2016 Simon Fell. All rights reserved.
//

#import "CoverArtCache.h"

static NSString *metaFilename = @"meta.dict";

static NSString *keyFilename = @"fn";
static NSString *keyLength = @"len";

@interface CacheItem()
-(id)initFromDictionary:(NSDictionary *)d;
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

@end

@interface CoverArtCache()

@property (retain) NSTimer *metaWriterTimer;
@property (retain) NSString *dir;

@property (retain) NSLock *lock;
@property (assign) BOOL dirty;
@property (retain) NSMutableDictionary *meta;

-(CacheItem *)cached:(NSURL *)url;
-(NSData *)load:(CacheItem *)item;

-(void)add:(NSData *)data withKey:(NSURL *)url replacing:(CacheItem *)existing;
-(NSString *)writeData:(NSData *)d;

-(void)writeMeta;

@end


@implementation CoverArtCache

-(id)initWithSession:(NSURLSession *)s {
    self = [super init];
    self.session = s;
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
        NSURLSessionTask *t = [self.session dataTaskWithURL:url
                               completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
                                   NSHTTPURLResponse *r = (NSHTTPURLResponse *)response;
                                   if ([r statusCode] != 200) {
                                       NSLog(@"Got error reading artwork %ld %@ \\ %@", [r statusCode], error, [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]);
                                   }
                                   else {
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
                               }];
        if (cachedData != nil) {
            t.priority = NSURLSessionTaskPriorityLow;
        }
        [t resume];
    });
}

-(CacheItem *)cached:(NSURL *)url {
    NSString *k = [url absoluteString];
    [self.lock lock];
    NSDictionary *c  = [self.meta objectForKey:k];
    [self.lock unlock];
    return c == nil ? nil : [[CacheItem alloc] initFromDictionary:c];
}

-(NSData *)load:(CacheItem *)i {
    NSData *d = [[NSData alloc] initWithContentsOfFile:[self.dir stringByAppendingPathComponent:i.filename]];
    return d;
}

-(void)add:(NSData *)data withKey:(NSURL *)url replacing:(CacheItem *)existing {
    CacheItem *i = [[CacheItem alloc] init];
    i.filename = [self writeData:data];
    i.length = [data length];
    NSDictionary *d = [i asDict];
    NSString *k = [url absoluteString];
    [self.lock lock];
    [self.meta setObject:d forKey:k];
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

@end

