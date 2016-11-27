//
//  NSNetService-Util.m
//  BluShepherd
//
//  Created by Simon Fell on 11/26/16.
//  Copyright © 2016 Simon Fell. All rights reserved.
//

#import "NSNetService-Util.h"
#include <arpa/inet.h>

@implementation NSNetService (Util)

- (NSArray*) addressesAndPorts {
    // this came from http://stackoverflow.com/a/4976808/8047
    NSMutableArray *retVal = [NSMutableArray arrayWithCapacity:self.addresses.count];
    char addressBuffer[INET6_ADDRSTRLEN];
    
    for (NSData *data in self.addresses) {
        memset(addressBuffer, 0, INET6_ADDRSTRLEN);
        
        typedef union {
            struct sockaddr sa;
            struct sockaddr_in ipv4;
            struct sockaddr_in6 ipv6;
        } ip_socket_address;
        
        ip_socket_address *socketAddress = (ip_socket_address *)[data bytes];
        
        if (socketAddress && (socketAddress->sa.sa_family == AF_INET || socketAddress->sa.sa_family == AF_INET6)) {
            const char *addressStr = inet_ntop(
                                               socketAddress->sa.sa_family,
                                               (socketAddress->sa.sa_family == AF_INET ? (void *)&(socketAddress->ipv4.sin_addr) : (void *)&(socketAddress->ipv6.sin6_addr)),
                                               addressBuffer,
                                               sizeof(addressBuffer));
            
            int port = ntohs(socketAddress->sa.sa_family == AF_INET ? socketAddress->ipv4.sin_port : socketAddress->ipv6.sin6_port);
            
            if (addressStr && port) {
                AddressAndPort *aAndP = [[AddressAndPort alloc] init];
                aAndP.address = [NSString stringWithCString:addressStr encoding:kCFStringEncodingUTF8];
                aAndP.port = port;
                [retVal addObject:aAndP];
            }
        }
    }
    return retVal;
}


@end


@implementation AddressAndPort
@end