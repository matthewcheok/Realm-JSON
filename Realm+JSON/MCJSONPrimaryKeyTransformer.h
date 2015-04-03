//
//  MCJSONPrimaryKeyTransformer.h
//  RealmJSON
//
//  Created by Anton Gaenko on 14.12.14.
//  Copyright (c) 2014 Anton Gaenko. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <Realm/Realm.h>

@interface MCJSONPrimaryKeyTransformer : NSValueTransformer

// it should be RLMObject subclass
+ (instancetype)valueTransformerWithRealmClass:(Class)realmClass;
- (instancetype)initWithRealmClass:(Class)realmClass;

@end
