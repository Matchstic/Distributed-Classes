Distributed Classes
===================

Distributed Classes builds upon Distributed Objects to transparently allow multiple processes to share classes as if they were native to each process. These processes need not be running on the same machine, and can scale across networks.

In a nutshell, provided you know the name of a class in one process, you can access it in another after setting up a connection between the two.

This library explores the technique of proxying class definitions, rather than instances of a class.

API reference for public header can be found [here](http://incendo.ws/projects/Distributed-Classes/), with all documentation on usage found in the [Wiki](https://github.com/Matchstic/Distributed-Classes/wiki/).

Features
===================

This library has the following features:

- Access to remote classes with only a slight syntax change (to avoid compiler complaints).
- Automatic discovery of processes providing classes on the local network via Bonjour.
- One-time connection, with no other code needed for a basic setup.
- Support for connecting to a given IPv6 hostname and port number (see limitations for IPv4).
- Optional global error handler, to avoid the need for adding code to catch potential transmission errors.
- Optional user-provided security, with a default of encrypting messages with ChaCha20+Poly1305.

You can also adjust the debug logging level of the system at compile-time, by changing the ```DEBUG_LOG_LEVEL``` value in ```DCNSPrivate.h```.

Installation
===================

You can integrate Distributed Classes into your project in a number of ways:

- Add via CocoaPods by adding:

    ```pod "DistributedClasses"```
    
to your Podfile

- Link in an appropriate static library from the Release page, copying in the headers from the ```include``` directory.

- Clone this repository (or add as a submodule if you're feeling adventurous) to somewhere in your project, and drag ```Distributed Classes.xcodeproj``` into your Xcode project.

Usage
===================

Since this is a distributed system, you will need to initialise Distributed Classes in both the process acting as a server of classes, and the process acting as a client. Other than that, all you need to do to access a remote class in the client process is to reference it as follows:

```RemoteClass *object = [[$c(RemoteClass) alloc] init];```

With the main difference being the usage of ```$c()```.

Note that the following is for communication between processes on the **same machine**, which is only possible on macOS due to sandboxing on other platforms. The API is almost identical for communication inter-machine, and can be found in the [Wiki](https://github.com/Matchstic/Distributed-Classes/wiki/API:-Init:-Inter-Machine).

To initialise the library in the **client process**, call:

```
NSError *error;
NSString *serviceName = @"<unique_name>";
[DCNSClient initialiseToLocalWithService:serviceName authenticationDelegate:auth andError:&error];
```

Where:  
```auth``` is either nil, or an object that responds to ```DCNSConnectionDelegate```, to provide modular security.  
```error``` will contain information about errors setting up the library, if any.  
```serviceName``` is a unique name the server process makes classes available on.  

In the **server process**, call:

```
NSError *error;
NSString *serviceName = @"<unique_name>";
[DCNSServer initialiseAsLocalWithService:serviceName authenticationDelegate:auth andError:&error];
```

Where:  
```auth``` is either nil, or an object that responds to ```DCNSConnectionDelegate```, to provide modular security.  
```error``` will contain information about errors setting up the library, if any.  
```serviceName``` is a unique name to make classes available on.  

And, that's it for a basic setup.

Further options are provided, such as a global handler block for when transmission and other such errors arise. Please see the [Wiki](https://github.com/Matchstic/Distributed-Classes/wiki) on how to configure those.

Supported Platforms
===================

- macOS 10.7 or higher (tested: 10.11 -> 10.12)
- iOS 6.0 or higher (tested: 9.0 -> 10.2)
- tvOS 9.0 or higher (not tested on-device)

Known Limitations
===================

1. Objective-C blocks cannot be proxied between processes
2. C++ objects cannot be proxied between processes
3. IPv4 is not supported when connecting to a specified hostname and port
4. If the client or server process gets suspended when using the inter-machine API, such as due to the user sleeping the device, the connection must be made again from scratch.
5. There is no specific response if the security module is different in the client process to the server process.

In addition, the limiting factor preventing support for e.g. GNUStep, mySTEP and WinObjC, is mainly the library utilised for rebinding runtime symbols. Currently, this will only work for Mach-O executables.

It's currently unknown if this library can be used in applications that are submitted to the App Store. 

License
===================

The GNU Lesser General Public License, v2.1.  
See LICENSES.md for the licenses of external code used within this library.
