//
//  dumpBTM.m
//  dumpBTM (library)
//
//  Created by Patrick Wardle on 1/20/23.
//

// Note: Once compiled, header file (dumpBTM.h) and library (libDumpBTM.a)
//       are added to: $SRCROOT/lib/
//
//       Copy this header file  / link this library in your own project(s)!

#import <dlfcn.h>
#import "dumpBTM.h"
#import "dumpBT_Internal.h"

/* GLOBALS */

//handle to btm daemon
void* btmd = NULL;

/* FUNCTION DEF */

//helper
// convert ItemRecord to dictionary
NSDictionary* toDictionary(ItemRecord* record, NSArray* items);

//constructor
// load btm daemon (into our memory)
__attribute__((constructor)) static void initDumpBTM(void)
{
    //load btm daemon
    // its contains obj methods we need
    btmd = dlopen(BTM_DAEMON, RTLD_LAZY);
    
    return;
}

//load a btm file
// and init a NSKeyedUnarchiver for it
NSKeyedUnarchiver* load(NSURL** path)
{
    //error
    NSError* error = nil;
    
    //database data
    NSData* data = nil;
    
    //unarchiver
    NSKeyedUnarchiver* keyedUnarchiver = nil;
    
    //no (user-specified) path?
    // find/use system's btm path
    if(nil == *path)
    {
        //get btm path
        *path = getPath();
        if(nil == *path)
        {
            //err msg
            os_log_error(OS_LOG_DEFAULT, "ERROR: failed to find a .btm file in %{public}@", BTM_DIRECTORY);
            
            //bail
            goto bail;
        }
    }

    //load database *path
    // note: this will fail if client doesn't have full disk access
    data = [NSData dataWithContentsOfURL:*path options:0 error:&error];
    if(nil == data)
    {
        //err msg
        os_log_error(OS_LOG_DEFAULT, "ERROR: failed to open/load %{public}@", *path);
        
        //bail
        goto bail;
    }
    
    //init unachiver
    keyedUnarchiver = [[NSKeyedUnarchiver alloc] initForReadingFromData:data error:&error];
    
    //set decoding failure policy
    // will throw an exception if unserialization fails
    keyedUnarchiver.decodingFailurePolicy = NSDecodingFailurePolicyRaiseException;
        
bail:
    
    return keyedUnarchiver;
}

//deserialize
Storage* deserialize(NSURL* path)
{
    //'Storage' class
    Class StorageClass = nil;
    
    //'Storage' object
    Storage* storage = nil;
    
    //unarchiver
    NSKeyedUnarchiver* keyedUnarchiver = nil;
        
    //lookup 'Storage' class
    StorageClass = NSClassFromString(@"Storage");
    if(nil == StorageClass)
    {
        //err msg
        printf("ERROR: failed to find 'Storage' class\n\n");
        
        //bail
        goto bail;
    }
    
    //load btm file
    keyedUnarchiver = load(&path);
    if(nil == keyedUnarchiver)
    {
        //err msg
        printf("ERROR: failed to open/load %s\n\n", path.path.UTF8String);
        
        //bail
        goto bail;
    }
    
    //dbg msg
    printf("Opened %s\n\n", path.path.UTF8String);
    
    //wrap unserialization
    @try {
        
        //decode storage object
        // this in turn will decode all items
        storage = [keyedUnarchiver decodeObjectOfClass:StorageClass forKey:@"store"];
    }
    //exception
    @catch(NSException *exception) {
        
        //err msg
        printf("ERROR: unserializing failed with %s\n\n", exception.description.UTF8String);
        
        //bail
        goto bail;
    }
    
    //sanity check
    // iVar: 'itemsByUserIdentifier' and 'mdmPayloadsByIdentifier'
    if( (YES != [storage respondsToSelector:@selector(itemsByUserIdentifier)]) ||
        (YES != [storage respondsToSelector:@selector(mdmPayloadsByIdentifier)]) )
    {
        //err msg
        printf("ERROR: failed to find 'Storage' class's 'itemsByUserIdentifier' or 'mdmPayloadsByIdentifier' instance variables\n\n");
        
        //unset
        storage = nil;
        
        //bail
        goto bail;
    }
    
bail:
    
    return storage;
}

//API INTERFACE
// dump a btm file to stdout
// path is optional, and if nil, will be found dynamically
NSInteger dumpBTM(NSURL* path)
{
    //result
    NSInteger result = -1;
    
    //'Storage' object
    Storage* storage = nil;
    
    //item #
    int itemNumber = 0;
    
    //deserialze
    storage = deserialize(path);
    if(nil == storage)
    {
        //bail
        goto bail;
    }
    
    //process each/all items
    for(NSString* key in storage.itemsByUserIdentifier)
    {
        //uid
        uid_t uid = 0;
        
        //items
        NSArray* items = nil;
        
        //get uid from uuid
        uid = uidFromUUID(key);
        
        //header (w/ uid/uuid)
        printf("========================\n Records for UID %d : %s\n========================\n\n", uid, key.description.UTF8String);
        
        printf(" Items:\n\n");
    
        //process each item
        items = storage.itemsByUserIdentifier[key];
        for(ItemRecord* item in items)
        {
            //sanity check
            if(YES != [item respondsToSelector:NSSelectorFromString(@"dumpVerboseDescription")])
            {
                //err msg
                printf("ERROR: failed to find current 'ItemRecord' object's 'dumpVerboseDescription' method\n\n");
                
                //bail
                goto bail;
            }
            
            //display number and item details.
            printf(" #%d\n", ++itemNumber);
            
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
            
            printf(" %s\n", [[item performSelector:NSSelectorFromString(@"dumpVerboseDescription")] UTF8String]);
            
#pragma clang diagnostic pop
            
        }
    }

    //any mdm items?
    if(0 != storage.mdmPayloadsByIdentifier.count)
    {
        //reset
        itemNumber = 0;
        
        //dbg output
        printf("========================\n");
        printf("\n MDM Payloads:\n\n");
        
        //print out all mdm items
        for(NSString* key in storage.mdmPayloadsByIdentifier)
        {
            //item
            NSDictionary* mdmItem = storage.mdmPayloadsByIdentifier[key];
            
            //print
            printf("#%d: %s:\n%s\n", ++itemNumber, key.UTF8String, mdmItem.description.UTF8String);
        }
    }
    
    //happy
    result = noErr;

bail:
    
    return result;
}

//API INTERFACE
// parse a btm file into a dictionary
// path is optional, and if nil, will be found dynamically
NSDictionary* parseBTM(NSURL* path)
{
    //contents
    NSMutableDictionary* contents = nil;

    //'Storage' object
    Storage* storage = nil;
    
    //items
    NSMutableDictionary* itemsByUserID = nil;
    
    //init contents
    contents = [NSMutableDictionary dictionary];
    
    //init
    itemsByUserID = [NSMutableDictionary dictionary];
    
    //deserialze
    storage = deserialize(path);
    if(nil == storage)
    {
        //set error
        contents[KEY_BTM_ERROR] = [NSNumber numberWithLong:EFTYPE];
        
        //bail
        goto bail;
    }
    
    //set path
    contents[KEY_BTM_PATH] = path;

    //process each/all items
    // key is the UUID (mapping to a uid)
    for(NSString* key in storage.itemsByUserIdentifier)
    {
        //uid
        uid_t uid = 0;
        
        //items
        NSMutableArray* items = nil;
        
        //init
        items = [NSMutableArray array];
        
        //get uid from uuid
        uid = uidFromUUID(key);
        
        //process each item
        for(ItemRecord* item in storage.itemsByUserIdentifier[key])
        {
            //add item
            [items addObject:toDictionary(item, storage.itemsByUserIdentifier[key])];
        }
        
        //add items
        itemsByUserID[key] = items;
    }
    
    //save all items by user id
    contents[KEY_BTM_ITEMS_BY_USER_ID] = itemsByUserID;
    
    //save MDM payloads
    if(0 != storage.mdmPayloadsByIdentifier.count)
    {
        //save
        contents[KEY_BTM_MDM_PAYLOAD] = storage.itemsByUserIdentifier;
    }
    
bail:
    
    return contents;
}
 
//get path of the latest BTM file
// looks in "/private/var/db/com.apple.backgroundtaskmanagement/"
NSURL* getPath(void)
{
    //path
    NSURL* path = nil;
    
    //directory files
    NSArray* files = nil;
    
    //btm files
    NSArray* btmFiles = nil;
    
    //error
    NSError* error = nil;
    
    //load all files in directory
    files = [NSFileManager.defaultManager contentsOfDirectoryAtURL:[NSURL fileURLWithPath:BTM_DIRECTORY] includingPropertiesForKeys:nil options:0 error:&error];
    if(nil == files)
    {
        //err msg
        os_log_error(OS_LOG_DEFAULT, "ERROR: failed to enumerate files in %{public}@\nDetails: %{public}@\n\n", BTM_DIRECTORY, error);
        
        //bail
        goto bail;
    }
    
    //get files that match ".btm"
    btmFiles = [files filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"self.absoluteString ENDSWITH '.btm'"]];
    
    //grab last file
    path = btmFiles.lastObject;
    
bail:
    
    return path;
}

/* (helper) EXTENSION FUNCTIONS for ItemRecord object */
/* ...can't extented ItemRecord class, as its defined in a daemon (vs. framework) */

//helper function
//convert Item Record's type to string
NSString* typeDetails(ItemRecord* record)
{
    //details
    NSMutableString* details = nil;
    
    //init
    details = [NSMutableString string];
    
    //curated
    if(record.type & 0x80000)
    {
        [details appendString:@"curated "];
    }
    
    //legacy
    if(record.type & 0x10000)
    {
        [details appendString:@"legacy "];
    }
    
    //developer
    if(record.type & 0x20)
    {
        [details appendString:@"developer "];
    }
    
    //daemon
    if(record.type & 0x10)
    {
        [details appendString:@"daemon "];
    }
    
    //agent
    if(record.type & 0x8)
    {
        [details appendString:@"agent "];
    }
    
    //login item
    if(record.type & 0x4)
    {
        [details appendString:@"login item "];
    }
    
    //app
    if(record.type & 0x2)
    {
        [details appendString:@"app "];
    }
    
    return details;
}

//helper function
// find parent of ItemRecord, via ID
ItemRecord* findParent(ItemRecord* record, NSArray* items)
{
    //parent
    ItemRecord* parent = nil;
    
    //find parent
    for(ItemRecord* item in items)
    {
        //not a parent?
        if(nil == item.identifier)
        {
            //skip
            continue;
        }
        
        //no match
        if(YES != [item.identifier isEqualToString:record.container])
        {
            continue;
        }
    
        //match
        // save parent
        parent = item;
        
        //done
        break;
    }

    return parent;
}

//helper function
//convert ItemRecord disposition to string
NSString* dispositionDetails(ItemRecord* record)
{
    //details
    NSMutableString* details = nil;
    
    //init
    details = [NSMutableString string];
    
    //enabled
    if(record.disposition & 0x1)
    {
        [details appendString:@"enabled "];
    }
    //disabled
    else
    {
        [details appendString:@"disabled "];
    }
    
    //allowed
    if(record.disposition & 0x2)
    {
        [details appendString:@"allowed "];
    }
    //disallowed
    else
    {
        [details appendString:@"disallowed "];
    }
    
    //hidden
    if(record.disposition & 0x4)
    {
        [details appendString:@"hidden "];
    }
    //visibile
    else
    {
        [details appendString:@"visible "];
    }
    
    //notified
    if(record.disposition & 0x8)
    {
        [details appendString:@"notified"];
    }
    //not notified
    else
    {
        [details appendString:@"not notified"];
    }
    
    return details;
}

//helper function
// convert ItemRecord to a dictionary
// w/ additional logic to extract plist/exe paths
NSDictionary* toDictionary(ItemRecord* record, NSArray* items)
{
    //item
    NSMutableDictionary* item = nil;
    
    //bundle
    NSBundle* bundle = nil;
    
    //bundle ids
    NSMutableArray* bundleIDs = nil;
    
    //parent
    ItemRecord* parent = nil;

    //embedded items
    NSMutableArray* embeddedItems = nil;
    
    //init
    item = [NSMutableDictionary dictionary];
    
    //uuid
    item[KEY_BTM_ITEM_UUID] = record.uuid;
    
    //name
    item[KEY_BTM_ITEM_NAME] = record.name;
    
    //dev
    item[KEY_BTM_ITEM_DEV_NAME] = record.developerName;
    
    //team id
    if(nil != record.teamIdentifier)
    {
        item[KEY_BTM_ITEM_TEAM_ID] = record.teamIdentifier;
    }
    
    //type
    item[KEY_BTM_ITEM_TYPE] = [NSNumber numberWithLong:(long)record.type];
    
    //type description
    item[KEY_BTM_ITEM_TYPE_DETAILS] = typeDetails(record);
    
    //disposition
    item[KEY_BTM_ITEM_DISPOSITION] = [NSNumber numberWithLong:(long)record.disposition];
    
    //disposition details
    item[KEY_BTM_ITEM_DISPOSITION_DETAILS] = dispositionDetails(record);
    
    //identifier
    item[KEY_BTM_ITEM_ID] = record.identifier;
    
    //url
    item[KEY_BTM_ITEM_URL] = record.url;
    
    //path
    item[KEY_BTM_ITEM_EXE_PATH] = record.executablePath;
    
    //generation
    item[KEY_BTM_ITEM_GENERATION] = [NSNumber numberWithLong:(long)record.generation];
    
    //bundle id
    if(nil != record.bundleIdentifier)
    {
        //add
        item[KEY_BTM_ITEM_BUNDLE_ID] = record.bundleIdentifier;
    }

    //associated bundle ids
    if(0 != record.associatedBundleIdentifiers.count)
    {
        //init
        bundleIDs = [NSMutableArray array];
        
        //add each
        for(NSString* associatedBundleIdentifier in record.associatedBundleIdentifiers)
        {
            //add
            [bundleIDs addObject:associatedBundleIdentifier];
        }
        
        item[KEY_BTM_ITEM_ASSOCIATED_IDS] = bundleIDs;
    }
    
    //parent
    if(0 != record.container.length)
    {
        //add
        item[KEY_BTM_ITEM_PARENT_ID] = record.container;
    }
    
    //items
    if(0 != record.embeddedItems.count)
    {
        //init
        embeddedItems = [NSMutableArray array];
        
        //add each
        for(NSString* item in record.embeddedItems.allObjects)
        {
            //add
            [embeddedItems addObject:item];
        }
        
        //save
        item[KEY_BTM_ITEM_EMBEDDED_IDS] = embeddedItems;
    }
    
    //agents/daemons
    // path: already set
    // plist: is in 'url'
    if( (record.type & 0x8) ||
        (record.type & 0x10) )
    {
        //set plist
        if(nil != record.url)
        {
            //plist
            item[KEY_BTM_ITEM_PLIST_PATH] = record.url.path;
        }
    }
    
    //login item
    // path: construct via parent
    else if(record.type & 0x4)
    {
        //find parent
        parent = findParent(record, items);
        if(nil != parent)
        {
            bundle = [NSBundle bundleWithPath:[NSString stringWithFormat:@"%@%@", parent.url.path, record.url.path]];
        }
        
        //add exe path
        if(nil != bundle.executablePath)
        {
            //exe path
            item[KEY_BTM_ITEM_EXE_PATH] = bundle.executablePath;
        }
    }
    
    //app
    // path to app bundle is in url
    // ...load bundle to get exe path
    else if(record.type & 0x2)
    {
        //load bundle from app path
        bundle = [NSBundle bundleWithPath:record.url.path];
        
        //add exe path
        if(nil != bundle.executablePath)
        {
            //exe path
            item[KEY_BTM_ITEM_EXE_PATH] = bundle.executablePath;
        }
    }

    return item;
}

//helper function
//get a UID from a UUID
uid_t uidFromUUID(NSString* uuid)
{
    //uid
    uid_t uid = 0;
    
    //node
    ODNode* node = nil;
    
    //query
    ODQuery* query = nil;
    
    //return
    NSArray* result = nil;
    
    //record
    ODRecord* record = nil;
    
    //attribute (@kDS1AttrUniqueID)
    NSArray* attribute = nil;
    
    //init node
    node = [ODNode nodeWithSession:ODSession.defaultSession type:0x2200 error:nil];
    
    //perform query
    query = [ODQuery queryWithNode:node forRecordTypes:kODRecordTypeUsers attribute:kODAttributeTypeGUID matchType:0x2001 queryValues:uuid returnAttributes:nil maximumResults:1 error:nil];
    
    //result
    result = [query resultsAllowingPartial:0x0 error:nil];
    
    //grab first result
    record = result.firstObject;
    
    //grab '@kDS1AttrUniqueID'
    attribute = [record valuesForAttribute:@kDS1AttrUniqueID error:nil];
    
    //uid is first obj, as int
    uid = [attribute.firstObject intValue];
    
    return uid;
}

