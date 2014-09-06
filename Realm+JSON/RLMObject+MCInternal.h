//
//  RLMObject+MCInternal.h
//  RealmJSONDemo
//
//  Created by Matthew Cheok on 6/9/14.
//
//

#import <Realm/Realm.h>
#import "RLMObject.h"

@interface RLMObject (MCInternal)

+ (Class)mc_normalizedClass;

@end
