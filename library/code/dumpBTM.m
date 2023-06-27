//
//  dumpBTM.m
//  dumpBTM (library)
//
//  Created by Patrick Wardle on 1/20/23.
//

#import "dumpBTM.h"
#import "dumpBT_Internal.h"

//load a btm file
NSInteger load(NSURL** path, NSKeyedUnarchiver** keyedUnarchiver)
{
    //result
    NSInteger result = -1;
    
    //error
    NSError* error = nil;
    
    //database data
    NSData* data = nil;
    
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
            
            //set
            result = ENOENT;
            
            //bail
            goto bail;
        }
    }
    
    //load database
    // note: this will fail if client doesn't have full disk access
    data = [NSData dataWithContentsOfURL:*path options:0 error:&error];
    if(nil == data)
    {
        //err msg
        os_log_error(OS_LOG_DEFAULT, "ERROR: failed to open/load %{public}@", *path);
        
        //set error
        result = error.code;
        
        //bail
        goto bail;
    }
    
    //init unachiver
    *keyedUnarchiver = [[NSKeyedUnarchiver alloc] initForReadingFromData:data error:&error];
    
    //set decoding failure policy
    // will throw an exception if unserialization fails
    (*keyedUnarchiver).decodingFailurePolicy = NSDecodingFailurePolicyRaiseException;
    
    //happy
    result = noErr;
    
bail:
    
    return result;
}

//API interface
// dump a btm file to stdout
// path is optional, and if nil, will be found dynamically
NSInteger dumpBTM(NSURL* path)
{
    //result
    NSInteger result = -1;
            
    //database storage obj
    Storage* storage = nil;
    
    //unarchiver
    NSKeyedUnarchiver* keyedUnarchiver = nil;

    //load
    result = load(&path, &keyedUnarchiver);
    if(result != noErr)
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
        storage = [keyedUnarchiver decodeObjectOfClass:[Storage class] forKey:@"store"];
    }
    //exception
    @catch (NSException *exception) {
        
        //err msg
        printf("ERROR: unserializing failed with %s\n\n", exception.description.UTF8String);
        
        //bail
        goto bail;
    }
    
    //process each/all items
    for(NSString* key in storage.items)
    {
        //uid
        uid_t uid = 0;
        
        //items
        NSArray* items = nil;
        
        //item number
        int itemNumber = 0;
        
        //get uid from uuid
        uid = uidFromUUID(key);
        
        //header (w/ uid/uuid)
        printf("========================\n Records for UID %d : %s\n========================\n\n", uid, key.description.UTF8String);
        
        printf(" Items:\n\n");
        
        //process each item
        items = storage.items[key];
        for(ItemRecord* item in items)
        {
            //display number and item details.
            printf(" #%d\n", ++itemNumber);
            printf(" %s\n", [[item dumpVerboseDescription] UTF8String]);
        }
    }
    
bail:
    
    return result;
}

//API interface
// parse a btm file into a dictionary
// path is optional, and if nil, will be found dynamically
NSDictionary* parseBTM(NSURL* path)
{
    //result
    NSInteger result = -1;
    
    //contents
    NSMutableDictionary* contents = nil;
    
    //unarchiver
    NSKeyedUnarchiver* keyedUnarchiver = nil;
    
    //database storage obj
    Storage* storage = nil;
    
    //items
    NSMutableDictionary* itemsByUserID = nil;
    
    //init contents
    contents = [NSMutableDictionary dictionary];
    
    //init
    itemsByUserID = [NSMutableDictionary dictionary];
    
    //load
    result = load(&path, &keyedUnarchiver);
    if(result != noErr)
    {
        //set error
        contents[KEY_BTM_ERROR] = [NSNumber numberWithLong:result];
        
        //bail
        goto bail;
    }
    
    //set path
    contents[KEY_BTM_PATH] = path;
    
    //wrap unserialization
    @try
    {
        //decode version
        contents[KEY_BTM_VERSION] = [NSNumber numberWithInteger:[keyedUnarchiver decodeIntegerForKey:@"version"]];

        //decode storage object
        // this in turn will decode all items
        storage = [keyedUnarchiver decodeObjectOfClass:[Storage class] forKey:@"store"];
    }
    //exception
    @catch(NSException *exception)
    {
        //err msg
        os_log_error(OS_LOG_DEFAULT, "ERROR: unserializing failed with %{public}@", exception);
        
        //set error
        contents[KEY_BTM_ERROR] = [NSNumber numberWithLong:EFTYPE];
    
        //bail
        goto bail;
    }

    //process each/all items
    // key is the UUID (mapping to a uid)
    for(NSString* key in storage.items)
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
        for(ItemRecord* item in storage.items[key])
        {
            //add item
            [items addObject:[item toDictionary]];
        }
        
        //add items
        itemsByUserID[key] = items;
    }
    
    //save all items by user id
    contents[KEY_BTM_ITEMS_BY_USER_ID] = itemsByUserID;
    
bail:
    
    return contents;
}

//get path of BTM file
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


@implementation Storage

@synthesize items;

+(BOOL)supportsSecureCoding
{
    return YES;
}

//decode object
-(id)initWithCoder:(NSCoder *)decoder
{
    if(self = [super init])
    {
        //supported classes
        NSArray* itemClasses = @[[NSMutableDictionary class], [NSString class], [NSArray class], [ItemRecord class]];
        
        //decode items
        // 'itemsByUserIdentifier'
        self.items = [decoder decodeObjectOfClasses:[NSSet setWithArray:itemClasses] forKey:@"itemsByUserIdentifier"];
    }
    
    //TODO:
    // "userSettingsByUserIdentifier" & "mdmPaloadsByIdentifier"
    
    
    return self;
}

-(void)encodeWithCoder:(nonnull NSCoder *)coder {
 
    return;
}

@end

@implementation ItemRecord

+(BOOL)supportsSecureCoding
{
    return YES;
}

//decode object
-(id)initWithCoder:(NSCoder *)decoder
{
    self = [super init];
    if(nil != self)
    {
        self.uuid = [decoder decodeObjectOfClass:[NSUUID class] forKey:@"uuid"];
        self.identifier = [decoder decodeObjectOfClass:[NSString class] forKey:@"identifier"];
        self.generation = [decoder decodeIntegerForKey:@"generation"];
        self.url = [decoder decodeObjectOfClass:[NSURL class] forKey:@"url"];
        self.executablePath = [decoder decodeObjectOfClass:[NSString class] forKey:@"executablePath"];
        self.name = [decoder decodeObjectOfClass:[NSString class] forKey:@"name"];
        self.developerName = [decoder decodeObjectOfClass:[NSString class] forKey:@"developerName"];
        self.teamIdentifier = [decoder decodeObjectOfClass:[NSString class] forKey:@"teamIdentifier"];
        self.lightweightRequirement = [decoder decodeObjectOfClass:[NSData class] forKey:@"lightweightRequirement"];
        self.type = [decoder decodeIntegerForKey:@"type"];
        self.disposition = [decoder decodeIntegerForKey:@"disposition"];
        self.bookmark = [decoder decodeObjectOfClass:[NSData class] forKey:@"bookmark"];
        self.bundleIdentifier = [decoder decodeObjectOfClass:[NSString class] forKey:@"bundleIdentifier"];
        self.associatedBundleIdentifiers = [decoder decodeObjectOfClasses:[NSSet setWithArray:@[[NSArray class], [NSString class]]] forKey:@"associatedBundleIdentifiers"];
    
        self.container = [decoder decodeObjectOfClass:[NSString class] forKey:@"container"];
        
        NSArray* itemsArray = [decoder decodeArrayOfObjectsOfClass:[NSString class] forKey:@"items"];
        if(nil != itemsArray)
        {
            self.items = [NSMutableSet setWithArray:itemsArray];
        }
        else
        {
            self.items = [NSMutableSet set];
        }
    }

    return self;
}

-(void)encodeWithCoder:(nonnull NSCoder *)coder {
 
    return;
}

//convert item record's type to string
// TODO: handle all types (e.g. managaged?)
-(NSString *)typeDetails
{
    //details
    NSMutableString* details = nil;
    
    //init
    details = [NSMutableString string];
    
    //curated
    if(self.type & 0x80000)
    {
        [details appendString:@"curated "];
    }
    
    //legacy
    if(self.type & 0x10000)
    {
        [details appendString:@"legacy "];
    }
    
    //developer
    if(self.type & 0x20)
    {
        [details appendString:@"developer "];
    }
    
    //daaemon
    if(self.type & 0x10)
    {
        [details appendString:@"daemon "];
    }
    
    //agent
    if(self.type & 0x8)
    {
        [details appendString:@"agent "];
    }
    
    //login item
    if(self.type & 0x4)
    {
        [details appendString:@"login item "];
    }
    
    //app
    if(self.type & 0x2)
    {
        [details appendString:@"app "];
    }
    
    return details;
}

//convert item record's disposition to string
-(NSString *)dispositionDetails
{
    //details
    NSMutableString* details = nil;
    
    //init
    details = [NSMutableString string];
    
    //enabled
    if(self.disposition & 0x1)
    {
        [details appendString:@"enabled "];
    }
    //disabled
    else
    {
        [details appendString:@"disabled "];
    }
    
    //allowed
    if(self.disposition & 0x2)
    {
        [details appendString:@"allowed "];
    }
    //disallowed
    else
    {
        [details appendString:@"disallowed "];
    }
    
    //hidden
    if(self.disposition & 0x4)
    {
        [details appendString:@"hidden "];
    }
    //visibile
    else
    {
        [details appendString:@"visible "];
    }
    
    //notified
    if(self.disposition & 0x8)
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

//convert to a dictionary
-(NSDictionary*)toDictionary
{
    //item
    NSMutableDictionary* item = nil;
    
    //bundle ids
    NSMutableArray* bundleIDs = nil;
    
    //embedded items
    NSMutableArray* embeddedItems = nil;
    
    //init
    item = [NSMutableDictionary dictionary];
    
    //uuid
    item[KEY_BTM_ITEM_UUID] = self.uuid;
    
    //name
    item[KEY_BTM_ITEM_NAME] = self.name;
    
    //dev
    item[KEY_BTM_ITEM_DEV_NAME] = self.developerName;
    
    //team id
    if(nil != self.teamIdentifier)
    {
        item[KEY_BTM_ITEM_TEAM_ID] = self.teamIdentifier;
    }
    
    //type
    item[KEY_BTM_ITEM_TYPE] = [NSNumber numberWithLong:(long)self.type];
    
    //type description
    item[KEY_BTM_ITEM_TYPE_DETAILS] = [self typeDetails];
    
    //disposition
    item[KEY_BTM_ITEM_DISPOSITION] = [NSNumber numberWithLong:(long)self.disposition];
    
    //disposition details
    item[KEY_BTM_ITEM_DISPOSITION_DETAILS] = [self dispositionDetails];
    
    //indentifier
    item[KEY_BTM_ITEM_ID] = self.identifier;
    
    //url
    item[KEY_BTM_ITEM_URL] = self.url;
    
    //path
    item[KEY_BTM_ITEM_EXE_PATH] = self.executablePath;
    
    //generation
    item[KEY_BTM_ITEM_GENERATION] = [NSNumber numberWithLong:(long)self.generation];
    
    //bundle id
    if(nil != self.bundleIdentifier)
    {
        //add
        item[KEY_BTM_ITEM_BUNDLE_ID] = self.bundleIdentifier;
    }

    //associated bundle ids
    if(0 != self.associatedBundleIdentifiers.count)
    {
        //init
        bundleIDs = [NSMutableArray array];
        
        //add each
        for(NSString* associatedBundleIdentifier in self.associatedBundleIdentifiers)
        {
            //add
            [bundleIDs addObject:associatedBundleIdentifier];
        }
        
        item[KEY_BTM_ITEM_ASSOCIATED_IDS] = bundleIDs;
    }
    
    //parent
    if(0 != self.container.length)
    {
        //add
        item[KEY_BTM_ITEM_PARENT_ID] = self.container;
    }
    
    //items
    if(0 != self.items.count)
    {
        //init
        embeddedItems = [NSMutableArray array];
        
        //add each
        for(NSString* item in self.items.allObjects)
        {
            //add
            [embeddedItems addObject:item];
        }
        
        item[KEY_BTM_ITEM_EMBEDDED_IDS] = embeddedItems;
    }

    return item;
}

//dump
// build a string for output
-(NSString *)dumpVerboseDescription {
    
    //desc
    NSMutableString* description = nil;
    
    //init
    description = [NSMutableString string];
    
    //build description
    [description appendFormat:@" UUID:              %@\r\n", self.uuid];
    [description appendFormat:@"  Name:              %@\r\n", self.name];
    [description appendFormat:@"  Developer Name:    %@\r\n", self.developerName];
    
    //team id
    if(nil != self.teamIdentifier)
    {
        [description appendFormat:@"  Team Identifier:   %@\r\n", self.teamIdentifier];
    }
    
    //type
    [description appendFormat:@"  Type:              %@ (%#lx)\n", [self typeDetails], (long)self.type];
    
    //disposition
    [description appendFormat:@"  Disposition:       [%@] (%ld)\n", [self dispositionDetails], (long)self.disposition];
    
    //id
    [description appendFormat:@"  Indentifier:       %@\r\n", self.identifier];
    
    //url
    [description appendFormat:@"  URL:               %@\n", self.url];
    
    //path
    [description appendFormat:@"  Executable Path:   %@\n", self.executablePath];
    
    //generation
    [description appendFormat:@"  Generation:        %ld\n", self.generation];
    
    //bundle id
    if(nil != self.bundleIdentifier)
    {
        //add
        [description appendFormat:@"  Bundle Identifier: %@\n", self.bundleIdentifier];
    }
    
    //associated bundle ids
    if(0 != self.associatedBundleIdentifiers.count)
    {
        [description appendFormat:@"  Assoc. Bundle IDs: "];
        [description appendString:@"["];
        
        for(NSString* associatedBundleIdentifier in self.associatedBundleIdentifiers)
        {
            [description appendFormat:@"%@ ", associatedBundleIdentifier];
        }
        
        //remove last " "
        if(YES == [[description substringFromIndex:[description length] - 1] isEqualToString:@" "])
        {
            description = [[description substringToIndex:[description length]-1] mutableCopy];
        }
    
        [description appendString:@"]\n"];
    }
    
    //parent id
    if(nil != self.container)
    {
        //add
        [description appendFormat:@"  Parent Identifier: %@\n", self.container];
    }
    
    //items
    if(0 != self.items.count)
    {
        int count = 0;
        
        //add identifiers
        [description appendFormat:@"  Embedded Item Identifiers:"];
        for(NSString* item in self.items.allObjects)
        {
            [description appendFormat:@"\n    #%d: %@", ++count, item];
        }
        [description appendString:@"\n"];
    }
    
    return description;
}
@end


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
