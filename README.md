Distributed Classes
===================

Distributed Classes builds upon Distributed Objects to transparently allow multiple processes to share classes as if they were native to each process. These processes need not be running on the same machine, and can scale across networks.

Usage
===================



Features
===================




Supported Platforms
===================

- macOS 10.7 or higher (tested: 10.11 -> 10.12)
- iOS 6.0 or higher (tested: 9.0 -> 10.2)
- tvOS 9.0 or higher (not tested on-device)

Please note that the limiting factor preventing support for e.g. GNUStep, mySTEP and WinObjC is mainly the library utilised for rebinding runtime symbols. Currently, this will only work for mach-o executables.

Known Limitations
===================

1. Objective-C blocks cannot be proxied between processes
2. C++ objects cannot be proxied between processes
3. IPv4 is not supported when connecting to a specified hostname+port
4. If the client or server process gets suspended when using the combined remote+local API, such as due to the user sleeping the device, the connection must be made again from scratch.
5. There is no specific response if a message's encryption doesn't match what the remote expects.

Known Bugs/Issues
===================



License
===================

The GNU Lesser General Public License, v2.
See LICENSES.md for the licenses of external code used within this library.



