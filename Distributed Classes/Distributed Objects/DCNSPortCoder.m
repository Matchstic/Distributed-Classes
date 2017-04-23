/*
 NSPortCoder.m
 
 Implementation of NSPortCoder object for remote messaging
 
 Complete rewrite:
 Dr. H. Nikolaus Schaller <hns@computer.org>
 Date: Jan 2006-Oct 2009
 Some implementation expertise comes from Crashlogs found on the Internet: Google e.g. for "NSPortCoder sendBeforeTime:"
 Everything else from good guessing and inspecting data that is exchanged
 
 Updates to support cross-platform coding/decoding with iOS.
 Updates to provide security such as encryption and access controls.
 Author: Matt Clarke <psymac@nottingham.ac.uk>
 Date: December 2016
 
 This file is part of the mySTEP Library and is provided
 under the terms of the GNU Library General Public License.
 */

#import "DCNSPortCoder.h"
#import "DCNSPrivate.h"
#import "DCNSConnection-NSUndocumented.h"
#import <Foundation/NSArray.h>
#import <Foundation/NSDate.h>
#import "DCNSDistantObject.h"
#import <Foundation/NSInvocation.h>
#import <Foundation/NSMethodSignature.h>
#import <Foundation/NSRunLoop.h>
#import <Foundation/NSNull.h>
#import <Foundation/NSByteOrder.h>
#import <Foundation/NSDictionary.h>

#include <stdlib.h>
#include <ctype.h> // isdigit
#include <string.h>

#ifdef __APPLE__
// make us work on Apple objc-runtime

const char *objc_skip_typespec (const char *type);
int objc_alignof_type(const char *type);
int objc_sizeof_type(const char *type);
int objc_aligned_size(const char *type);
const char *objc_skip_offset (const char *type);

int objc_alignof_type(const char *type) {
    if(*type == _C_CHR)
        return 1;
    else
        return 4;
}

int objc_sizeof_type(const char *type) {
    switch(*type) {
        case _C_ID:
            return sizeof(id);
        case _C_CLASS:
            return sizeof(Class);
        case _C_SEL:
            return sizeof(SEL);
        case _C_PTR:
            return sizeof(void *);
        case _C_ATOM:
        case _C_CHARPTR:
            return sizeof(char *);
        case _C_ARY_B: {
            int cnt = 0;
            type++;
            while (isdigit(*type))
                cnt = 10*cnt+(*type++)-'0';
            return cnt*objc_sizeof_type(type);
        }
        case _C_UNION_B:
            // TODO: should get maximum size of all components
        case _C_STRUCT_B: {
            int cnt = 0;
            while(*type != 0 && *type != '=')
                type++;
            while(*type != 0 && *type != _C_STRUCT_E) {
                int objc_aligned_size(const char *type);
                cnt += objc_aligned_size(type);
                type = (char *) objc_skip_typespec(type);
            }
            return cnt;
        }
        case _C_VOID:
            return 0;
        case _C_CHR:
        case _C_UCHR:
            return sizeof(char);
        case _C_SHT:
        case _C_USHT:
            return sizeof(short);
        case _C_INT:
        case _C_UINT:
            return sizeof(int);
        case _C_LNG:
        case _C_ULNG:
            return sizeof(long);
        case _C_LNG_LNG:
        case _C_ULNG_LNG:
            return sizeof(long long);
        case _C_FLT:
            return sizeof(float);
        case _C_DBL:
            return sizeof(double);
        default:
#if DEBUG_LOG_LEVEL>=1
            NSLog(@"can't determine size of %s", type);
#endif
            return 0;
    }
}

int objc_aligned_size(const char *type) {
    int sz = objc_sizeof_type(type);
    if(sz%4 != 0)
        sz += 4-(sz%4);
    return sz;
}

const char *objc_skip_offset(const char *type) {
    while (isdigit(*type))
        type++;
    return type;
}

const char *objc_skip_typespec(const char *type) {
    switch(*type) {
        case _C_PTR:	// *type
            return objc_skip_typespec(type+1);
        case _C_ARY_B:	// [size type]
            type = objc_skip_offset(type+1);
            type = objc_skip_typespec(type);
            if(*type == _C_ARY_E)
                type++;
            return type;
        case _C_STRUCT_B:	// {name=type type}
            while(*type != 0 && *type != '=')
                type++;
            while(*type != 0 && *type != _C_STRUCT_E)
                type = objc_skip_typespec(type);
            if(*type != 0)
                type++;
            return type;
        default:
            return type+1;
    }
}

#endif

#import "DCNSPrivate.h"

/*
 this is how an Apple Cocoa request for [connection rootProxy] arrives in the first component of a NSPortMessage (with msgid=0)
 
 04									4 byte integer follows
 edfe1f 0e					0e1ffeed - appears to be some Byte-Order-mark and flags
 01 01							sequence number 1
 01									flag that value is not nil
 01									more classes follow
 01									1 byte integer follows
 0d									string len (incl. 00)
 4e53496e766f636174696f6e00			"NSInvocation"		class	- this payload encodes an NSInvocation
 00									flag that we don't encode version information
 01 01							Integer 1
 01									1 byte integer follows
 10									string len (incl. 00)
 4e5344697374616e744f626a65637400	"NSDistantObject"	self	- represents the 'target' component
 00
 00
 0101
 0101
 0201
 01									1 byte length follows
 0b									string len (incl. 00)
 726f6f744f626a65637400				"rootObject			_cmd	- appears to be the 'selector' component
 01
 01									1 byte length follows
 04									len (incl. 00)
 40403a00							"@@:"				signature (return type=id, self=id, _cmd=SEL)
 0140								@
 0100
 00									end of record
 
 You can set a breakpoint on -[NSPort sendBeforeDate:msgid:components:from:reserved:] to see what is going on
 */

// allows to define specific port-coding without changing the standard encoding (keyed/non-keyed)
@interface NSObject (NSPortCoding)
+ (int) _versionForPortCoder;	// return version to be provided during encoding - defaults to 0
- (void) _encodeWithPortCoder:(NSCoder *) coder;
- (id) _initWithPortCoder:(NSCoder *) coder;
@end

@implementation DCNSPortCoder

+ (DCNSPortCoder *)portCoderWithReceivePort:(NSPort *)recv sendPort:(NSPort *)send components:(NSArray *)cmp {
    return [[[self alloc] initWithReceivePort:recv sendPort:send components:cmp] autorelease];
}

// this method is not documented but exists (or at least did exist)!
- (void)sendBeforeTime:(NSTimeInterval)time sendReplyPort:(BOOL)flag {
    NSPortMessage *pm = [[NSPortMessage alloc] initWithSendPort:_send
                                                  receivePort:_recv
                                                   components:_components];
    NSDate *due = [NSDate dateWithTimeIntervalSinceReferenceDate:time];
    BOOL r;
    int _msgid = 0;
    
#if DEBUG_LOG_LEVEL>=2
    NSLog(@"DCNSPortCoder: -sendBeforeTime %@ msgid=%d replyPort:%d _send:%@ _recv:%@", due, _msgid, flag, _send, _recv);
#endif
    
    [pm setMsgid:_msgid];
    
    r = [pm sendBeforeDate:due];
    [pm release];
    
    if (!r)
        [NSException raise:NSPortTimeoutException format:@"Could not send request (within %.0lf seconds)", time];
}

- (void)dispatch {
    // Handle components either passed during initialization or received while sending
    NS_DURING
    if(_send == _recv)
        NSLog(@"DCNSPortCoder: -dispatch: receive and send ports must be different");	// should not be the same
    else {
        [[self connection] handlePortCoder:self];	// locate real connection and forward
    }
    NS_HANDLER
    NSLog(@"-[DCNSPortCoder dispatch]: %@", localException.callStackSymbols);
    [localException raise];
    NS_ENDHANDLER
}

- (DCNSConnection *)connection {
    // We don't cache the connection!
    
    // Get our connection object if it exists
    DCNSConnection *c = [DCNSConnection lookUpConnectionWithReceivePort:_recv sendPort:_send];
    
    // Create one if needed.
    if (!c)
        c = [[[DCNSConnection alloc] initWithReceivePort:_recv sendPort:_send] autorelease];
    
    return c;
}

- (instancetype)initWithReceivePort:(NSPort *)recv sendPort:(NSPort *)send components:(NSArray *)cmp {
    self = [super init];
    
    if(self) {
        NSData *first;
        NSAssert(recv, @"receive port");
        NSAssert(send, @"send port");
        
        // Provide a default object for encoding
        if(!cmp)
            _components = [[NSMutableArray alloc] initWithObjects:[NSMutableData dataWithCapacity:200], nil];
        else
            _components = [cmp retain];
        
        NSAssert(_components, @"components");
        
        _recv = [recv retain];
        _send = [send retain];
        first = [_components objectAtIndex:0];
        
        // Set read pointer
        _pointer = [first bytes];
        
        // Only relevant for decoding but initialize always
        _eod = (unsigned char *) [first bytes] + [first length];
    }
    return self;
}

- (void)dealloc {
    [self invalidate];
    [super dealloc];
}

- (BOOL)isBycopy { return _isBycopy; }
- (BOOL)isByref { return _isByref; }

#pragma mark Core encoding

- (void)_encodeInteger:(long long)val {
    NSMutableData *data = [_components objectAtIndex:0];
    union {
        long long val;
        unsigned char data[8];
    } d;
    signed char len = 8;
    
#if DEBUG_LOG_LEVEL>=3
    NSLog(@"encode %lld", val);
#endif
    
    // NOTE: this has been unit-tested to be correct on big and little endian machines
    d.val = NSSwapHostLongLongToLittle(val);
    
    if (val < 0) {
        while (len > 1 && d.data[len-1] == (unsigned char) 0xff)
            len--;	// get first non-0xff byte which determines length
        
        len = -len;	// encode by negative length
#if DEBUG_LOG_LEVEL>=2
        NSLog(@"DCNSPortCoder: -_encodeInteger len = %d", len);
#endif
        
    } else {
        while (len > 0 && d.data[len-1] == 0)
            len--;	// get first non-0 byte which determines length
    }
    
    // Encode length of int
    [data appendBytes:&len length:1];
    
    // Encode significant bytes
    [data appendBytes:&d.data length:len < 0 ? -len : len];
}

- (void)encodePortObject:(NSPort *)port {
    // psymac :: Check to ensure that we are actually trying to encode a port object.
    if (![port isKindOfClass:[NSPort class]]) {
        [NSException raise:NSInvalidArgumentException format:@"DCNSPortCoder: -encodePortObject: NSPort expected, got %@", port];
    }
    
    [(NSMutableArray *) _components addObject:port];
}

- (void)encodeArrayOfObjCType:(const char*)type count:(NSUInteger) count at:(const void*)array {
    int size = objc_sizeof_type(type);
    
#if DEBUG_LOG_LEVEL>=2
    NSLog(@"DCNSPortCoder: -encodeArrayOfObjCType %s count %lu size %d", type, (unsigned long)count, size);
#endif
    
    // FIXME: handle alignment
    if (size == 1) {
        // Encode bytes directly
        [[_components objectAtIndex:0] appendBytes:array length:count];
        return;
    }
    
    while(count-- > 0) {
        [self encodeValueOfObjCType:type at:array];
        array = size + (char *) array;
    }
}

- (void)encodeObject:(id)obj {
    Class class;
    id robj;
    signed char flag;
    
#if DEBUG_LOG_LEVEL>=3
    NSLog(@"DCNSPortCoder: -encodeObject%@%@ %@", _isBycopy?@" bycopy":@"", _isByref?@" byref":@"", obj);
#endif
    
    // Substitute by a proxy if required
    robj = [obj replacementObjectForPortCoder:self];
    flag = (robj != nil);
    
    if(![robj isProxy])
        class = [robj classForPortCoder];	// only available for NSObject but not for NSProxy
    else
        class = [robj class];

    // the first byte is the non-nil/nil flag
    [self encodeValueOfObjCType:@encode(signed char) at:&flag];
    
    if (flag) {
        // Encode class and version info
        int version;
        Class superclass;
        [self encodeValueOfObjCType:@encode(Class) at:&class];
        
        // Encode class and superclasses.
        // For some reason we can't call +version on NSProxy...
        if (![robj isProxy]) {
            flag = (version = (int)[class version]) != 0;

            if (flag) {
                // Main class is not version 0
                [self encodeValueOfObjCType:@encode(signed char) at:&flag];
                [self encodeValueOfObjCType:@encode(int) at:&version];
            }
            
            superclass = [class superclass];
            
            while (superclass != Nil) {
                // check
                version = (int)[superclass version];

                flag = (version != 0);
                
                if (flag) {
                    // receiver must be notified about version != 0
                    [self encodeValueOfObjCType:@encode(signed char) at:&flag];	// version is not 0
                    [self encodeValueOfObjCType:@encode(Class) at:&superclass];
                    [self encodeValueOfObjCType:@encode(int) at:&version];
                }
                
                // Go up one level
                superclass = [superclass superclass];
            }
        }
        
        // No more class version info follows
        flag = NO;
        [self encodeValueOfObjCType:@encode(signed char) at:&flag];
        
        if (class == [NSInvocation class])
            [self encodeInvocation:robj];
        else if (![robj isProxy] && [class instancesRespondToSelector:@selector(_encodeWithPortCoder:)])
            [robj _encodeWithPortCoder:self];	// this allows to define different encoding
        else
            [robj encodeWithCoder:self];	// translate and encode
        
        // It appears as if this is always YES
        flag = YES;
        [self encodeValueOfObjCType:@encode(signed char) at:&flag];
    }
    
#if DEBUG_LOG_LEVEL>=2
    NSLog(@"DCNSPortCoder: encodeObject -> %@", _components);
#endif
    
    // Reset flags for next encoder call
    _isBycopy = _isByref = NO;
}

- (void)encodeBycopyObject:(id)obj {
    _isBycopy = YES;
    [self encodeObject:obj];
}

- (void)encodeByrefObject:(id)obj {
    _isByref = YES;
    [self encodeObject:obj];
}

- (void)encodeBytes:(const void *)address length:(NSUInteger)numBytes {
    [self _encodeInteger:numBytes];
    [[_components objectAtIndex:0] appendBytes:address length:numBytes];
}

- (void)encodeDataObject:(NSData *)data {
    // called by NSData encodeWithCoder
    signed char flag = NO;
    [self encodeValueOfObjCType:@encode(signed char) at:&flag];
    [self encodeBytes:[data bytes] length:[data length]];
}

- (void)encodeValueOfObjCType:(const char *)type at:(const void *)address {
    // must encode in network byte order (i.e. bigendian)
    
    
#if DEBUG_LOG_LEVEL>=2
    NSLog(@"DCNSPortCoder: -encodeValueOfObjCType:'%s' at:%p", type, address);
#endif
    
    switch(*type) {
        case _C_VOID:
            return; // nothing to encode
        case _C_CONST:
            
            // mclarke :: Treat it as if there is no const.
            if (*type++ != '\0') {
                [self encodeValueOfObjCType:type at:address];
            }
            // END
            
            break;
        case _C_ID:	{
            switch(type[1]) {
                case _C_BYREF:
                    [self encodeByrefObject:*((id *)address)];
                    break;
                case _C_BYCOPY:
                    [self encodeBycopyObject:*((id *)address)];
                    break;
                default:
                    [self encodeObject:*((id *)address)];
                    break;
            }
            break;
        }
        case _C_CLASS: {
            Class c = *((Class *)address);
            signed char flag = YES;
            const char *class = c ? [NSStringFromClass(c) UTF8String] : "nil";
            
            [self encodeValueOfObjCType:@encode(signed char) at:&flag];
            if (class)
                [self encodeBytes:class length:strlen(class)+1];	// include terminating 0 byte
            break;
        }
        case _C_SEL: {
            SEL s = *((SEL *) address);
            signed char flag = (s != NULL);
            const char *sel = s != NULL ? [NSStringFromSelector(s) UTF8String] : "null";
            [self encodeValueOfObjCType:@encode(signed char) at:&flag];
            
            if (sel)
                [self encodeBytes:sel length:strlen(sel)+1];	// include terminating 0 byte
            break;
        }
        case _C_CHR:
        case _C_UCHR: {
            [[_components objectAtIndex:0] appendBytes:address length:1];	// encode character as it is
            break;
        }
        case _C_SHT:
        case _C_USHT: {
            [self _encodeInteger:*((short *) address)];
            break;
        }
        case _C_INT:
        case _C_UINT: {
            [self _encodeInteger:*((int *) address)];
            break;
        }
        case _C_LNG:
        case _C_ULNG: {
            [self _encodeInteger:*((long *) address)];
            break;
        }
        case _C_LNG_LNG:
        case _C_ULNG_LNG: {
            [self _encodeInteger:*((long long *) address)];
            break;
        }
        case _C_FLT: {
            NSMutableData *data = [_components objectAtIndex:0];
            
            // Test on PowerPC if we really swap or if we swap only when we decode from a different architecture
            // mclarke :: PPC is suitably old enough now (Nov 2016) to not worry too much about it.
            NSSwappedFloat val = NSSwapHostFloatToLittle(*(float *)address);
            
            char len = sizeof(float);
            [data appendBytes:&len length:1];
            [data appendBytes:&val length:len];
            break;
        }
        case _C_DBL: {
            NSMutableData *data = [_components objectAtIndex:0];
            NSSwappedDouble val = NSSwapHostDoubleToLittle(*(double *)address);
            char len = sizeof(double);
            [data appendBytes:&len length:1];
            [data appendBytes:&val length:len];
            break;
        }
        case _C_ATOM:
        case _C_CHARPTR: {
            char *str = *((char **)address);
            signed char flag = (str != NULL);
            [self encodeValueOfObjCType:@encode(signed char) at:&flag];
            
            if (flag) {
                [self encodeBytes:str length:strlen(str)+1];	// include final 0-byte
            }
            break;
        }
        case _C_PTR: {
            // Generic pointer
            
            // Load pointer
            void *ptr = *((void **) address);
            
            signed char flag = (ptr != NULL);
            [self encodeValueOfObjCType:@encode(signed char) at:&flag];
            
            if (flag)
                [self encodeValueOfObjCType:type+1 at:ptr];	// dereference pointer
            break;
        }
        case _C_ARY_B: {
            // Get number of entries from type encoding
            int cnt = 0;
            type++;
            
            while (*type >= '0' && *type <= '9')
                cnt = 10*cnt+(*type++)-'0';
            
            // FIXME: do we have to dereference?
            [self encodeArrayOfObjCType:type count:cnt at:address];
            break;
        }
        case _C_STRUCT_B: {
            // Recursively encode components! type is e.g. "{testStruct=c*}"
            
            while (*type != 0 && *type != '=' && *type != _C_STRUCT_E)
                type++;
            
            if (*type++ == 0)
                break;	// invalid
            
            while (*type != 0 && *type != _C_STRUCT_E) {
                int align = objc_alignof_type(type);
                
                // We must handle alignment before encoding and incrementing the address afterwards
                int off = (unsigned int) address%align;
                
                // Apply alignment
                if (off != 0) address = ((char *) address)+(align-off);

                [self encodeValueOfObjCType:type at:address];
                
                // Advance address by object size
                address = ((char *)address)+objc_aligned_size(type);
                
                // Next
                type = objc_skip_typespec(type);
            }
            break;
            // mclarke :: Added for cross-platform compatibility.
        case 'B': {
            // C++ BOOL.
            [self _encodeInteger:*((bool *) address)];
            break;
        }
        case _C_UNION_B:
        default:
            NSLog(@"DCNSPortCoder: can't encodeValueOfObjCType:%s", type);
            [NSException raise:NSPortReceiveException format:@"DCNSPortCoder: can't encodeValueOfObjCType:%s", type];
        }
    }
}

#pragma mark Core decoding

- (NSString *)_location {
    // Show current decoding location
    NSData *first = [_components objectAtIndex:0];
    
    const unsigned char *f = [first bytes];	// initial read pointer
    
    return [NSString stringWithFormat:@"%@ * %@", [first subdataWithRange:NSMakeRange(0, _pointer-f)], [first subdataWithRange:NSMakeRange(_pointer-f, _eod-_pointer)]];
}

// should know about expected length
// raise exception: more significant bytes (%d) than room to hold them (%d)

- (long long)_decodeInteger {
    union {
        long long val;
        unsigned char data[8];
    } d;
    int len;
    
    if (_pointer >= _eod)
        [NSException raise:NSPortReceiveException format:@"no more data to decode (%@)", [self _location]];
    
    len = *_pointer++;
    if (len < 0) {
        // fill with 1 bits
        len = -len;
        d.val = -1;	// initialize
    } else {
        d.val = 0;
    }
    
    // 8 bits to an integer.
    if (len > 8)
        [NSException raise:NSPortReceiveException format:@"invalid integer length (%d) to decode (%@)", len, [self _location]];
    
    if(_pointer+len > _eod)
        [NSException raise:NSPortReceiveException format:@"not enough data to decode integer with length %d (%@)", len, [self _location]];
    
    memcpy(d.data, _pointer, len);
    
    _pointer += len;
    return NSSwapLittleLongLongToHost(d.val);
}

- (NSPort *)decodePortObject {
    return NIMP;
}

- (void)decodeArrayOfObjCType:(const char*)type count:(NSUInteger)count at:(void*)array {
    int size = objc_sizeof_type(type);
    
    if (size == 1) {
        if (_pointer+count >= _eod)
            [NSException raise:NSPortReceiveException format:@"not enough data to decode byte array"];
        
        memcpy(array, _pointer, count);
        _pointer += count;
        
        return;
    }
    
    while (count-- > 0) {
        [self decodeValueOfObjCType:type at:array];
        array = size + (char *) array;
    }
}

- (id)decodeObject {
    return [[self decodeRetainedObject] autorelease];
}

- (void *)decodeBytesWithReturnedLength:(NSUInteger *)numBytes {
    NSData *d = [self decodeDataObject];	// will be autoreleased
    if (numBytes)
        *numBytes = (unsigned int)[d length];
    
    return (void *) [d bytes];
}

- (NSData *)decodeDataObject {
    // Get next object as it is
    unsigned long len = (unsigned long)[self _decodeInteger];
    NSData *d;
    
    if(_pointer+len > _eod)
        [NSException raise:NSPortReceiveException format:@"not enough data to decode data (length=%lul): %@", len, [self _location]];
    
    // retained copy...
    d = [NSData dataWithBytes:_pointer length:len];
    _pointer += len;
    
    return d;
}

/*
 * FIXME: make robust
 * it must not be possible to create arbitraty objects (type check)
 * it must not be possible to overwrite arbitrary memory (code injection, buffer overflows)
 */

- (void)decodeValueOfObjCType:(const char *)type at:(void *)address {
    // Encoded in network byte order (i.e. bigendian)
    
#if DEBUG_LOG_LEVEL>=2
    NSLog(@"NSPortCoder decodeValueOfObjCType:%s at:%p", type, address);
#endif
    
    switch(*type) {
        case _C_VOID:
            return;	// nothing to decode
        case _C_CONST:
            
            // mclarke :: Recursion to support const decoding.
            if (*type++ != '\0') {
                [self decodeValueOfObjCType:type at:address];
            }
            // END
            
            break;
            
        case _C_ID: {
            // Caller is responsible for releasing!
            *((id *)address) = [self decodeRetainedObject];
            return;
        }
        case _C_CLASS: {
            signed char flag;
            Class class = nil;
            
            [self decodeValueOfObjCType:@encode(signed char) at:&flag];
            
            if (flag) {
                NSUInteger len;
                char *str = [self decodeBytesWithReturnedLength:&len];	// include terminating 0 byte
                
                // check if last byte is 00
                
                NSString *s = [NSString stringWithUTF8String:str];
                
                // May not really be needed unless someone defines a class named "Nil"
                if (![s isEqualToString:@"Nil"])
                    class = NSClassFromString(s);
            }
            *((Class *)address) = class;
            return;
        }
        case _C_SEL: {
            signed char flag;
            SEL sel = NULL;
            
            [self decodeValueOfObjCType:@encode(signed char) at:&flag];
            
            if (flag) {
                NSUInteger len;
                char *str = [self decodeBytesWithReturnedLength:&len];	// include terminating 0 byte
                
                // check if last byte is really 00
                
                NSString *s = [NSString stringWithUTF8String:str];
                sel = NSSelectorFromString(s);
            }
            *((SEL *)address) = sel;
            return;
        }
        case _C_CHR:
        case _C_UCHR: {
            if(_pointer >= _eod)
                [NSException raise:NSPortReceiveException format:@"not enough data to decode char: %@", [self _location]];
            
            *((char *) address) = *_pointer++;	// single byte
            break;
        }
        case _C_SHT:
        case _C_USHT: {
            *((short *) address) = [self _decodeInteger];
            break;
        }
        case _C_INT:
        case _C_UINT: {
            *((int *) address) = (int)[self _decodeInteger];
            break;
        }
        case _C_LNG:
        case _C_ULNG: {
            *((long *) address) = (long)[self _decodeInteger];
            break;
        }
        case _C_LNG_LNG:
        case _C_ULNG_LNG: {
            *((long long *) address) = [self _decodeInteger];
            break;
        }
        case _C_FLT: {
            NSSwappedFloat val;
            
            if (_pointer+sizeof(float) >= _eod)
                [NSException raise:NSPortReceiveException format:@"not enough data to decode float"];
            
            if (*_pointer != sizeof(float))
                [NSException raise:NSPortReceiveException format:@"invalid length to decode float"];
            
            memcpy(&val, ++_pointer, sizeof(float));
            
            _pointer += sizeof(float);
            
            *((float *) address) = NSSwapLittleFloatToHost(val);
            break;
        }
        case _C_DBL: {
            NSSwappedDouble val;
            
            if (_pointer+sizeof(double) >= _eod)
                [NSException raise:NSPortReceiveException format:@"not enough data to decode double"];
            
            if (*_pointer != sizeof(double))
                [NSException raise:NSPortReceiveException format:@"invalid length to decode double"];
            
            memcpy(&val, ++_pointer, sizeof(double));
            
            _pointer += sizeof(double);
            
            *((double *) address) = NSSwapLittleDoubleToHost(val);
            break;
        }
        case _C_ATOM:
        case _C_CHARPTR: {
            signed char flag;
            NSUInteger numBytes;
            void *addr;
            
            [self decodeValueOfObjCType:@encode(signed char) at:&flag];
            
            if (flag) {
                addr = [self decodeBytesWithReturnedLength:&numBytes];
                
                // Should check if the last byte is 00
            } else
                addr = NULL;
            
            // Store address (storage object is the bytes of an autoreleased NSData!)
            *((char **) address) = addr;
            break;
        }
        case _C_PTR: {
            signed char flag; // NIL-flag

            [self decodeValueOfObjCType:@encode(signed char) at:&flag];
            
            if (flag) {
                unsigned len = objc_aligned_size(type+1);
                void *addr = malloc(len);
                if(addr) {
                    [NSData dataWithBytesNoCopy:addr length:len];	// take autorelease-ownership

                    [self decodeValueOfObjCType:type+1 at:addr];	// decode object pointed to
                }
                *((void **) address) = addr;	// store address of buffer
            } else
                *((void **) address) = NULL;	// store NULL pointer
            
            break;
        }
        case _C_ARY_B: {
            // Get number of entries from type encoding
            int cnt = 0;
            
            type++;
            while (*type >= '0' && *type <= '9')
                cnt = 10*cnt+(*type++)-'0';
            
            // FIXME: should we return the address of a malloc() array? I.e. handle like _C_PTR?
            [self decodeArrayOfObjCType:type count:cnt at:address];
            break;
        }
        case _C_STRUCT_B: {
            // Recursively decode components! type is e.g. "{testStruct=c*}"
            
            while (*type != 0 && *type != '=' && *type != _C_STRUCT_E)
                type++;
            
            // Invalid
            if (*type++ == 0)
                break;
            
            while (*type != 0 && *type != _C_STRUCT_E) {
                // We must handle alignment before encoding and incrementing the address afterwards
                int align = objc_alignof_type(type);
                int off = (unsigned int) address%align;
                
                // Apply alignment
                if(off != 0) address = ((char *) address)+(align-off);

                [self decodeValueOfObjCType:type at:address];
                
                // Advance address by object size
                address = ((char *)address)+objc_aligned_size(type);
                
                // next
                type = objc_skip_typespec(type);
            }
            break;
        }
        case _C_UNION_B:
        default:
            NSLog(@"DCNSPortCoder: -decodeValueOfObjCType: can't decodeValueOfObjCType:%s", type);
            [NSException raise:NSPortReceiveException format:@"can't decodeValueOfObjCType:%s", type];
    }
}

- (NSInteger)versionForClassName:(NSString *)className {
    // Can be called within initWithCoder to find out which version(s) to decode
    
    NSNumber *version = [_classVersions objectForKey:className];
    if (version)
        return [version intValue];	// defined by sender
    
    return [[self connection] versionForClassNamed:className];
}

@end

@implementation DCNSPortCoder (NSConcretePortCoder)

- (void)invalidate {
    // release internal data and references to _send and _recv ports
    [_recv release];
    _recv=nil;
    [_send release];
    _send=nil;
    [_components release];
    _components=nil;
    [_imports release];
    _imports=nil;
}

- (NSArray *)components {
    return _components;
}

- (void)encodeReturnValue:(NSInvocation *)i {
    // Encode the return value as an object with correct type
    NSMethodSignature *sig = [i methodSignature];
    
    if ([sig methodReturnLength] > 0) {
        // Allocate a buffer
        void *buffer = malloc([sig methodReturnLength]);
        
        // Get value
        [i getReturnValue:buffer];

        [self encodeValueOfObjCType:[sig methodReturnType] at:buffer];
        
        free(buffer);
    }
}

- (void)decodeReturnValue:(NSInvocation *)i {
    // Decode object as return value into existing invocation so that we can finish a forwardInvocation:
    NSMethodSignature *sig = [i methodSignature];
    
    if ([sig methodReturnLength] > 0) {
        // allocate a buffer
        void *buffer = malloc([sig methodReturnLength]);

        [self decodeValueOfObjCType:[sig methodReturnType] at:buffer];
        
        // set value
        [i setReturnValue:buffer];
        
        // FIXME: autorelease? or release on -dealloc of NSInvocation
        free(buffer);
    }
}

/* FIXME: This should be implemented in NSInvocation to have direct access to the iVars
 * i.e. call some private [i encodeWithCoder:self]
 *
 * This would also eliminate the detection of the Class during encodeObject/decodeObject
 *
 * DOC says: NSInvocation also conforms to the NSCoding protocol, i.e has encodeWithCoder!
*/

- (void)encodeInvocation:(NSInvocation *)i {
    NSMethodSignature *sig = [i methodSignature];
    unsigned char len = [sig methodReturnLength];	// this should be the length really allocated
    id target = [i target];
    SEL selector = [i selector];
    int j;
    
    // Allocate a buffer
    void *buffer = malloc(MAX([sig frameLength], len));
    
    // Encode arguments (incl. target&selector)
    int cnt = (int)[sig numberOfArguments];
    
    // NOTE: if we move this to NSInvocation we don't even need the private methods
    //const char *type = [sig _methodType];	// would be a little faster
    const char *type = [[sig _typeString] UTF8String];

    [self encodeValueOfObjCType:@encode(id) at:&target];
    
    // Argument count
    [self encodeValueOfObjCType:@encode(int) at:&cnt];
    [self encodeValueOfObjCType:@encode(SEL) at:&selector];
    
    // Method type
    [self encodeValueOfObjCType:@encode(char *) at:&type];

    NS_DURING
    
    // Get value
    // mclarke :: Added error checking on the return type's length.
    if (len > 0)
        [i getReturnValue:buffer];
    // END
    
    NS_HANDLER
    
    // Not needed if we implement encoding in NSInvocation
#if DEBUG_LOG_LEVEL>=1
    // e.g. if [i invoke] did result in an exception!
    NSLog(@"DCNSPortCoder: -encodeInvocation: has no return value");
#endif
    
    len = 1;
    *(char *) buffer = 0x40;
    
    NS_ENDHANDLER
    // Encode the bytes of the return value (not the object/type which can be done by encodeReturnValue)
    [self encodeValueOfObjCType:@encode(unsigned char) at:&len];
    [self encodeArrayOfObjCType:@encode(char) count:len at:buffer];
    
    // encode arguments
    for (j = 2; j < cnt; j++) {
        // Set byRef & byCopy flags here
        [i getArgument:buffer atIndex:j];
        [self encodeValueOfObjCType:[sig getArgumentTypeAtIndex:j] at:buffer];
    }

    free(buffer);
}

- (NSInvocation *)decodeInvocation {
    /*
     * mclarke
     *
     * Ideally, here we would implement -initWithCoder on NSInvocation, which would be able
     * to nicely init a new NSInvocation from incoming data.
     *
     * eg, return [[[NSInvocation alloc] initWithCoder:portCoder] autorelease];
     */

    NSInvocation *i;
    NSMethodSignature *sig;
    void *buffer;
    char *type;
    int cnt;	// number of arguments (incl. target&selector)
    unsigned char len;
    id target;
    SEL selector;
    int j;
    
    [self decodeValueOfObjCType:@encode(id) at:&target];	// is retained
    [self decodeValueOfObjCType:@encode(int) at:&cnt];
    
#if DEBUG_LOG_LEVEL>=3
    NSLog(@"DCNSPortCoder: -decodeInvocation: %d arguments", cnt);
#endif
    
    [self decodeValueOfObjCType:@encode(SEL) at:&selector];
    [self decodeValueOfObjCType:@encode(char *) at:&type];
    
    // FIXME: we must check if it is big enough...
    // should set the buffer size internal to the NSInvocation
    [self decodeValueOfObjCType:@encode(unsigned char) at:&len];
    
#if 0
    type = translateSignatureFromNetwork(type);
#endif
    
    // Create NSInvocation
    sig = [NSMethodSignature signatureWithObjCTypes:type];
    i = [NSInvocation invocationWithMethodSignature:sig];
    
    // Allocate a buffer
    buffer = malloc(MAX([sig frameLength], len));
    
    // Decode byte pattern
    [self decodeArrayOfObjCType:@encode(char) count:len at:buffer];
    
    // psymac :: Added error checking to return value's length
    if (len > 0)
        [i setReturnValue:buffer];	// set value
    
    // Decode arguments
    for (j = 2; j < cnt; j++) {
        const char *type = [sig getArgumentTypeAtIndex:j];

        [self decodeValueOfObjCType:type at:buffer];
        
        // Set value
        [i setArgument:buffer atIndex:j];
        // FIXME: decoded id values are retained - are they retained again by setArgument? Not by default!
        //			if(*type == _C_ID)
        //				[(*(id *) buffer) autorelease];
    }
    
    [i setTarget:target];
    [target release];
    [i setSelector:selector];
    
    free(buffer);
    
#if DEBUG_LOG_LEVEL>=2
    NSLog(@"NSInvocation decoded");
#endif
    
    return i;
}

- (id)importedObjects {
    return _imports;
}

- (void)importObject:(id)obj {
    if (!_imports)
        _imports = [[NSMutableArray alloc] initWithCapacity:5];
    
    [_imports addObject:obj];
}

- (id)decodeRetainedObject {
    Class class;
    id obj;
    signed char flag;
    NSMutableDictionary *savedClassVersions;
    int version;
    
    // The first byte is the non-nil/nil flag
    [self decodeValueOfObjCType:@encode(signed char) at:&flag];
    if (!flag)
        return nil;
    
    [self decodeValueOfObjCType:@encode(Class) at:&class];
    
    if (!class) {
        // CHECKME: Class is nil so we can't convert it back into a NSString...
        [NSException raise:@"DCNSPortCoderException" format:@"Cannot decode class, as it is nil."];
        return nil; // psymac :: Is this reached?
    }
    
    // FIXME: This all is handled by [connection addClassNamed: version:]
    // But, how do we know to pop the stack?
    savedClassVersions = _classVersions;
    if (_classVersions)
        _classVersions = [_classVersions mutableCopy];
    else
        _classVersions = [[NSMutableDictionary alloc] initWithCapacity:5];
    
    // Version flag
    [self decodeValueOfObjCType:@encode(signed char) at:&flag];
    if (flag) {
        // Main class version is not 0
        [self decodeValueOfObjCType:@encode(int) at:&version];

        // Save class version
        [_classVersions setObject:[NSNumber numberWithInt:version] forKey:NSStringFromClass(class)];
        
        while (YES) {
            // Decode versionForClass info
            Class otherClass;
            
            // More-class flag
            [self decodeValueOfObjCType:@encode(signed char) at:&flag];
            if (!flag)
                break;
            
            // Another class folows
            [self decodeValueOfObjCType:@encode(Class) at:&otherClass];
            [self decodeValueOfObjCType:@encode(int) at:&version];

            // Save class version
            [_classVersions setObject:[NSNumber numberWithInt:version] forKey:NSStringFromClass(otherClass)];
        }
    }
    
    if (class == [NSInvocation class]) {
        // Special handling as long as we can't call initWithCoder: for NSInovocation
        obj = [[self decodeInvocation] retain];
    } else if ([class instancesRespondToSelector:@selector(_initWithPortCoder:)]) {
        // This allows to define a different encoding - currently used for NSString
        obj = [[class alloc] _initWithPortCoder:self];
    } else {
        // Allocate and load new instance
        obj = [[class alloc] initWithCoder:self];
    }
    
    // always 0x01 (?) - appears to be 0x00 for a reply; and there may be another object if flag == 0x01
    // almost always 1 - only seen as 0 in some NSInvocation and then the invocation has less data
    [self decodeValueOfObjCType:@encode(signed char) at:&flag];

    [_classVersions release];
    _classVersions = savedClassVersions;
    
    if (!obj)
        [NSException raise:@"DCNSPortCoderException" format:@"decodeRetainedObject: class %@ not instantiated %@", NSStringFromClass(class), [self _location]];

    return obj;
}

- (void)encodeObject:(id)obj isBycopy:(BOOL)isBycopy isByref:(BOOL)isByref {
    _isBycopy = isBycopy;
    _isByref = isByref;
    [self encodeObject:obj];
}

/*
 * mclarke
 *
 * The vast majority of my additions to this class are to be found in the below methods.
 */

- (void)authenticateWithDelegate:(id<DCNSConnectionDelegate>)delegate withSessionKey:(char*)key {
    if (delegate && [delegate respondsToSelector:@selector(authenticationDataForComponents:andSessionKey:)]) {
        NSData *data = [delegate authenticationDataForComponents:[self components] andSessionKey:key];
        
        if (!data)
            [NSException raise:NSGenericException format:@"Cannot return nil from -authenticationDataForComponents:"];
        
        [(NSMutableArray *) _components addObject:data];
    }
}

- (BOOL)verifyWithDelegate:(id<DCNSConnectionDelegate>)delegate withSessionKey:(char*)key {
    // Check if we have processed the full request
    
    if (delegate && [delegate respondsToSelector:@selector(authenticateComponents:withData:andSessionKey:)]) {
        NSArray *components = [self components];
        unsigned int len = (unsigned int)[components count];
        
        /*
         * mclarke
         *
         * For most authentication requests, there will only be two components - data, and credentials.
         */
        
        // Auth data is present within the components array.
        if (len >= 2) {
            // FIXME: what do we do with the other components?
            NSData *data = [components objectAtIndex:len-1];
            
            return [delegate authenticateComponents:components withData:data andSessionKey:key];
        }
        
        // psymac :: No authentication data. Assume verification should be allowed.
    }
    return YES;
}

-(void)decryptComponentsWithDelegate:(id<DCNSConnectionDelegate>)delegate andSessionKey:(char*)key {
    /*
     * mclarke
     *
     * Encrypted starts at an offset AFTER the flag and sequence number;
     * Data from this point is likely to be encrypted if there's a delegate, so we will
     * request it to be decrypted from _pointer -> end.
     */
    
    if (delegate && [delegate respondsToSelector:@selector(decryptData:andSessionKey:)]) {
        long offset = _pointer - (unsigned char *)[_components[0] bytes];
        
        // I hate memory management. Long live ARC!
        
        NSData *data = [NSData dataWithBytes:(void*)_pointer length:[_components[0] length]-offset];
        NSMutableData *final = [NSMutableData dataWithBytes:(void*)[_components[0] bytes] length:offset];
        
        NSData *decrypted = [delegate decryptData:data andSessionKey:key];
        
        // Along with updating components[0], we also are required to update _pointer to be at
        // offset.
        
        [final appendData:decrypted];
        
        NSMutableArray *mutable = [_components mutableCopy];
        [mutable replaceObjectAtIndex:0 withObject:final];
        
        _components = mutable;
        
        // Set read pointer
        _pointer = (unsigned char *)[_components[0] bytes] + offset;
        
        // Only relevant for decoding but initialize always
        _eod = (unsigned char *)[_components[0] bytes] + [_components[0] length];
    }
}

-(void)encryptComponentsWithDelegate:(id<DCNSConnectionDelegate>)delegate andSessionKey:(char*)key {
    /*
     * mclarke
     *
     * At this point, we will also request the delegate to encrypt the data from components[0] at
     * an offset AFTER the flag and sequence number.
     *
     * Note: For the initial DHKEx, this method won't actually get called, as we cannot encrypt
     * without first being aware of the shared key for the session.
     */
    
    if (delegate && [delegate respondsToSelector:@selector(encryptData:andSessionKey:)]) {
        unsigned char *point = (void*)[_components[0] bytes];
        
        for (int i = 0; i < 2; i++) { // We need to read the flag and sequence number.
            int len = *point++; // First byte is length.
            if (len < 0) {
                // fill with 1 bits
                len = -len;
            }
            
            // Read through value.
            point += len;
        }
        
        long offset = point - (unsigned char*)[_components[0] bytes];
        
        NSData *data = [NSData dataWithBytes:(void*)[_components[0] bytes]+offset length:[_components[0] length]-offset];
        NSMutableData *final = [NSMutableData dataWithBytes:(void*)[_components[0] bytes] length:offset];
        
        NSData *encrypted = [delegate encryptData:data andSessionKey:key];
        
        [final appendData:encrypted];
        
        NSMutableArray *mutable = [_components mutableCopy];
        [mutable replaceObjectAtIndex:0 withObject:final];
        
        _components = mutable;
    }
}

@end

@implementation NSObject (NSPortCoder)

// We must be able to override the version for classes like NSString
+ (int)_versionForPortCoder {
    return (int)[self version];
}

- (Class)classForPortCoder {
    return [self classForCoder];
}

- (id)replacementObjectForPortCoder:(DCNSPortCoder*)coder {
    // Default is to encode a local proxy. Some classes may prefer to create a copy of themselves,
    // such as NSString, NSArray, NSDictionary..., to improve perfomance.
    
    id rep = [self replacementObjectForCoder:coder];
    if (rep) {
        // This will be encoded and decoded into a remote proxy
        rep = [DCNSDistantObject proxyWithLocal:rep connection:[coder connection]];
    }
    
    return rep;
}

@end

@implementation NSTimeZone (NSPortCoding)

+ (int)_versionForPortCoder {
    return 1;
}

- (id)replacementObjectForPortCoder:(DCNSPortCoder*)coder {
    // Default is to encode bycopy
    if (![coder isByref])
        return self;
    
    return [super replacementObjectForPortCoder:coder];
}

@end

@implementation NSArray (NSPortCoding)

- (id)replacementObjectForPortCoder:(DCNSPortCoder*)coder {
    // Default is to encode bycopy
    if(![coder isByref])
        return self;
    
    return [super replacementObjectForPortCoder:coder];
}

@end

@implementation NSDictionary (NSPortCoding)

- (id)replacementObjectForPortCoder:(DCNSPortCoder*)coder {
    // Default is to encode bycopy
    if(![coder isByref])
        return self;
    
    return [super replacementObjectForPortCoder:coder];
}

@end

@implementation NSNull (NSPortCoding)

- (id)replacementObjectForPortCoder:(DCNSPortCoder*)coder {
    // Default is to encode bycopy
    if(![coder isByref])
        return self;
    
    return [super replacementObjectForPortCoder:coder];
}

@end

@implementation NSData (NSPortCoding)

// Class cluster
- (Class)classForPortCoder {
    return [NSData class];
}

- (id)replacementObjectForPortCoder:(DCNSPortCoder*)coder {
    // Default is to encode bycopy
    if(![coder isByref])
        return self;
    
    return [super replacementObjectForPortCoder:coder];
}

// mclarke :: Changes to correctly encode/decode NSData

- (void)_encodeWithPortCoder:(NSCoder *)coder {
    const void *bytes = [self bytes];
    unsigned int len = (unsigned int)[self length];
    
    [coder encodeValueOfObjCType:@encode(unsigned int) at:&len];
    [coder encodeArrayOfObjCType:@encode(unsigned char) count:len at:bytes];
}

- (id)_initWithPortCoder:(NSCoder *)coder {
    void *bytes;
    unsigned int len;
    
    [coder decodeValueOfObjCType:@encode(unsigned int) at:&len];
    
    bytes = malloc(len);
    [coder decodeArrayOfObjCType:@encode(unsigned char) count:len at:bytes];
    
    self = [self initWithBytes:bytes length:len];
    free(bytes);
    
    return self;
}

// END

@end

@implementation NSMutableData (NSPortCoding)

// Class cluster
- (Class) classForPortCoder {
    return [NSMutableData class];
}

@end

#ifdef __mySTEP__
@interface NSDataStatic : NSData @end
@interface NSDataMalloc : NSDataStatic @end
@interface NSMutableDataMalloc : NSDataMalloc @end

@implementation NSMutableDataMalloc (NSPortCoding)
- (Class) classForPortCoder { return [NSMutableData class]; }	// class cluster
@end
#endif

@implementation NSString (NSPortCoding)

// We use the encoding version #1 as UTF8-String (with length but without trailing 0!)
+ (int)_versionForPortCoder {
    return 1;
}

// Class cluster
- (Class)classForPortCoder {
    return [NSString class];
}

- (id)replacementObjectForPortCoder:(DCNSPortCoder *)coder {
    // Default is to encode by copy
    if (![coder isByref])
        return self;
    
    return [super replacementObjectForPortCoder:coder];
}

- (void)_encodeWithPortCoder:(NSCoder *)coder {
    const char *str = [self UTF8String];
    unsigned int len=  (unsigned int)strlen(str);
    
    [coder encodeValueOfObjCType:@encode(unsigned int) at:&len];
    [coder encodeArrayOfObjCType:@encode(char) count:len at:str];
}

- (id)_initWithPortCoder:(NSCoder *)coder {
    char *str;
    unsigned int len;
    
    if([coder versionForClassName:@"NSString"] != 1)
        [NSException raise:NSInvalidArgumentException format:@"Can't decode version %ld of NSString", (long)[coder versionForClassName:@"NSString"]];
    
    [coder decodeValueOfObjCType:@encode(unsigned int) at:&len];

    str = malloc(len+1);
    [coder decodeArrayOfObjCType:@encode(char) count:len at:str];
    
    str[len] = 0;

    self = [self initWithUTF8String:str];
    free(str);
    
    return self;
}

@end

@implementation NSMutableString (NSPortCoding)

// Even for subclasses
- (Class)classForPortCoder	{
    return [NSMutableString class];
}

@end

#ifdef __mySTEP__
// Does not inherit from NSMutableString
@implementation GSMutableString (NSPortCoding)

// Even for subclasses
- (Class)classForPortCoder	{
    return [NSMutableString class];
}

@end
#endif

@implementation NSValue (NSPortCoding)

- (id)replacementObjectForPortCoder:(DCNSPortCoder*)coder {
    // Don't replace by another proxy, i.e. encode numbers bycopy
    return self;
}

@end

@implementation NSNumber (NSPortCoding)

- (id)replacementObjectForPortCoder:(DCNSPortCoder*)coder {
    // Don't replace by another proxy, i.e. encode numbers bycopy
    return self;
}

- (Class)classForPortCoder {
    // Class cluster
    return [NSNumber class];
}

@end

@implementation NSMethodSignature (NSPortCoding)

// It's not even clear if we can encode it at all!
- (id)replacementObjectForPortCoder:(DCNSPortCoder*)coder {
    // Don't replace by another proxy, i.e. encode method signatures bycopy (if at all!)
    return self;
}

@end

@implementation NSInvocation (NSPortCoding)

- (id)replacementObjectForPortCoder:(DCNSPortCoder*)coder {
    // Don't replace by another proxy, i.e. encode invocations bycopy
    return self;
}

@end

