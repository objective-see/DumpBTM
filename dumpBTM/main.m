//
//  main.m
//  dumpBTM
//
//  Created by Patrick Wardle on 1/1/23.
//

#import <Foundation/Foundation.h>
#import <OpenDirectory/OpenDirectory.h>
#import <DirectoryService/DirectoryService.h>

#define DB_PATH @"/private/var/db/com.apple.backgroundtaskmanagement/BackgroundItems-v4.btm"

//helper function(s)
uid_t uidFromUUID(NSString* uuid);

//Storage obj
@interface Storage : NSObject <NSSecureCoding>

@property(nonatomic, retain)NSDictionary* items;

@end

//item record obj
@interface ItemRecord : NSObject <NSSecureCoding>

@property(nonatomic, retain)NSUUID* uuid;
@property(nonatomic, retain)NSString* identifier;
@property NSInteger generation;
@property(nonatomic, retain)NSURL* url;
@property(nonatomic, retain)NSString* executablePath;
@property(nonatomic, retain)NSString* name;
@property(nonatomic, retain)NSString* developerName;
@property(nonatomic, retain)NSString* teamIdentifier;
@property(nonatomic, retain)NSData* lightweightRequirement;
@property NSInteger type;
@property NSInteger disposition;
@property(nonatomic, retain)NSData* bookmark;
@property(nonatomic, retain)NSString* bundleIdentifier;
@property(nonatomic, retain)NSArray* associatedBundleIdentifiers;
@property(nonatomic, retain)NSString* container;
@property(nonatomic, retain)NSMutableSet* items;

-(NSString*)dumpVerboseDescription;

@end


//main
// just dump DB to stdout
// TODO: add option to print as JSON
int main(int argc, const char * argv[]) {
    
    //status
    int status = -1;
    
    @autoreleasepool {
        
        //error
        NSError* error = nil;
        
        //unarchiver
        NSKeyedUnarchiver* keyedUnarchiver = nil;
        
        //database (raw/unserialized) data
        NSData* dbData = nil;
        
        //database dictionary
        NSMutableDictionary* dbDictionary = nil;
        
        //database storage obj
        Storage* storage = nil;
        
        //init
        dbDictionary = [NSMutableDictionary dictionary];
        
        //load database
        // note: this will fail if you don't have full disk access
        dbData = [NSData dataWithContentsOfURL:[[NSURL alloc] initFileURLWithPath:DB_PATH] options:0 error:&error];
        if(nil == dbData)
        {
            //error msg
            NSLog(@"ERROR: failed to load %@\n\n Do you have Full Disk Access?\n\n", DB_PATH);
            goto bail;
        }
        
        //NSLog(@"opened %@", DB_PATH);
        
        //init unachiver
        keyedUnarchiver = [[NSKeyedUnarchiver alloc] initForReadingFromData:dbData error:&error];
        
        //set this (for debugging)
        keyedUnarchiver.decodingFailurePolicy = NSDecodingFailurePolicyRaiseException;
        
        //get version
        dbDictionary[@"version"] = [NSNumber numberWithInteger:[keyedUnarchiver decodeIntegerForKey:@"version"]];
        
        //get store
        dbDictionary[@"store"] = [keyedUnarchiver decodeObjectOfClass:[Storage class] forKey:@"store"];

        //grab storage obj
        storage = dbDictionary[@"store"];
        
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
        
        //happy
        status = 0;
    }
    
bail:
    
    return status;
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
        self.associatedBundleIdentifiers = [decoder decodeObjectOfClass:[NSArray class] forKey:@"associatedBundleIdentifiers"];
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

//dump
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
    [description appendFormat:@"  Parent Identifier: %@\n", self.container];
    
    //items
    if(0 != self.items.count)
    {
        int count = 0;
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
//grab a UID from a UUID
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

