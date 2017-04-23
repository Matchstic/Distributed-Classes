/*
 NSConnection.m
 
 Implementation of connection object for remote object messaging
 
 Copyright (C) 1994, 1995, 1996, 1997 Free Software Foundation, Inc.
 
 Created by:  Andrew Kachites McCallum <mccallum@gnu.ai.mit.edu>
 Date: July 1994
 OPENSTEP rewrite by: Richard Frith-Macdonald <richard@brainstorm.co.uk>
 Date: August 1997
 
 Changed to encode/decode NSInvocations:
 Dr. H. Nikolaus Schaller <hns@computer.org>
 Date: October 2003
 
 Complete rewrite:
 Dr. H. Nikolaus Schaller <hns@computer.org>
 Date: Jan 2006
 Some implementation expertise comes from from Crashlogs found on the Internet: Google for "Thread 0 Crashed dispatchInvocation" - and examples of "class dump"
 Everything else from good guessing and inspecting data that is exchanged
 Date: Oct 2009
 Heavily reworked to be more compatible to Cocoa
 Date: May 2012
 Debugged to be more compatible to Cocoa
 
 Heavily refactored for usage as standalone Distributed Objects.
 Added support for modular security
 Provided acknowledgement reciepts for data re-transmission
 Provided full multi-threading support
 Note that we now diverge from feature parity with Cocoa.
 Author: Matt Clarke <psymac@nottingham.ac.uk>
 Date: April 2017
 
 This file is part of the mySTEP Library and is provided
 under the terms of the GNU Library General Public License.
 */

#import <Foundation/NSRunLoop.h>
#import "DCNSConnection.h"
#import "DCNSConnection-NSUndocumented.h"
#import "DCNSConnection-NSPrivate.h"
#import "DCNSDistantObject.h"
#import "DCNSSocketPort.h"
#import "DCNSAbstractError.h"

#import "DCNSPrivate.h"

#import <Foundation/NSPort.h>
#import "DCNSPortCoder.h"

#import "DCNSDiffieHellmanUtility.h"

#import <Foundation/NSData.h>
#import <Foundation/NSArray.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSValue.h>
#import <Foundation/NSString.h>
#import <Foundation/NSDate.h>
#import <Foundation/NSException.h>
#import <Foundation/NSLock.h>
#import <Foundation/NSThread.h>
#import <Foundation/NSNotification.h>
#import <Foundation/NSInvocation.h>
#import <Foundation/NSMethodSignature.h>
#import <Foundation/NSAutoreleasePool.h>

#include <stdlib.h>

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Extra interfaces

@interface DCNSConnection (Private)

@end

@interface DCNSAbstractError (Private)
-(instancetype)initWithName:(NSString*)name reason:(NSString*)reason callStackSymbols:(NSArray*)callStackSymbols andUserInfo:(NSDictionary*)userinfo;
@end

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Defines

#define FLAGS_INTERNAL	0x0e2ffee2
#define FLAGS_REQUEST	0x0e1ffeed
#define FLAGS_RESPONSE	0x0e2ffece
#define FLAGS_ACK	    0x0e5ffefe

// Utilised when negotiating a session key.
#define FLAGS_DH_REQUEST 0x0e3ffeed
#define FLAGS_DH_RESPONSE 0x0e4ffece

// Default timeout used for timing out transmission of data (in seconds)
#define DEFAULT_TRANSMISSION_TIMEOUT 10.0
#define DEFAULT_ACK_ENABLED YES

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Function definitions

FOUNDATION_EXPORT NSMapTable *NSCreateMapTable(NSMapTableKeyCallBacks keyCallBacks, NSMapTableValueCallBacks valueCallBacks, NSUInteger capacity);

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Global variables

// Statistics
NSString *const DCNSConnectionRepliesReceived = @"kConnectionRepliesReceived";
NSString *const DCNSConnectionRepliesSent = @"kConnectionRepliesSent";
NSString *const DCNSConnectionRequestsReceived = @"kConnectionRequestsReceived";
NSString *const DCNSConnectionRequestsSent = @"kConnectionRequestsSent";

// Runloops
NSString *const DCNSConnectionReplyMode = @"NSDefaultRunLoopMode";

// Exceptions
NSString *const DCNSFailedAuthenticationException = @"DCNSFailedAuthenticationException";
NSString *const DCNSInvalidPortNameServerException = @"DCNSInvalidPortNameServerException";
NSString *const DCNSPortTimeoutException = @"DCNSPortTimeoutException";

// Notifications
NSString *const NSConnectionDidDieNotification = @"DCNSConnectionDidDieNotification";
NSString *const NSConnectionDidInitializeNotification = @"DCNSConnectionDidInitializeNotification";

// Errors
NSString *const DCNSConnectionErrorDomain = @"DCNSConnectionErrorDomain";

// Concurrency
static NSLock *_DCNSResponsesLock;
static NSLock *_DCNSAckLock;
static dispatch_semaphore_t _DCNSReceiveScheduleSem;

// A cache of known connections that are currently instiantated.
// This could/should use a NSMapTable keyed by a combination of receivePort and sendPort (e.g. string concatenation)
// Speed issues causes by this might be visible on server reponses time with multiple clients.
static NSHashTable *_allConnections;

// Sequence number for message ordering.
// Will 'tick over' after hitting the maximum integer.
static unsigned int _sequence;

@implementation DCNSConnection

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Object lifecycle

+ (void)initialize {
    if (!_DCNSResponsesLock) {
        _DCNSResponsesLock = [[NSLock alloc] init];
    }
    
    if (!_DCNSAckLock) {
        _DCNSAckLock = [[NSLock alloc] init];
    }
}

+ (DCNSConnection *)connectionWithReceivePort:(NSPort *)receivePort sendPort:(NSPort *)sendPort {
    return [[[self alloc] initWithReceivePort:receivePort sendPort:sendPort] autorelease];
}

+ (DCNSConnection *)connectionWithRegisteredName:(NSString *)name host:(NSString *)hostName usingNameServer:(NSPortNameServer *)server portNumber:(unsigned int)portnum {
    
#if DEBUG_LOG_LEVEL>=1
    NSLog(@"connectionWithRegisteredName:%@ host:%@ usingNameServer:%@", name, hostName, server);
#endif
    
    NSAssert(server != nil, @"A port nameserver must be provided!");
    
#if DEBUG_LOG_LEVEL>=1
    NSLog(@"server: %@", server);
#endif
    
    NSPort *sendPort;
    
    // We will proceed to find a port that can send to the service or hostname provided.
    if ([server respondsToSelector:@selector(portForName:host:nameServerPortNumber:)]) {
        sendPort = [(DCNSSocketPortNameServer*)server portForName:name host:hostName nameServerPortNumber:portnum];
    } else {
        sendPort = [server portForName:name host:hostName];
    }
    
    return [self connectionWithReceivePort:nil sendPort:sendPort];
}

+ (id)serviceConnectionWithName:(NSString *)name rootObject:(id)root usingNameServer:(NSPortNameServer *)server portNumber:(unsigned int)portnum {
    
    NSAssert(server != nil, @"A port nameserver must be provided!");
    
    // If we don't have a name server, assume we're running on the same device. We *must* use TCP/IP to
    // send data to localhost to avoid sandboxing for iOS.
    
    NSPort *port;

    if ([server isKindOfClass:NSClassFromString(@"NSMachBootstrapServer")])
        // Create a mach port with any port number
        port = [NSMachPort port];
    else if ([server isKindOfClass:[DCNSSocketPortNameServer class]])
        // Create a socket port with the provided port number.
        port = [[[DCNSSocketPort alloc] initWithTCPPort:portnum] autorelease];
    else {
        [NSException raise:DCNSInvalidPortNameServerException format:@"Unknown port nameserver class provided"];
    }
    
    DCNSConnection *connection = [DCNSConnection connectionWithReceivePort:port sendPort:port];	// create new connection
    [connection setRootObject:root];
    
    return connection;
}

- (id)init {
    // Init with default ports
    NSPort *port = [NSPort new];
    
    // Make a connection for vending objects.
    self = [self initWithReceivePort:port sendPort:port];
    
    // Clean up after ourselves.
    [port release];
    
    return self;
}

/*
 * We will consider some differing setups that define how the connection will behave:
 * 1. sendPort == nil or sendPort == receivePort
 *    We are only serving (vending) a rootObject
 * 2. receivePort == nil
 *    We are a client, so create a (unpublished) receivePort of the same class
 *
 * Furthermore, this method may be called when a server is creating a child connection
 * to handle a new client, or when either the client or server are initializing for the
 * first time.
 */
- (id)initWithReceivePort:(NSPort *)receivePort sendPort:(NSPort *)sendPort {
#if DEBUG_LOG_LEVEL>=2
    NSLog(@"DCNSConnection -initWithReceivePort:%@ sendPort:%@", receivePort, sendPort);
#endif
    
    // run +initialize
    [NSInvocation class];
    
    self = [super init];
    
    if (self) {
        NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
        
        _sessionKey = NULL;
        
        if (!sendPort) {
            // We have hit condition (1).
            
            if (!receivePort) {
                // neither port is defined
                NSLog(@"DCNSConnection -init: ERROR: Both ports are undefined, aborting.");
                
                [self release];
                return nil;
            }
            
            // Equate the two ports.
            sendPort = receivePort;
        } else if (!receivePort) {
            // We have hit condition (2).
            receivePort = [[[sendPort class] new] autorelease];
        }
        
        // First, we will check if a connection with these ports already exist. If so, we will
        // give the callee that instead.
        
        DCNSConnection *c = [DCNSConnection lookUpConnectionWithReceivePort:receivePort sendPort:sendPort];
        
        // Check if we already have a connection on these ports, and return that instead if so.
        if (c != nil) {
            
#if DEBUG_LOG_LEVEL>=1
            NSLog(@"DCNSConnection -init: connection exists");
#endif
            
            // We will use the existing object
            [self release];
            return [c retain];
        }
        
        // If a parent connection exists, then we should treat this call as the server creating a new
        // DCNSConnection to handle a client connecting. Otherwise, we'll treat it as either a client
        // connecting to a server, or the server initializing.
        c = [DCNSConnection lookUpConnectionWithReceivePort:receivePort sendPort:receivePort];
        
        if (receivePort != sendPort && c) {
            
#if DEBUG_LOG_LEVEL>=1
            NSLog(@"DCNSConnection -init: parent connection exists, make new connection");
#endif

            // Copy data from parent connection.
            
            self.receivePort = [receivePort retain];
            self.sendPort = [sendPort retain];
            self.rootObject = [c.rootObject retain];
            self.delegate = c.delegate;
            _modes = [c->_modes mutableCopy];		// we share the receivePort which is already scheduled in these modes and runloops
            _runLoops = [c->_runLoops mutableCopy];
            self.transmissionTimeout = c.transmissionTimeout;
            self.acksEnabled = c.acksEnabled;
        } else {
            // Alright, can actually make a brand new connection then.
            
#if DEBUG_LOG_LEVEL>=1
            NSLog(@"DCNSConnection -init: creating connection from scratch");
#endif
            self.receivePort = [receivePort retain];
            self.sendPort = [sendPort retain];
            
            _modes = [[NSMutableArray alloc] initWithCapacity:10];
            _runLoops = [[NSMutableArray alloc] initWithCapacity:10];
            self.transmissionTimeout = DEFAULT_TRANSMISSION_TIMEOUT; // default timeout.
            self.acksEnabled = DEFAULT_ACK_ENABLED; // default acks state
            
            // The receiving port is now scheduled on its own runloop. We should wait until that actually
            // occurs before continuing any further.
            _DCNSReceiveScheduleSem = dispatch_semaphore_create(0);
            
            [NSThread detachNewThreadSelector:@selector(scheduleReceivePortOnNewThread) toTarget:self withObject:nil];
            dispatch_semaphore_wait(_DCNSReceiveScheduleSem, DISPATCH_TIME_FOREVER);
        }
        
        // Make us respond to handlePortMessage:
        [self.receivePort setDelegate:self];
        
        // If the client disconnects or server goes down, we will be notified.
        [nc addObserver:self selector:@selector(_portInvalidated:) name:NSPortDidBecomeInvalidNotification object:self.sendPort];
        
        // Schedule the Ack timer for both new and children connections.
        [NSThread detachNewThreadSelector:@selector(scheduleAckTimerOnNewThread) toTarget:self withObject:nil];
        
        _isValid = YES;
        
        // Make us persistent at least until we are invalidated.
        [self retain];

        // Retain local proxies
        self.localObjects = NSCreateMapTable(NSNonRetainedObjectMapKeyCallBacks, NSObjectMapValueCallBacks, 10);
        
        // Don't retain these local proxies
        self.localObjectsByRemote = NSCreateMapTable(NSIntegerMapKeyCallBacks, NSNonRetainedObjectMapValueCallBacks, 10);
        
        // Retain remote proxies
        self.remoteObjects = NSCreateMapTable(NSIntegerMapKeyCallBacks, NSObjectMapValueCallBacks, 10);
        
        // Map sequence number to response portcoder when handling a port message.
        _responses = NSCreateMapTable(NSIntegerMapKeyCallBacks, NSObjectMapValueCallBacks, 10);
        
        // Create maps for Acks.
        self.pendingAcksToCachedDataMap = [NSMapTable mapTableWithKeyOptions:NSMapTableCopyIn
                                                                valueOptions:NSMapTableStrongMemory];
        self.pendingAcksToSendTimeMap = [NSMapTable mapTableWithKeyOptions:NSMapTableCopyIn
                                                                valueOptions:NSMapTableCopyIn];
        
        if (!_allConnections) {
            // Don't retain connections in hash table
            _allConnections = NSCreateHashTable(NSNonOwnedPointerHashCallBacks, 10);
        }
        
        // Add us to connections list
        NSHashInsertKnownAbsent(_allConnections, self);
        
        // And tell everyone we're now alive.
        [nc postNotificationName:NSConnectionDidInitializeNotification object:self];
        
#if DEBUG_LOG_LEVEL>=1
        NSLog(@"new DCNSConnection: %p send=%d recv=%d", self, [self.sendPort machPort], [self.receivePort machPort]);
#endif
    }
    return self;
}

- (void)invalidate {
#if DEBUG_LOG_LEVEL>=2
    NSLog(@"invalidate %p:%@ (_isValid=%d)", self, self, _isValid);
#endif
    
    if(!_isValid)
        return;	// already invalidated
    
    _isValid = NO;
    
    // Remove ourselves as an observer for port invalidation.
    [[NSNotificationCenter defaultCenter] removeObserver:self name:NSPortDidBecomeInvalidNotification object:self.sendPort];
    
    // Remove runloops
    unsigned int cnt = (unsigned int)[_runLoops count];
    while(cnt-- > 0) { // can't enumerate if we remove objects from the array
        NSRunLoop *rl=[_runLoops objectAtIndex:cnt];
        [self.sendPort removeFromRunLoop:rl forMode:DCNSConnectionReplyMode];
        [self removeRunLoop:rl];
    }
    
    // Post that we're no longer valid.
    [[NSNotificationCenter defaultCenter] postNotificationName:NSConnectionDidDieNotification object:self];
    
    if(_responses)
        NSFreeMapTable(_responses);
    _responses = nil;
    
    [self.receivePort release];
    self.receivePort = nil;
    
    [self.sendPort release];
    self.sendPort = nil;
    
    // Remove us from the connections table
    if(_allConnections) {
        //const char *key = [[NSString stringWithFormat:@"%d-%d", [self.sendPort machPort], [self.receivePort machPort]] UTF8String];
        //NSMapRemove(_allConnections, key);
        NSHashRemove(_allConnections, self);
    }
    
#if DEBUG_LOG_LEVEL>=1
    NSLog(@"DCNSConnection did invalidate %p", self);
#endif
    
    // This will dealloc when all other retains (e.g. in NSDistantObject) are done
    [self release];
}

- (void)dealloc {
    if(_isValid) {
        // this should not really occur since we are retained as an observer as long as we are valid!
        
        NSLog(@"DCNSConnection -dealloc: deallocating without invalidate: %p %@", self, self);
        abort();
        
        #pragma clang diagnostic push
        #pragma clang diagnostic ignored "-Wunreachable-code"
        [self invalidate];
        #pragma clang diagnostic pop
    }
    
#if DEBUG_LOG_LEVEL>=2
    NSLog(@"local objects count: %lu", (unsigned long)NSCountMapTable(self.localObjects));
    NSLog(@"remote objects count: %lu", (unsigned long)NSCountMapTable(self.remoteObjects));
#endif

    if(self.localObjects) {
#if DEBUG_LOG_LEVEL>=2
        NSLog(@"local objects=%@", NSAllMapTableValues(self.localObjects));
#endif
        NSAssert(NSCountMapTable(self.localObjects) == 0, @"local objects still use this connection"); // should be empty before we can be released...
        NSFreeMapTable(self.localObjects);
        NSFreeMapTable(self.localObjectsByRemote);
        
        self.localObjects = nil;
        self.localObjectsByRemote = nil;
    }
    
    if(self.remoteObjects) {
#if DEBUG_LOG_LEVEL>=2
        NSLog(@"remote objects=%@", NSAllMapTableValues(self.remoteObjects));
#endif
        NSAssert(NSCountMapTable(self.remoteObjects) == 0, @"remote objects still use this connection"); // should be empty before we can be released...
        NSFreeMapTable(self.remoteObjects);
        
        self.remoteObjects = nil;
    }
    
    if(_responses)
        NSFreeMapTable(_responses);
    
    if (self.pendingAcksToSendTimeMap) {
        [self.pendingAcksToSendTimeMap removeAllObjects];
        //[self.pendingAcksToSendTimeMap release];
        self.pendingAcksToSendTimeMap = nil;
        
        [self.pendingAcksToCachedDataMap removeAllObjects];
        //[self.pendingAcksToCachedDataMap release];
        self.pendingAcksToCachedDataMap = nil;
    }
    
    // releasing from all modes/runloops automatically unschedules the port!
    [_modes release];
    [_runLoops release];
    
    // we are already removed as receivePort observer by -invalidate
    [self.receivePort release];
    [self.sendPort release];
    [self.rootObject release];
    [_requestQueue release];
    
    // This is calloc'd.
    if (_sessionKey != NULL) {
        free(_sessionKey);
    }
    
    [super dealloc];
}

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Runloop shenanigans

- (void)addRequestMode:(NSString *)mode {
    // schedule additional mode in all known runloops
    [_modes addObject:mode];
    
    // Schedule ports in all available runloops.
    for (NSRunLoop *runLoop in _runLoops) {
        [self.receivePort scheduleInRunLoop:runLoop forMode:mode];
        
        if(self.receivePort != self.sendPort)
            [self.sendPort scheduleInRunLoop:runLoop forMode:mode];
    }
}

- (void)addPortsToRunLoop:(NSRunLoop *)runLoop {
    // First, schedule receivePort in passed runloop.
    [self.receivePort scheduleInRunLoop:runLoop forMode:DCNSConnectionReplyMode];
    
    // Then, schedule in all available runloops.
    for (NSString *mode in _modes) {
        [self.receivePort scheduleInRunLoop:runLoop forMode:mode];
    }
    
    // Same again for sendPort.
    if (self.receivePort != self.sendPort) {
        [self.sendPort scheduleInRunLoop:runLoop forMode:DCNSConnectionReplyMode];
        
        for (NSString *mode in _modes) {
            [self.sendPort scheduleInRunLoop:runLoop forMode:mode];
        }
    }
}

- (void)addRunLoop:(NSRunLoop *) runLoop {
    // schedule in new runloop in all known modes
    
#if DEBUG_LOG_LEVEL>=3
    NSLog(@"addRunLoop: %@ to %@", runLoop, _runLoops);
#endif
    
    if (![_runLoops containsObject:runLoop]) {
        [_runLoops addObject:runLoop];
        
        for (NSString *mode in _modes) {
            [self.receivePort scheduleInRunLoop:runLoop forMode:mode];
            
            if (self.receivePort != self.sendPort)
                [self.sendPort scheduleInRunLoop:runLoop forMode:mode];
        }
    }
}

- (void)removeRequestMode:(NSString*)mode {
    for (NSRunLoop *runLoop in _runLoops) {
        [self.receivePort removeFromRunLoop:runLoop forMode:mode];
        
        if(self.receivePort != self.sendPort)
            [self.sendPort removeFromRunLoop:runLoop forMode:mode];
    }
    
    [_modes removeObject:mode];
}

- (void)removePortsFromRunLoop:(NSRunLoop *)runLoop {
    [self.receivePort removeFromRunLoop:runLoop forMode:DCNSConnectionReplyMode];
    
    for (NSString *mode in _modes) {
        [self.receivePort removeFromRunLoop:runLoop forMode:mode];
    }

    if (self.receivePort != self.sendPort) {
        [self.sendPort removeFromRunLoop:runLoop forMode:DCNSConnectionReplyMode];
        
        for (NSString *mode in _modes) {
            [self.sendPort removeFromRunLoop:runLoop forMode:mode];
        }
    }
}

- (void)removeRunLoop:(NSRunLoop *)runLoop {
    if([_runLoops containsObject:runLoop]) {
        // remove from all modes
        for (NSString *mode in _modes) {
            // Only remove the receive port if this is the last connection left
            if ([_allConnections count] == 1)
                [self.receivePort removeFromRunLoop:runLoop forMode:mode];
            
            if(self.receivePort != self.sendPort)
                [self.sendPort removeFromRunLoop:runLoop forMode:mode];
        }
        
        [_runLoops removeObject:runLoop];
    }
}

-(void)scheduleReceivePortOnNewThread {
    [self addRequestMode:NSDefaultRunLoopMode];
    [self addRunLoop:[NSRunLoop currentRunLoop]];
    
#if DEBUG_LOG_LEVEL>=1
    NSLog(@"Scheduling receive port %@...", self.receivePort);
#endif
    
    dispatch_semaphore_signal(_DCNSReceiveScheduleSem);
    
    // Get that damn receive port running in a separate thread!
    [[NSRunLoop currentRunLoop] run];
}

- (void)scheduleAckTimerOnNewThread {
    NSTimer *pendingAckTimer = [NSTimer timerWithTimeInterval:0.25 target:self selector:@selector(pendingAckTimerDidFire:) userInfo:nil repeats:YES];
    [[NSRunLoop currentRunLoop] addTimer:pendingAckTimer forMode:NSDefaultRunLoopMode];
    
    [[NSRunLoop currentRunLoop] run];
}

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Service name registration (server-side)

- (BOOL)registerName:(NSString *)name withNameServer:(NSPortNameServer *)server portNumber:(unsigned int)portnum {
    // Return YES if registering this service worked.
    
    if (!_isValid)
        return NO;
    
    NSAssert(server != nil, @"Must give a valid port nameserver");
    
    if (!server)
        server = [NSPortNameServer systemDefaultPortNameServer]; // probably will give the Mach bootstrap server
    
    BOOL value = NO;
    if ([server respondsToSelector:@selector(registerPort:name:nameServerPortNumber:)]) {
        value = [(DCNSSocketPortNameServer*)server registerPort:self.receivePort name:name nameServerPortNumber:portnum];
    } else {
        value = [server registerPort:self.receivePort name:name];
    }
    
    if (!value) {
        NSLog(@"Cannot register name %@ with portnameserver (may be registered by other process)", name);
        return NO;
    }
    
    return YES;
}

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Initial connection establishment

- (id)rootObject {
#if DEBUG_LOG_LEVEL>=2
    NSLog(@"*** asked for rootObject:");
    NSLog(@"***   self=%p", self);
    NSLog(@"***   _cmd=%p", _cmd);
    NSLog(@"***   rootObject=%p", _rootObject);
#endif
    
    NSAssert(self != nil, @"self is not set correctly; NSInvocation may be broken");
    return _rootObject;
}

/*
 * mclarke
 *
 * The below two methods are represent the initial connection establishment.
 */

-(int)dhkexBWithGenerator:(int)g modulus:(int)p andA:(int)A {
    // We generate our B value and calculate the shared key for this session.
    
    int secb = [DCNSDiffieHellmanUtility generateSecret];
    int pubB = [DCNSDiffieHellmanUtility powermod:g power:secb modulus:p];
    int K = [DCNSDiffieHellmanUtility powermod:A power:secb modulus:p];
    
    _sessionKey = [DCNSDiffieHellmanUtility convertToKey:K];
    
    _sendNextDecryptedFlag = 1;
    
    return pubB;
}

- (DCNSDistantObject *)rootProxy {
    // This generates a proxy
    
    // Get first remote object (id == 0) which represents the NSConnection
    DCNSConnection *conn = (DCNSConnection *)[DCNSDistantObject proxyWithTarget:(id) 0 connection:self];
    
    // A session key is generated on ALL connections, regardless of if a security delegate is in use.
    int g = [DCNSDiffieHellmanUtility generatePrimeNumber];
    int p = [DCNSDiffieHellmanUtility generatePrimeNumber];
        
    if (g > p) {
        int swap = g;
        g = p;
        p = swap;
    }
        
    int seca = [DCNSDiffieHellmanUtility generateSecret];
    int pubA = [DCNSDiffieHellmanUtility powermod:g power:seca modulus:p];
        
    int B = [conn dhkexBWithGenerator:g modulus:p andA:pubA];
        
    int K = [DCNSDiffieHellmanUtility powermod:B power:seca modulus:p];
    _sessionKey = [DCNSDiffieHellmanUtility convertToKey:K];
    
    // This ends up in forwardInvocation: and asks other side for a reference to their root object
    DCNSDistantObject *proxy = [conn rootObject];
    
#if DEBUG_LOG_LEVEL>=1
    NSLog(@"root proxy: %@", proxy);
#endif
    
    return proxy;
}

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Getters, setters, and other object information requests

+ (NSArray *)allConnections {
    return NSAllHashTableObjects(_allConnections);
}

- (NSString *)description {
    return [NSString stringWithFormat:@"%p:%@\n  recv=%@\n  send=%@\n  root=%@\n  delegate=%@\n  modes=%@\n  timeout=%.2lf\n  flags:%@",
            self,
            NSStringFromClass(object_getClass(self)),
            self.receivePort,
            self.sendPort,
            self.rootObject,
            self.delegate,
            _modes,
            self.transmissionTimeout,
            [self isValid] ? @" valid" : @""
            ];
}

- (BOOL)isValid {
    return _isValid;
}

// the objects and not the proxies
- (NSArray *)knownLocalObjects {
    return NSAllMapTableKeys(self.localObjects);
}

- (NSArray *)knownRemoteObjects {
    return NSAllMapTableValues(self.remoteObjects);
}

- (NSArray *)requestModes {
    return _modes;
}

-(NSTimeInterval)ackTimeout {
    return (self.transmissionTimeout / 1.5);
}

- (void)setRootObject:(NSObject*)anObj {
    _rootObject = [anObj retain];
    
    if(anObj)
        [self addPortsToRunLoop:[_runLoops objectAtIndex:0]];	// TODO: checkme - loop over all???
    else
        [self removePortsFromRunLoop:[_runLoops objectAtIndex:0]];	// TODO: checkme - loop over all???
}

- (NSDictionary *)statistics {
    return [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedInt:_repliesReceived], @"DCDCNSConnectionRepliesReceived",
            [NSNumber numberWithUnsignedInt:_repliesSent], @"DCDCNSConnectionRepliesSent",
            [NSNumber numberWithUnsignedInt:_requestsReceived], @"DCDCNSConnectionRequestsReceived",
            [NSNumber numberWithUnsignedInt:_requestsSent], @"DCDCNSConnectionRequestsSent",
            nil
            ];
}

- (const char*)sessionKey {
    return _sessionKey;
}

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Error handling

- (void)_handleExceptionIfPossible:(NSException *)exception andRaise:(BOOL)raiseAgain {
    BOOL errorHandled = NO;
    
    if (self.globalErrorHandler) {
        DCNSAbstractError *error = [[[DCNSAbstractError alloc] initWithName:exception.name reason:exception.reason callStackSymbols:exception.callStackSymbols andUserInfo:exception.userInfo] autorelease];
        
        errorHandled = self.globalErrorHandler(error);
    }
    
    if (!errorHandled && raiseAgain) {
        // Re-raise the exception and cross everything that it'll get handled.
        // i.e, please don't die, that's not an enjoyable state of being.
        
        [exception raise];
    }
}

@end

@implementation DCNSConnection (NSUndocumented)

// found in http://opensource.apple.com/source/objc4/objc4-371/runtime/objc-sel-table.h

// private methods
// all of them have been identified to exist in MacOS X Core Dumps
// by Googling for 'NSConnection core dump'
// or class-dumps found on the net

// according to http://www.cocoabuilder.com/archive/cocoa/225353-distributed-objects-with-garbage-collection-on-ppc.html
// these also seem to set up and tear down the runloop scheduling

- (void)_incrementLocalProxyCount {
    if(_localProxyCount == 0) {
#if DEBUG_LOG_LEVEL>=2
        NSLog(@"first local proxy created");
#endif
    }
    _localProxyCount++;
}

- (void)_decrementLocalProxyCount {
    if (_localProxyCount != 0) {
        _localProxyCount--;
        if(_localProxyCount == 0) {
#if DEBUG_LOG_LEVEL>=2
            NSLog(@"last local proxy destroyed");
#endif
        }
    } else {
        NSLog(@"ERROR: Cannot decrement local proxy count, already at 0.");
    }
}

+ (DCNSConnection *)lookUpConnectionWithReceivePort:(NSPort *)receivePort sendPort:(NSPort *)sendPort {
    // Look up if we already know this connection
    
    // FIXME: this should use a NSMapTable with struct { NSPort *recv, *send; } as key/hash
    // but as long as we just have 2-3 connection objects this does not really matter
    
    if(_allConnections) {
        NSHashEnumerator e=NSEnumerateHashTable(_allConnections);
        DCNSConnection *c;
        while((c=(DCNSConnection *) NSNextHashEnumeratorItem(&e))) {
            if([c receivePort] == receivePort && [c sendPort] == sendPort)
                return c;	// found!
        }
        
    }
    return nil;	// not found
}

- (void)_portInvalidated:(NSNotification *)n {
#if DEBUG_LOG_LEVEL>=2
    NSLog(@"_portInvalidated: %@", n);
#endif
    
    [self invalidate];
}

- (id)newConversation {
    // Create a new object to denote the current conversation.
    return [NSObject new];
}

- (DCNSPortCoder *)portCoderWithComponents:(NSArray *)components {
    return [[[DCNSPortCoder alloc] initWithReceivePort:self.receivePort
                                            sendPort:self.sendPort
                                          components:components] autorelease];
}

/*
 * mclarke
 *
 * With regards to the _responses map, there is the potential for 2 entries for a given sequence number
 * due to the Ack sub-system. Thus, we should probably drop an entry if its not accessed within the timeout
 * specified for reply/request. Note that this doubling of entries won't affect performance other than taking
 * up unnecessary memory until it is dropped.
 */
- (void)sendInvocation:(NSInvocation *)i internal:(BOOL)internal {
    // send invocation and handle result - this might be called reentrant!
    
    BOOL isOneway = NO;
    
    NSRunLoop *rl = [NSRunLoop currentRunLoop];
    unsigned long flags = _sessionKey == NULL && self.delegate ? FLAGS_DH_REQUEST : FLAGS_REQUEST;
    DCNSPortCoder *portCoder;
    
#if DEBUG_LOG_LEVEL>=2
    NSLog(@"*** (conn=%p) sendInvocation:%@", self, i);
#endif
    
    NSAssert(i, @"Missing invocation to send");
    
    isOneway = [[i methodSignature] isOneway];
    portCoder = [self portCoderWithComponents:nil];	// for encoding
    
    // Increment sequence number for this conversation
    unsigned int currentSequence = ++_sequence;
    
    // Encode message metadata
    [portCoder encodeValueOfObjCType:@encode(unsigned long) at:&flags];
    [portCoder encodeValueOfObjCType:@encode(unsigned long) at:&currentSequence];
    
    // Encode invocation
    // CHECKME: Can we remove the encoding of nil?
    [portCoder encodeObject:i];
    [portCoder encodeObject:nil];
    [portCoder encodeObject:nil];
    
    // Cleanup, and encryption of payload if available.
    [self finishEncoding:portCoder];
    
    NS_DURING
    
    // Otherwise, we may be deallocated by -invalidate.
    [self retain];
    
#if DEBUG_LOG_LEVEL>=1
    NSLog(@"*** (conn=%p) send request to %@ (%d)", self, self.sendPort, [self.sendPort machPort]);
#endif
    
    // Set delegate as needed.
    [self.sendPort setDelegate:self];

    // Encode and send - raises exception on timeout.
    [portCoder sendBeforeTime:[NSDate timeIntervalSinceReferenceDate]+self.transmissionTimeout sendReplyPort:NO];
    _requestsSent++; // no need for concurrency here.
    
    // Setup Ack.
    [self setupPendingAckWithNumber:currentSequence andComponents:[portCoder components]];
    
    // Release internal memory immediately.
    [portCoder invalidate];
    
    if (!isOneway) {
        // Wait for response to arrive to -handlePortMessage:
        NSDate *until = [NSDate dateWithTimeIntervalSinceNow:self.transmissionTimeout];
        NSException *ex;
        
#if DEBUG_LOG_LEVEL>=2
        NSLog(@"*** (conn=%p) waiting for response before %@ in runloop %@ from %@ (%u)", self, [NSDate dateWithTimeIntervalSinceNow:self.transmissionTimeout], rl, _receivePort, [_receivePort machPort]);
#endif
        
        // Loop until we can extract a matching response for our sequence number from the receive queue...
        while(YES) {
            // Not yet timed out and current conversation is not yet completed
            
#if DEBUG_LOG_LEVEL>=2
            NSLog(@"*** (conn=%p) loop for response %u in %@ at %d", self, currentSequence, DCNSConnectionReplyMode, [_receivePort machPort]);
#endif
            
            if (![self isValid])
                [NSException raise:NSPortReceiveException format:@"Connection became invalid whilst sending data."];
            if (![self.receivePort isValid])
                [NSException raise:NSPortReceiveException format:@"Receiving port became invalid whilst sending data."];
            
            [_DCNSResponsesLock lock];
            portCoder = NSMapGet(_responses, INT2VOIDP(currentSequence));
            [_DCNSResponsesLock unlock];
            
            if (portCoder) {
                // The response we are waiting for has arrived!
                
                [portCoder retain];	// we will need it for a little time...
                
                [_DCNSResponsesLock lock];
                NSMapRemove(_responses, INT2VOIDP(currentSequence));
                [_DCNSResponsesLock unlock];
                
                break;	// break the loop and decode the response
            }
            
            // We now run the receiving port on its own thread.
            
#if DEBUG_LOG_LEVEL>=2
            NSLog(@"responses %@", NSAllMapTableValues(_responses));
#endif
            
            if([until timeIntervalSinceNow] < 0) {
                [NSException raise:DCNSPortTimeoutException format:@"Did not receive a response within %.0f seconds (sequence: %d)", self.transmissionTimeout, currentSequence];
            }
        }
#if DEBUG_LOG_LEVEL>=2
        NSLog(@"*** (conn=%p) runloop done for mode: %@", self, DCNSConnectionReplyMode);
#endif
        
        // what is this? most likely the Exception to raise
        ex = [portCoder decodeObject];
        
#if DEBUG_LOG_LEVEL>=2
        NSLog(@"ex=%@", ex);
#endif
        
        // Decode return value into our original invocation
        [portCoder decodeReturnValue:i];
        
        if(![portCoder verifyWithDelegate:self.delegate withSessionKey:_sessionKey]) {
            [portCoder invalidate];
            [portCoder release];
            [NSException raise:DCNSFailedAuthenticationException format:@"Authentication of server's response failed!"];
        }
        
        [portCoder invalidate];
        [portCoder release];
        
        // Raise if needed.
        [ex raise];
    } else {
#if DEBUG_LOG_LEVEL>=1
        NSLog(@"No need to wait for response because it is a oneway method call");
#endif
    }
    
    [self.sendPort removeFromRunLoop:rl forMode:DCNSConnectionReplyMode];
    [self release];
    
    NS_HANDLER
    
    [self.sendPort removeFromRunLoop:rl forMode:DCNSConnectionReplyMode];
    [self release];
    
    // Re-raise exception if needed
    [self _handleExceptionIfPossible:localException andRaise:YES];
    
    NS_ENDHANDLER
}

- (void) sendInvocation:(NSInvocation *)i {
    [self sendInvocation:i internal:NO];
}

- (void)dispatchWithComponents:(NSArray*)components {
    NIMP;
}

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Handling of any incoming data to this connection

/*
 * this trick works as follows:
 *
 * there is a NSPort listening for new connections
 * incoming accepted connections spawn a child NSPort
 * this child NSPort is reported as the receiver of the NSPortMessage
 * but NSConnections are identified by the listening NSPort (the
 *   one to be used for vending objects)
 * therefore NSConnection makes the listening port its own delegate
 *   so that the method implemented here is called
 * the newly accepted NSPort shares this delegate
 * now, since both call this delegate method, we end up here
 *   with self being always the listening port
 * which we can pass as the receiving port to the NSPortCoder
 * NSPortCoder's dispatch method looks up the connection based on the
 *   listening port (hiding the receiving port)
 *
 * this behaviour has also been observed here:
 *   http://lists.apple.com/archives/macnetworkprog/2003/Oct/msg00033.html
 */

- (void)handlePortMessage:(NSPortMessage *)message {
    // Handle a received port message
    
#if DEBUG_LOG_LEVEL>=2
    NSLog(@"### handlePortMessage:%@", message);
#endif
    
    if(!message)
        return;
    
    // Setup port coder with this message.
    [[DCNSPortCoder portCoderWithReceivePort:[message receivePort] sendPort:[message sendPort] components:[message components]] dispatch];
}

- (void) handlePortCoder:(DCNSPortCoder *) coder; {
    // Request received on this connection
    
    unsigned int flags;
    unsigned int seq;
    
    @autoreleasepool {
    
    /*
     * mclarke
     *
     * Before we go any further, we should request the delegate to decrypt the first set of components.
     * The initial two unsigned int however will NOT be encrypted, so that we can effectively work with
     * them as needed.
     *
     * Note also that authentication data WILL NOT be present on the very first request, nor will it
     * be encrypted in any way; this is so that we can effectively setup Diffie-Hellman to produce the
     * shared key for this session.
     *
     * DHKEx will utilise two additional flags; FLAGS_DH_REQUEST and FLAGS_DH_RESPONSE. These simply
     * define that there is no need to apply authentication challenges to these messages.
     *
     * Oh, and one more thing. We also additionally handle an Ack here of the remote receiving our last sent data.
     */
    
#if DEBUG_LOG_LEVEL>=1
        NSLog(@"%p: handlePortCoder: %@", self, coder);
#endif
    
        @try {
            [coder decodeValueOfObjCType:@encode(unsigned int) at:&flags];
#if DEBUG_LOG_LEVEL>=2
            NSLog(@"found flag = %d 0x%08x", flags, flags);
#endif
    
            [coder decodeValueOfObjCType:@encode(unsigned int) at:&seq];	// that is sequential (0, 1, ...)
    
#if DEBUG_LOG_LEVEL>=2
            NSLog(@"%p: found seq number = %d", self, seq);
#endif
    
            /*
             * Perform decryption of components if required and possible.
             */
            if (flags != FLAGS_DH_REQUEST && flags != FLAGS_DH_RESPONSE && flags != FLAGS_ACK && _sessionKey != NULL) {
                // Request portCoder to decrypt components.
                [coder decryptComponentsWithDelegate:self.delegate andSessionKey:_sessionKey];
            }
    
            switch(flags) {
                case FLAGS_INTERNAL:	// connection setup (just allocates this NSConnection)
                    break;
                case FLAGS_REQUEST:	// request received
                case FLAGS_DH_REQUEST:
                    _requestsReceived++;
                    [self handleRequest:coder sequence:seq];
                    
                    break;
                case FLAGS_RESPONSE:	// response received
                case FLAGS_DH_RESPONSE:
                    _repliesReceived++;
                    [_DCNSResponsesLock lock];
                    // Put response into sequence queue/dictionary
                    NSMapInsert(_responses, INT2VOIDP(seq), (void *) coder);
                    [_DCNSResponsesLock unlock];
                    
                    // We should also send back an Ack to let the remote know we have recieved their data.
                    // NOTE: We will do this on a seperate thread to keep the receive port thread clear.
                        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                            @try {
                                [self sendAckToRemote:seq];
                            } @catch (NSException *e) {
                                // This is a courtesy!
                                [self _handleExceptionIfPossible:e andRaise:NO];
                            }
                        });
                    
                    // Additionally, recieiving a response counts as an Ack.
                    // If not, we could have two messages sent to the remote, and only one may make it.
                    [self handleAckReceived:seq];
                    break;
                case FLAGS_ACK:
                    [self handleAckReceived:seq];
                    break;
                default:
                    NSLog(@"%p: unknown flags received: %08x", self, flags);
            }
        } @catch (NSException *e) {
            NSLog(@"Exception in handlePortCoder: %@", e.description);
            
            // We should now cleanup the portcoder.
            [coder invalidate];
            
            [self _handleExceptionIfPossible:e andRaise:NO];
        }
    }
}

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Handling of acknowledgements (Acks) of data receipt

- (void)handleAckReceived:(unsigned int)ackNumber {
    if (!self.acksEnabled)
        return;
    
    // Simply remove the Ack from both pending maps to ensure it won't be picked up in the next
    // firing of the Ack check timer.
    // NOTE: The ack number === the sequence number of the current request/response conversation.
    
    id key = [NSNumber numberWithInt:ackNumber];
    
    [_DCNSAckLock lock];
    [self.pendingAcksToCachedDataMap removeObjectForKey:key];
    [self.pendingAcksToSendTimeMap removeObjectForKey:key];
    [_DCNSAckLock unlock];
}

- (void)sendAckToRemote:(unsigned int)ackNumber {
    if (!self.acksEnabled)
        return;
    
    DCNSPortCoder *pc = [self portCoderWithComponents:nil];
    
    unsigned int flags = FLAGS_ACK;
    unsigned int seq = ackNumber;
    
    // Encode Ack data
    [pc encodeValueOfObjCType:@encode(unsigned int) at:&flags];
    [pc encodeValueOfObjCType:@encode(unsigned int) at:&seq];
    
    // Send Ack
    [pc sendBeforeTime:[NSDate timeIntervalSinceReferenceDate]+self.transmissionTimeout sendReplyPort:NO];
    
    // Cleanup
    [pc invalidate];
}

- (void)setupPendingAckWithNumber:(unsigned int)ackNumber andComponents:(NSArray*)components {
    if (!self.acksEnabled)
        return;
    
    // To store an Ack, simply add it to the two pending Ack maps. The Ack timeout timer will pick
    // them up as needed.
    // NOTE: We will treat the modification of these two maps as a critical section.
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        time_t currentTime = time(NULL);
    
        id key = [NSNumber numberWithInt:ackNumber];
    
        [_DCNSAckLock lock];
        [self.pendingAcksToSendTimeMap setObject:[NSNumber numberWithInt:(unsigned int)currentTime] forKey:key];
        [self.pendingAcksToCachedDataMap setObject:components forKey:key];
        [_DCNSAckLock unlock];
    });
}

- (void)pendingAckTimerDidFire:(NSTimer*)timer {
    if (!self.acksEnabled)
        return;
    
    time_t currentTime = time(NULL);
    
    // For all pending Acks that are past the timeout value, we should re-send their data.
    for (NSNumber *key in [[[self.pendingAcksToSendTimeMap keyEnumerator] allObjects] copy]) {
        time_t ackSendTime = (time_t)[[self.pendingAcksToSendTimeMap objectForKey:key] intValue];
        
        if (currentTime - ackSendTime > self.ackTimeout) {
            NSArray *components = (NSArray*)[self.pendingAcksToCachedDataMap objectForKey:key];
            
            // Re-send this coder, and also make sure to clear it from the pending acks to avoid a loop
            // of re-sending if the client goes dark.
            
            if (!_isValid) {
                [timer invalidate];
                return;
            }
            
            NSLog(@"[DCNSConnection] (%p) Re-sending data for sequence: %d", self, [key intValue]);
            
            DCNSPortCoder *coder = [self portCoderWithComponents:components];
            
            @try {
                [coder sendBeforeTime:[NSDate timeIntervalSinceReferenceDate]+self.transmissionTimeout sendReplyPort:NO];
            } @catch (NSException *e) {
                NSLog(@"[DCNSConnection] (%p) Failed to re-send data: %@", self, e);
            }
            [coder invalidate];
            
            // Clear this pending Ack.
            [_DCNSAckLock lock];
            [self.pendingAcksToCachedDataMap removeObjectForKey:key];
            [self.pendingAcksToSendTimeMap removeObjectForKey:key];
            [_DCNSAckLock unlock];
            
            // XXX: Not releasing the components since it will have been retained only by the map.
        }
    }
}

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Handling of incoming RPC requests

- (void)handleRequest:(DCNSPortCoder *)coder sequence:(int)seq {
    // What can/should we do with the sequence number? This is used to keep the order when queueing requests
    
    // Note that this may be called multiple times if the remote re-sends data due to an Ack timeout.
    // Thus, if the data is already stored for this sequence, just parrot it back again.
    // This avoids calling methods twice by accident.
    
    NSArray *components = (NSArray*)[self.pendingAcksToCachedDataMap objectForKey:[NSNumber numberWithInt:seq]];
    if (components) {
        // We have already been called and are waiting on an Ack from the remote.
        DCNSPortCoder *coder = [self portCoderWithComponents:components];
        
        [coder sendBeforeTime:[NSDate timeIntervalSinceReferenceDate]+self.transmissionTimeout sendReplyPort:NO];
        [coder invalidate];
        
        return;
    }
    
    NSInvocation *inv;
    NSException *exception;	// exception response (an NSException created in the current autorelease-pool)
    id imports = nil;
    NSMethodSignature *sig;
    DCNSDistantObjectRequest *req;
    BOOL enqueue;

#if DEBUG_LOG_LEVEL>=2
    NSLog(@"handleRequest (seq=%d): %@", seq, coder);
    NSLog(@"message=%@", [[coder components] objectAtIndex:0]);
#endif
    
    // CHECKME: could not confirm recently: the first remote call for [client rootProxy] passes nil here (to establish the connection?)
    inv = [coder decodeObject];
    
    if (inv) {
        NSMethodSignature *tsig;
        sig = [inv methodSignature];	// how the invocation was initialized
        
#if DEBUG_LOG_LEVEL>=3
        NSLog(@"inv.argumentsRetained=%@", [inv argumentsRetained]?@"yes":@"no");
        NSLog(@"inv.selector='%@'", NSStringFromSelector([inv selector]));
        NSLog(@"inv.target=%p", [inv target]);
        NSLog(@"inv.target.class=%@", NSStringFromClass([[inv target] class]));
        NSLog(@"inv.methodSignature.numberOfArguments=%lu", (unsigned long)[[inv methodSignature] numberOfArguments]);
        NSLog(@"inv.methodSignature.methodReturnLength=%lu", (unsigned long)[[inv methodSignature] methodReturnLength]);
        NSLog(@"inv.methodSignature.frameLength=%lu", (unsigned long)[[inv methodSignature] frameLength]);
        NSLog(@"inv.methodSignature.isoneway=%d", [[inv methodSignature] isOneway]);
        NSLog(@"inv.methodSignature.methodReturnType=%s", [[inv methodSignature] methodReturnType]);
#endif

        // CHECKME: do we really need to check that by creating yet another methodSignature object???
        tsig = [[inv target] methodSignatureForSelector:[inv selector]];
        
        if(![sig isEqual:tsig])
            [NSException raise:@"NSSignatureMismatchException" format:@"Local/remote signature mismatch: %@ vs. %@", sig, tsig];
        
        if (![self _cleanupAndAuthenticate:coder sequence:seq conversation:&_currentConversation invocation:inv raise:NO]) {
            // We have ourselves an issue now. The remote's authentication failed, so we should at this point
            // send an exception back to let them know.
            
            req = [[DCNSConcreteDistantObjectRequest alloc] initWithInvocation:inv conversation:_currentConversation sequence:seq importedObjects:imports connection:self];
            
            exception = [NSException exceptionWithName:DCNSFailedAuthenticationException reason:@"Authentication failed" userInfo:nil];
            [req replyWithException:exception];
            
            [req release];
            return;
        }
    }
    
    // This will allocate the conversation if needed and tell if we should dispatch immediately
    enqueue = ![self _shouldDispatch:&_currentConversation invocation:inv sequence:seq coder:coder];

    req = [[DCNSConcreteDistantObjectRequest alloc] initWithInvocation:inv conversation:_currentConversation sequence:seq importedObjects:imports connection:self];
    
    if (enqueue) {
        /* should not dispatch, i.e. enqueue
         *
         * Do we have a global queue or one per NSConnection? If local, why do we then save the connection 
         * within NSDistantObjectRequest?
         *
         * According to the description it appears there is one queue per NSThread shared by all NSConnections 
         * known to that NSThread.
         *
         * So... we should not have an iVar but use [[NSThread currentThread] threadDictionary]
         */
        
        if (!_requestQueue)
            _requestQueue = [NSMutableArray new];
        
        // Retain any NSDistantObject we have received
        [inv retainArguments];
        [_requestQueue addObject:req];
#if DEBUG_LOG_LEVEL>=1
        NSLog(@"*** (conn=%p) queued: %@", self, req);
#endif
        
        [req release];
        return;
    }
    
    while(YES) {
        inv = [req invocation];
            
#if DEBUG_LOG_LEVEL>=1
        NSLog(@"*** (conn=%p) request received ***", self);
#endif
        
        @try {
            // Make a call to the local object(s)
            [[req connection] dispatchInvocation:inv];
            
            // No exception was raised, nil it to be sure.
            exception = nil;
        } @catch (NSException *e) {
            // Dispatching did result in an exception
            exception = e;
        } @finally {
            // Reply, with exception if available.
            [req replyWithException:exception];
        }
        
#if DEBUG_LOG_LEVEL>=2
        NSLog(@"request queue %@", _requestQueue);
#endif
        
        [req release];
        
        if ([_requestQueue count] == 0)
            break;	// empty
        
        req = [[_requestQueue objectAtIndex:0] retain];
        [_requestQueue removeObjectAtIndex:0];	// pull next request from queue
    }
    
    [_currentConversation release];
    _currentConversation = nil;	// done
}

/*
 * NOTE: it has been verified by stack traces that an
 * invocation dispatched to a NSDistantObject target
 * will call -invoke twice, i.e. the NSDistantObject
 * will get a forwardInvocation: call because it does
 * not implement the method and that will result in
 * [i invokeWithTarget:[distantObject localObject]]
 */

- (void)dispatchInvocation:(NSInvocation *)i {
    
#if DEBUG_LOG_LEVEL>=1
    NSLog(@"DCNSConnection: -dispatchInvocation: %@", i);
#endif
    
#if DEBUG_LOG_LEVEL>=2
    NSLog(@"target=%p %@", [i target], NSStringFromClass([[i target] class]));
    NSLog(@"selector=%@", NSStringFromSelector([i selector]));
#endif
    
    // This is a workaround since our -invoke does not work as described in the comment NOTE above this method
    if ([[i target] isKindOfClass:[DCNSDistantObject class]]) {
        // This should only happen for local DCNSDistantObjects!
        [(DCNSDistantObject *) [i target] forwardInvocation:i];	// call with _local as the target
    } else {
        [i invoke];
    }
    
#if DEBUG_LOG_LEVEL>=2
    NSLog(@"DCNSConnection: done with -dispatchInvocation: %@", i);
#endif
}

- (BOOL)_cleanupAndAuthenticate:(DCNSPortCoder *)coder sequence:(unsigned int)seq conversation:(id *)conversation invocation:(NSInvocation *)inv raise:(BOOL)raise {
    BOOL r = [coder verifyWithDelegate:self.delegate withSessionKey:_sessionKey];
    
#if DEBUG_LOG_LEVEL>=3
    NSLog(@"DCNSConnection: -_cleanupAndAuthenticate: sequence=%u", seq);
#endif
    
    [coder invalidate];	// no longer needed
    
    if(!r && raise)
        [NSException raise:DCNSFailedAuthenticationException format:@"Authentication of request failed for connection %@ sequence %u on selector %@", self, seq, NSStringFromSelector([inv selector])];
    
    return r;
}

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Handling of sending RPC results as a response

- (void)returnResult:(NSInvocation *)result exception:(NSException *)exception sequence:(unsigned int)seq imports:(NSArray *)imports {
    NSMethodSignature *sig = [result methodSignature];
    BOOL isOneway = [sig isOneway];
    
#if DEBUG_LOG_LEVEL>=3
    NSLog(@"returnResult: %@", result);
    NSLog(@"   exception: %@", exception);
    NSLog(@"    sequence: %u", seq);
    NSLog(@"     imports: %@", imports);
#endif
    
    if(!isOneway) {
        // There is something to return.
        
        DCNSPortCoder *pc = [self portCoderWithComponents:nil];	// for encoding
        unsigned long flags = _sendNextDecryptedFlag ? FLAGS_DH_RESPONSE : FLAGS_RESPONSE;
        
#if DEBUG_LOG_LEVEL>=2
        NSLog(@"port coder=%@", pc);
#endif
        
        // Encode flag then sequence number
        [pc encodeValueOfObjCType:@encode(unsigned int) at:&flags];
        [pc encodeValueOfObjCType:@encode(unsigned int) at:&seq];
        
        [pc encodeObject:nil];	// is this the exception or the inout objects list?
        
        // Encode result (separately from NSInvocation)
        [pc encodeReturnValue:result];
        
        // Then, the exception if occured.
        [pc encodeObject:exception];

        [self finishEncoding:pc];
        
#if DEBUG_LOG_LEVEL>=2
        // CHECKME: is this timeout correct? We are sending a reply...
        NSLog(@"replyTimeout=%f", self.transmissionTimeout);
        NSLog(@"timeIntervalSince1970=%f", [[NSDate date] timeIntervalSince1970]);
        NSLog(@"timeIntervalSinceRefDate=%f", [[NSDate date] timeIntervalSinceReferenceDate]);
        NSLog(@"time=%f", [NSDate timeIntervalSinceReferenceDate]+self.transmissionTimeout);
#endif
        
#if DEBUG_LOG_LEVEL>=1
        NSLog(@"DCNSConnection: -returnResult: now sending %@", [pc components]);
#endif
        
        // Send response on sendPort
        [pc sendBeforeTime:[NSDate timeIntervalSinceReferenceDate]+self.transmissionTimeout sendReplyPort:NO];
        
        // Setup the Ack waiting.
        [self setupPendingAckWithNumber:seq andComponents:[pc components]];
        
        _repliesSent++;
        [pc invalidate];
        
#if DEBUG_LOG_LEVEL>=1
        NSLog(@"DCNSConnection: -returnResult: sent");
#endif
    }
}

- (void)finishEncoding:(DCNSPortCoder *)coder {
    if (0 == _sendNextDecryptedFlag && self.delegate && _sessionKey != NULL) {
        [coder authenticateWithDelegate:self.delegate withSessionKey:_sessionKey];
        [coder encryptComponentsWithDelegate:self.delegate andSessionKey:_sessionKey];
    } else {
        _sendNextDecryptedFlag = 0;
    }
}

- (BOOL)_shouldDispatch:(id *)conversation invocation:(NSInvocation *)invocation sequence:(unsigned int)seq coder:(NSCoder *)coder {
    /*
     * mclarke
     * I have fully stripped out the toggle for independant conversation queuing.
     */
    
    if (*conversation)
        return NO;	// must enqueue
    
    *conversation = [self newConversation];	// create new conversation
    return YES;	// but dispatch this call
}

- (BOOL)hasRunloop:(NSRunLoop *)obj {
    return [_runLoops indexOfObjectIdenticalTo:obj] != NSNotFound;
}

- (void)addClassNamed:(char *)name version:(int)version {
    NSLog(@"-[DCNSConnection addClassNamed:%s version:%d] - NOT IMPLEMENTED", name, version);
}

- (int)versionForClassNamed:(NSString *)className {
    Class class = NSClassFromString(className);
    if(!class)
        return (int)NSNotFound;	// unknown class
    
    return (int)[class version];	// default defined by class
}

@end

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Private methods to handle caching of remote/local proxies
// mclarke :: These remain unchanged from mySTEP.

@implementation DCNSConnection (NSPrivate)

- (DCNSDistantObject *)_getLocal:(id)target {
    // Get proxy object for local object - if known
    
#if DEBUG_LOG_LEVEL>=3
    NSLog(@"DCNSConnection: -_getLocal: %p", target);
#endif
    
    return NSMapGet(self.localObjects, (void *) target);
}

- (DCNSDistantObject *)_getLocalByRemote:(id)remote {
    // Get proxy object for local object - if known
    
    // we could do the NSConnection fallback here
    return NSMapGet(self.localObjectsByRemote, (void *) remote);
}

- (void)_addLocalDistantObject:(DCNSDistantObject *)obj forLocal:(id)target andRemote:(id)remote {
#if DEBUG_LOG_LEVEL>=3
    NSLog(@"DCNSConnection: -_addLocalDistantObject: forLocal: %p andRemote: %p", target, remote);
#endif
    
    NSMapInsert(self.localObjects, (void *) target, obj);
    NSMapInsert(self.localObjectsByRemote, (void *) remote, obj);
}

- (void)_removeLocalDistantObjectForLocal:(id)target andRemote:(id)remote {
#if DEBUG_LOG_LEVEL>=3
    NSLog(@"DCNSConncetion: -_removeLocalDistantObjectForLocal: %p andRemote: %p", target, remote);
#endif
    
    NSMapRemove(self.localObjectsByRemote, (void *) remote);
    NSMapRemove(self.localObjects, (void *) target);
}

// Map target id's (may be casted from int) to the distant objects.
// Note that the distant object retains this connection, but not vice versa!

- (DCNSDistantObject *)_getRemote:(id)target {
    // Get proxy for remote target - if known
    
#if DEBUG_LOG_LEVEL>=3
    NSLog(@"DCNSConnection: -_getRemote: %p", target);
#endif
    
    return NSMapGet(self.remoteObjects, (void *) target);
}

- (void)_addRemoteDistantObject:(DCNSDistantObject *)obj forRemote:(id)target {
#if DEBUG_LOG_LEVEL>=3
    NSLog(@"DCNSConnection: -_addRemoteDistantObject: forRemote: %p", target);
#endif
    
    NSMapInsert(self.remoteObjects, (void *) target, obj);
}

- (void)_removeRemoteDistantObjectForRemote:(id)target {
#if DEBUG_LOG_LEVEL>=3
    NSLog(@"DCNSConnection: -_removeRemoteDistantObjectForRemote: %p", target);
#endif
    
    NSMapRemove(self.remoteObjects, (void *) target);
}

@end

