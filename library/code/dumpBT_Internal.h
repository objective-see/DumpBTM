//
//  dumpBTM_Internal.h
//  dumpBTM (library)
//
//  Created by Patrick Wardle on 1/20/23.
//

@import OSLog;
@import Foundation;
@import OpenDirectory;
@import DirectoryService;

#define BTM_DIRECTORY @"/private/var/db/com.apple.backgroundtaskmanagement/"

//helper function(s)
NSURL* getPath(void);
uid_t uidFromUUID(NSString* uuid);

/* the following objects
   ...dumped from backgroundtaskmanagementd */

//Storage obj
@interface Storage : NSObject <NSSecureCoding>

@property(nonatomic, retain)NSDictionary* items;

@end

//Item Record obj
@interface ItemRecord : NSObject <NSSecureCoding>

@property NSInteger type;
@property NSInteger generation;
@property NSInteger disposition;

@property(nonatomic, retain)NSURL* url;
@property(nonatomic, retain)NSUUID* uuid;
@property(nonatomic, retain)NSString* name;
@property(nonatomic, retain)NSData* bookmark;
@property(nonatomic, retain)NSString* container;
@property(nonatomic, retain)NSMutableSet* items;
@property(nonatomic, retain)NSString* identifier;
@property(nonatomic, retain)NSString* developerName;
@property(nonatomic, retain)NSString* executablePath;
@property(nonatomic, retain)NSString* teamIdentifier;
@property(nonatomic, retain)NSString* bundleIdentifier;
@property(nonatomic, retain)NSData* lightweightRequirement;
@property(nonatomic, retain)NSArray* associatedBundleIdentifiers;

-(NSString*)dumpVerboseDescription;

//custom method
-(NSDictionary*)toDictionary;

@end
