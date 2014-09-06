//
//  RLMObject+MCInternal.m
//  RealmJSONDemo
//
//  Created by Matthew Cheok on 6/9/14.
//
//

#import "RLMObject+MCInternal.h"

@implementation RLMObject (MCInternal)

+ (Class)mc_normalizedClass {
	NSString *className = NSStringFromClass(self);
	className = [className stringByReplacingOccurrencesOfString:@"RLMAccessor_" withString:@""];
	className = [className stringByReplacingOccurrencesOfString:@"RLMStandalone_" withString:@""];
	return NSClassFromString(className);
}

@end
