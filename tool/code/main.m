//
//  main.m
//  tool
//
//  Created by Patrick Wardle on 1/20/23.
//

@import Foundation;

#include "dumpBTM.h"

//example program to link/invoke 'dumpBTM' library
int main(int argc, const char * argv[]) {
    
    //for user-specified path
    NSURL* path = nil;
    
    //user-specified path?
    if(argc == 2)
    {
        //set
        path = [[NSURL alloc] initFileURLWithPath:[NSString stringWithUTF8String:argv[1]]];
    }
    
    //just dump to stdout
    // similar to: sfltool dumpbtm
    dumpBTM(path);
    
    //parse into a dictionary
    // containing items (in dictionaries)
    NSDictionary* contents = parseBTM(path);
    
    //now do something with extracted/parsed out items
    
    return 0;
}
