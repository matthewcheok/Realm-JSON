//
//  MCJSONPrimaryKeyTransformer.m
//  RealmJSON
//
//  Created by Anton Gaenko on 14.12.14.
//  Copyright (c) 2014 Anton Gaenko. All rights reserved.
//

#import "MCJSONPrimaryKeyTransformer.h"

@interface MCJSONPrimaryKeyTransformer ()

@property (nonatomic, assign) Class realmClassToMap;

@end

@implementation MCJSONPrimaryKeyTransformer

+ (instancetype)valueTransformerWithRealmClass:(Class)realmClass {
    return [[self alloc] initWithRealmClass:realmClass];
}

- (instancetype)initWithRealmClass:(Class)realmClass {
    self = [super init];
    if (self) {
        // it should be RLMObject subclass
        BOOL isRlmObjectSubclass  = [realmClass respondsToSelector:@selector(isSubclassOfClass:)] &&
                                    [realmClass isSubclassOfClass:[RLMObject class]];
        
        if (isRlmObjectSubclass) {
            self.realmClassToMap = realmClass;
        }
        
    }
    return self;
}

- (id)transformedValue:(NSString*)value {
    if (value && self.realmClassToMap) {
        return [self.realmClassToMap performSelector:@selector(objectForPrimaryKey:) withObject:value];
    }
    
    return nil;
}

@end
