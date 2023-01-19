# DumpBTM
tl;dr: an open-source version of `% sfltool dumpbtm`

```
% ./dumpBTM 
Dumps (unserializes) BackgroundItems-v*.btm

Opened /private/var/db/com.apple.backgroundtaskmanagement/BackgroundItems-v7.btm
...

========================
 Records for UID 501 : 1CAA5D2B-A526-49E2-9A6F-58CACBDF0AFB
========================

#1 
  UUID:              68D88F8B-A750-4A4D-AD31-520E2436FE9F
  Name:              LuLu
  Developer Name:    (null)
  Team Identifier:   VBG97UB4TA
  Type:              app  (0x2)
  Disposition:       [enabled allowed visible notified] (11)
  Indentifier:       anchor apple generic and identifier "com.objective-see.lulu.app" and (certificate leaf[field.1.2.840.113635.100.6.1.9] /* exists */ or certificate 1[field.1.2.840.113635.100.6.2.6] /* exists */ and certificate leaf[field.1.2.840.113635.100.6.1.13] /* exists */ and certificate leaf[subject.OU] = VBG97UB4TA)
  URL:               file:///Applications/LuLu.app/
  Executable Path:   (null)
  Generation:        2
  Parent Identifier: (null)
  
  #2 
  UUID:              17A60CB8-537A-44D1-A6F8-2EBD22439076
  Name:              AGSService
  Developer Name:    Adobe Creative Cloud
  Team Identifier:   JQ525L2MZD
  Type:              curated legacy daemon  (0x90010)
  Disposition:       [enabled allowed visible notified] (11)
  Indentifier:       Adobe_Genuine_Software_Integrity_Service
  URL:               file:///Library/LaunchDaemons/com.adobe.agsservice.plist
  Executable Path:   /Library/Application Support/Adobe/AdobeGCClient/AGSService
  Generation:        1
  Assoc. Bundle IDs: [com.adobe.acc.AdobeCreativeCloud]
  Parent Identifier: Adobe Creative Cloud
```

Note: If you're running the pre-built binary, though signed, it's not notarized (Apple doesn't support notarized commandline tools). So after making it executable, remove the quarantine attributue to make it runnable (via Terminal).

```
% chmod +x dumpBTM
% xattr -rc dumpBTM
```

Also, make sure you give Terminal "Full Disk Access" (a requirment to read the `BackgroundItems-v4.btm` file). 

In macOS Ventura (13), Apple consolidated persistent items (login items, launch agents/daemons) in a new file: `BackgroundItems-v*.btm`, found in `/private/var/db/com.apple.backgroundtaskmanagement/`. On macOS 13.0 this file is named `BackgroundItems-v*.btm` whereas on macOS 13.1 it's `BackgroundItems-v7.btm`.

This file is a serialized binary propertly list. You can dump it via Apple's `sfltool`, specifying the `dumpbtm` command line flag. 

`DumpBTM` is an open-source version of this, which has the following benefits:

* Open-source
* Programmatic access to enumerate (persistent) items in the file 

The latter point is most notable as this allow you to now add such logic into security/EDR tools. Specifically you can now easily and programmatically enumerate all (ok most) persistent items on a macOS Ventura system (which will include any persistently installed malware). 

You can also then monitor this file for changes to detect new persistence events (as now you can parse/unserialize its contents via this project's code). 

Note: Such monitoring was supposed to be accomplished via the Endpoint Security `ES_EVENT_TYPE_NOTIFY_BTM_LAUNCH_ITEM_ADD` event ...but this event is broken (See: "[Endpoint Security Event: ES_EVENT_TYPE_NOTIFY_BTM_LAUNCH_ITEM_ADD is ...broken?](https://developer.apple.com/forums/thread/720468)" 😓).
