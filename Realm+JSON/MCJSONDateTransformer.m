//
//  MCJSONDateTransformer.m
//  RealmJSONDemo
//
//  Created by Matthew Cheok on 27/7/14.
//  Copyright (c) 2014 Matthew Cheok. All rights reserved.
//

#import "MCJSONDateTransformer.h"

NSString* const MCJSONDateTimeTransformerName = @"MCJSONDateTimeTransformerName";
NSString* const MCJSONDateTimeMillisecondTransformerName = @"MCJSONDateTimeMillisecondTransformerName";
NSString* const MCJSONDateOnlyTransformerName = @"MCJSONDateOnlyTransformerName";
static NSString *const kDateFormatDateTime = @"yyyy-MM-dd'T'HH:mm:ssZZZZZ";
static NSString *const kDateFormatDateTimeMillisecond = @"yyyy-MM-dd'T'HH:mm:ss.SSSZZZZZ";
static NSString *const kDateFormatDateOnly = @"yyyy-MM-dd";

@interface MCJSONDateTransformer ()

@property (nonatomic, strong) NSDateFormatter *formatter;

@end

@implementation MCJSONDateTransformer

+ (void)load {
    [NSValueTransformer setValueTransformer:[[self alloc] initWithDateStyle:MCJSONDateTransformerStyleDateTime] forName:MCJSONDateTimeTransformerName];
    [NSValueTransformer setValueTransformer:[[self alloc] initWithDateStyle:MCJSONDateTransformerStyleDateTimeMillisecond] forName:MCJSONDateTimeMillisecondTransformerName];
    [NSValueTransformer setValueTransformer:[[self alloc] initWithDateStyle:MCJSONDateTransformerStyleDateOnly] forName:MCJSONDateOnlyTransformerName];
}

+ (instancetype)valueTransformerWithDateStyle:(MCJSONDateTransformerStyle)style {
    return [[self alloc] initWithDateStyle:style];
}

- (instancetype)initWithDateStyle:(MCJSONDateTransformerStyle)style {
    switch (style) {
        case MCJSONDateTransformerStyleDateOnly:
            self = [self initWithDateFormat:kDateFormatDateOnly];
            break;
        case MCJSONDateTransformerStyleDateTimeMillisecond:
            self = [self initWithDateFormat:kDateFormatDateTimeMillisecond];
            break;
            
        default:
            self = [self initWithDateFormat:kDateFormatDateTime];
            break;
    }
    return self;
}

+ (instancetype)valueTransformerWithDateFormat:(NSString *)dateFormat {
    return [[self alloc] initWithDateFormat:dateFormat];
}

- (instancetype)initWithDateFormat:(NSString *)dateFormat {
    self = [super init];
    if (self) {
        self.formatter = [[NSDateFormatter alloc] init];
        self.formatter.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
        self.formatter.dateFormat = dateFormat;
    }
    return self;
}

+ (Class)transformedValueClass {
	return [NSDate class];
}

+ (BOOL)allowsReverseTransformation {
	return YES;
}

- (id)transformedValue:(id)value {
    if([value isKindOfClass:[NSNull class]])return nil;
	return [self.formatter dateFromString:value];
}

- (id)reverseTransformedValue:(id)value {
	return [self.formatter stringFromDate:value];
}

@end
