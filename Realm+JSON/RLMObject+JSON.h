//
//  RLMObject+JSON.h
//  RealmJSONDemo
//
//  Created by Matthew Cheok on 27/7/14.
//  Copyright (c) 2014 Matthew Cheok. All rights reserved.
//

#import <Realm/Realm.h>
#import "MCJSONDateTransformer.h"
#import "MCJSONValueTransformer.h"

@interface RLMObject (JSON)

+ (void)createInRealm:(RLMRealm *)realm withJSONArray:(NSArray *)array;
+ (instancetype)createInRealm:(RLMRealm *)realm withJSONDictionary:(NSDictionary *)dictionary;

- (instancetype)initWithJSONDictionary:(NSDictionary *)dictionary;
- (NSDictionary *)JSONDictionary;

@end
