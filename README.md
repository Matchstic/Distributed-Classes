Distributed Classes
===================

Distributed Classes builds upon Distributed Objects to transparently allow multiple processes to share classes as if they were native to each process. These processes need not be running on the same machine, and can scale across networks.

Features
===================

  

Installation
===================

You can integrate Distributed Classes into your project in a number of ways:

1. Add via CocoaPods by adding:

    ```pod "DistributedClasses"```
    
to your Podfile

OR

2. Link in an appropriate static library from the Release page, copying in the headers from the ```include``` directory.

OR

3. Copy the source code to somewhere in your project, and drag ```Distributed Classes.xcodeproj``` into your Xcode project.

Usage
===================

Since this is a distributed system, you will need to initialise Distributed Classes in both the process acting as a server of classes, and the process acting as a client. Other than that, all you need to do to access a remote class in the client process is to reference it as follows:

```RemoteClass *object = [[$c(RemoteClass) alloc] init];```

With the main difference being the usage of ```$c()```.

Note that the following is for communication between processes on the **same machine**, which is only possible on macOS due to sandboxing on other platforms. The API is almost identical for communication inter-machine.

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

Further options are provided, such as a global handler block for when transmission and other such errors arise. Please see the Wiki on how to configure those.

Supported Platforms
===================

- macOS 10.7 or higher (tested: 10.11 -> 10.12)
- iOS 6.0 or higher (tested: 9.0 -> 10.2)
- tvOS 9.0 or higher (not tested on-device)

Known Limitations
===================

1. Objective-C blocks cannot be proxied between processes
2. C++ objects cannot be proxied between processes
3. IPv4 is not supported when connecting to a specified hostname+port
4. If the client or server process gets suspended when using the combined remote+local API, such as due to the user sleeping the device, the connection must be made again from scratch.
5. There is no specific response if a message's encryption doesn't match what the remote expects.

In addition, the limiting factor preventing support for e.g. GNUStep, mySTEP and WinObjC is mainly the library utilised for rebinding runtime symbols. Currently, this will only work for Mach-O executables.

License
===================

The GNU Lesser General Public License, v3.  
See LICENSES.md for the licenses of external code used within this library.
