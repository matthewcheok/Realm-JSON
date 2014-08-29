//
//  RLMObject+Copying.m
//  Saleswhale
//
//  Created by Matthew Cheok on 26/8/14.
//  Copyright (c) 2014 Getting Real. All rights reserved.
//

#import "RLMObject+Copying.h"

@implementation RLMObject (Copying)

- (instancetype)shallowCopy {
    Class class = [self.class mc_normalizedClass];
    id object = [[class alloc] init];
    [object mergePropertiesFromObject:self];
    
    return object;
}

- (void)mergePropertiesFromObject:(id)object {
    for (RLMProperty *property in self.objectSchema.properties) {
        // assume array
        if (property.type == RLMPropertyTypeArray) {
            RLMArray *thisArray = [self valueForKeyPath:property.name];
            RLMArray *thatArray = [object valueForKeyPath:property.name];
            [thisArray addObjectsFromArray:thatArray];
        }
        // assume data
        else {
            id value = [object valueForKeyPath:property.name];
            [self setValue:value forKeyPath:property.name];
        }
    }
}

#pragma mark - Private

+ (Class)mc_normalizedClass {
	NSString *className = NSStringFromClass(self);
	className = [className stringByReplacingOccurrencesOfString:@"RLMAccessor_" withString:@""];
	className = [className stringByReplacingOccurrencesOfString:@"RLMStandalone_" withString:@""];
	return NSClassFromString(className);
}

@end
