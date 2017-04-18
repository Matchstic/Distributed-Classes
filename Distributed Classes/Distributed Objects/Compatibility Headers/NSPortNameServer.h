#import <Foundation/NSObject.h>

@interface NSPortNameServer : NSObject

+ (id)defaultPortNameServer;
+ (id)systemDefaultPortNameServer;

- (id)portForName:(id)arg1;
- (id)portForName:(id)arg1 host:(id)arg2;
- (id)portForName:(id)arg1 onHost:(id)arg2;
- (BOOL)registerPort:(id)arg1 forName:(id)arg2;
- (BOOL)registerPort:(id)arg1 name:(id)arg2;
- (BOOL)removePortForName:(id)arg1;

@end