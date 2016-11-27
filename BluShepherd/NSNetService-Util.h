//
//  NSNetService-Util.h
//  BluShepherd
//
// see http://stackoverflow.com/questions/938521/iphone-bonjour-nsnetservice-ip-address-and-port
//

#import <Foundation/Foundation.h>

@interface NSNetService (Util)
- (NSArray*) addressesAndPorts;
@end


@interface AddressAndPort : NSObject

@property (nonatomic, assign) int port;
@property (nonatomic, strong)  NSString *address;

@end