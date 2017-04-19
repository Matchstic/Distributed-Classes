/* NSPortMessage interface for GNUstep
   Copyright (C) 1998 Free Software Foundation, Inc.
   
   Written by:  Richard frith-Macdonald <richard@brainstorm.co.Ik>
   Created: October 1998
   
   H.N.Schaller, Dec 2005 - API revised to be compatible to 10.4
 
   Fabian Spillner, July 2008 - API revised to be compatible to 10.5

   This file is part of the GNUstep Base Library.
   
   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Library General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.
   
   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Library General Public License for more details.
   
   You should have received a copy of the GNU Library General Public
   License along with this library; if not, write to the Free
   Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111 USA.
   */

#ifndef __NSPortMessage_h_GNUSTEP_BASE_INCLUDE
#define __NSPortMessage_h_GNUSTEP_BASE_INCLUDE

#import <Foundation/NSArray.h>
#import <Foundation/NSPort.h>

@interface NSPortMessage : NSObject
{
	unsigned		_msgid;
	NSPort			*_recv;
	NSPort			*_send;
	NSMutableArray	*_components;	// NSData or NSPort
}

- (NSArray *) components;
// - (id) initWithMachMessage:(void *) buffer;			// NOTE: does not initialize _recv and _send!
- (id) initWithSendPort:(NSPort *) aPort
			receivePort:(NSPort *) anotherPort
			 components:(NSArray *) items;
- (unsigned) msgid;
- (NSPort *) receivePort;
- (BOOL) sendBeforeDate:(NSDate *) when;
- (NSPort *) sendPort;
- (void) setMsgid:(unsigned) anId;

@end

#endif
