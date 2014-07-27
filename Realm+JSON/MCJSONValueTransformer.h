//
//  MCJSONValueTransformer.h
//  RealmJSONDemo
//
//  Created by Matthew Cheok on 27/7/14.
//  Copyright (c) 2014 Matthew Cheok. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface MCJSONValueTransformer : NSValueTransformer

+ (instancetype)valueTransformerWithMappingDictionary:(NSDictionary *)dictionary;
- (instancetype)initWithMappingDictionary:(NSDictionary *)dictionary;

@end
