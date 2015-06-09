//
//  MCJSONNonNullStringTransformer.m
//  Pods
//
//  Created by Matthew Cheok on 23/5/15.
//
//

#import "MCJSONNonNullStringTransformer.h"

@implementation MCJSONNonNullStringTransformer

+ (instancetype)valueTransformer {
	return [[self alloc] init];
}

+ (Class)transformedValueClass {
	return [NSString class];
}

+ (BOOL)allowsReverseTransformation {
	return YES;
}

- (id)transformedValue:(id)value {
	if (value && ![value isKindOfClass:[NSNull class]]) {
		return value;
	}
	else {
		return @"";
	}
}

- (id)reverseTransformedValue:(id)value {
	return value;
}

@end
