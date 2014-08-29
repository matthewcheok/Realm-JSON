//
//  RLMObject+Copying.h
//  Saleswhale
//
//  Created by Matthew Cheok on 26/8/14.
//  Copyright (c) 2014 Getting Real. All rights reserved.
//

#import <Realm/Realm.h>

@interface RLMObject (Copying)

- (instancetype)shallowCopy;
- (void)mergePropertiesFromObject:(id)object;

@end
