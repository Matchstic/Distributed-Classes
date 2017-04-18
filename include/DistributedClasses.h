//
//  DistributedClasses.h
//  Distributed Classes
//
//  Created by Matt Clarke on 10/03/2017.
//  Copyright © 2017 Matt Clarke. All rights reserved.
//

/*
 * Distributed Classes is an RPC solution that allows for proxying meta-class objects over process and machine boundaries.
 *
 * The act of proxying a meta-class allows for any class defined in a remote process can be accessed as if it were native, 
 * _without_ prior needing to make the client aware of its existance.
 *
 * To access a remote class, there is a slight change in syntax to ensure the compiler doesn't complain:
 *
 *       $c(RemoteClass)
 *
 * e.g.,
 *
 *       RemoteClass *obj = [[$c(RemoteClass) alloc] init];
 *
 * To integrate nicely with Distributed Classes, add a #import to this header file in your prefix header (.pch).
 *
 * You'll also want to establish a connection from the client process to the server process that provides the classes
 * desired, along with establishing the server end.
 *
 * There are also optional error handling controls. By default, if Distributed Classes fails to send a messages, 
 * an exception will be raised. However, that's not a great way to handle an error, so you can specify a global block to be
 * called whenever an issue occurs; this covers any transmission errors. If you wish to forward an error through to the
 * code that first called on a remote method, simply return NO in this block to raise it as an exception.
 *
 * If connecting to a remote server over IPv4, please be aware that due to NAT and other weirdness this may fail. I 
 * recommend using IPv6 instead for this.
*/

#pragma mark Syntax definition

#import <objc/runtime.h>

// This is simply a wrapper around objc_getClass(), nothing fancy.
#define $c(var) objc_getClass(#var)

#pragma mark Imports

// Security module stuff.
#import "Security/DCNSBasicAuthentication.h"
#import "Security/DCNSConnection-Delegate.h"

// Server-side
#import "Server/DCNSServer.h"

// Client-side
#import "Client/DCNSClient.h"

// Errors
#import "DCNSAbstractError.h"
