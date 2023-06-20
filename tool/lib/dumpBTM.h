//
//  dumpBTM.h
//  library
//
//  Created by Patrick Wardle on 1/20/23.
//

#import <Foundation/Foundation.h>

//keys for dictionary
#define KEY_PATH @"path"
#define KEY_ERROR @"error"
#define KEY_VERSION @"version"
#define KEY_ITEMS_BY_USER_ID @"itemsByUserIdentifier"

//APIs
// note: path is optional
NSInteger dump(NSURL* path);
NSDictionary* parse(NSURL* path);




