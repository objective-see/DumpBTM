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
    
    //set if you want a custom btm file
    NSURL* path = nil;
    
    //just dump to stdout
    // similar to: sfltool dumpbtm
    dumpBTM(path);
    
    //parse into a dictionary
    // containing items (in dictionaries)
    NSDictionary* contents = parseBTM(path);
    
    //now do something with extracted/parsed out items
    
    return 0;
}
