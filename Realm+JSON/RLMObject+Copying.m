//
//  RLMObject+Copying.m
//  RealmJSONDemo
//
//  Created by Matthew Cheok on 26/8/14.
//  Copyright (c) 2014 Getting Real. All rights reserved.
//

#import "RLMObject+Copying.h"

#import <Realm/RLMProperty.h>
#import <Realm/RLMObjectSchema.h>

@implementation RLMObject (Copying)

- (instancetype)shallowCopy {
    Class class = NSClassFromString([[self class] className]);

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
            [thisArray addObjects:thatArray];
        }
        // assume data
        else {
            id value = [object valueForKeyPath:property.name];
            [self setValue:value forKeyPath:property.name];
        }
    }
}

- (instancetype)deepCopy {
    Class class = NSClassFromString([[self class] className]);
    
    RLMObject *object = [[class alloc] init];
    
    for (RLMProperty *property in self.objectSchema.properties) {

        if (property.type == RLMPropertyTypeArray) {
            RLMArray *thisArray = [self valueForKeyPath:property.name];
            RLMArray *newArray = [object valueForKeyPath:property.name];
            
            for (RLMObject *currentObject in thisArray) {
                [newArray addObject:[currentObject deepCopy]];
            }
            
        }
        else if (property.type == RLMPropertyTypeObject) {
            RLMObject *value = [self valueForKeyPath:property.name];
            [object setValue:[value deepCopy] forKeyPath:property.name];
        }
        else {
            id value = [self valueForKeyPath:property.name];
            [object setValue:value forKeyPath:property.name];
        }
    }
    
    return object;
}



@end
