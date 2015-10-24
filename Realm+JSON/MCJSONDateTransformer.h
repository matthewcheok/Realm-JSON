//
//  MCJSONDateTransformer.h
//  RealmJSONDemo
//
//  Created by Matthew Cheok on 27/7/14.
//  Copyright (c) 2014 Matthew Cheok. All rights reserved.
//

#import <Foundation/Foundation.h>

extern NSString* const MCJSONDateTimeTransformerName;
extern NSString* const MCJSONDateTimeMillisecondTransformerName;
extern NSString* const MCJSONDateOnlyTransformerName;

typedef NS_ENUM(NSInteger, MCJSONDateTransformerStyle) {
    MCJSONDateTransformerStyleDateTime = 0,
    MCJSONDateTransformerStyleDateTimeMillisecond,
    MCJSONDateTransformerStyleDateOnly
};

@interface MCJSONDateTransformer : NSValueTransformer

+ (instancetype)valueTransformerWithDateStyle:(MCJSONDateTransformerStyle)style;
- (instancetype)initWithDateStyle:(MCJSONDateTransformerStyle)style;
+ (instancetype)valueTransformerWithDateFormat:(NSString *)dateFormat;
- (instancetype)initWithDateFormat:(NSString *)dateFormat;

@end
