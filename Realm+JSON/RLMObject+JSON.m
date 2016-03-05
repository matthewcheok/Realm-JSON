//
//  RLMObject+JSON.m
//  RealmJSONDemo
//
//  Created by Matthew Cheok on 27/7/14.
//  Copyright (c) 2014 Matthew Cheok. All rights reserved.
//

#import "RLMObject+JSON.h"

#import <Realm/RLMProperty.h>
#import <Realm/RLMObjectSchema.h>

// RLMSchema private interface
@interface RLMSchema ()
// class for string
+ (Class)classForString:(NSString *)className;
@end

#import <objc/runtime.h>

static id MCValueFromInvocation(id object, SEL selector) {
	NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:[object methodSignatureForSelector:selector]];
	invocation.target = object;
	invocation.selector = selector;
	[invocation invoke];

	__unsafe_unretained id result = nil;
	[invocation getReturnValue:&result];

	return result;
}

static NSString *MCTypeStringFromPropertyKey(Class class, NSString *key) {
	const objc_property_t property = class_getProperty(class, [key UTF8String]);
	if (!property) {
		[NSException raise:NSInternalInconsistencyException format:@"Class %@ does not have property %@", class, key];
	}
	const char *type = property_getAttributes(property);
	return [NSString stringWithUTF8String:type];
}

@interface NSString (MCJSON)

- (NSString *)snakeToCamelCase;
- (NSString *)camelToSnakeCase;

@end

@interface RLMObject (JSON_Internal)

// RLMObject private methods
+ (RLMObjectSchema *)sharedSchema;

@end

@implementation RLMObject (JSON)

static NSInteger const kCreateBatchSize = 100;

+ (NSArray *)createOrUpdateInRealm:(RLMRealm *)realm withJSONArray:(NSArray *)array {
    NSInteger count = array.count;
    NSMutableArray *result = [NSMutableArray array];

    for (NSInteger index=0; index*kCreateBatchSize<count; index++) {
        NSInteger size = MIN(kCreateBatchSize, count-index*kCreateBatchSize);
        @autoreleasepool {
            for (NSInteger subIndex=0; subIndex<size; subIndex++) {
                NSDictionary *dictionary = array[index*kCreateBatchSize+subIndex];
                id object = [self createOrUpdateInRealm:realm withJSONDictionary:dictionary];
                [result addObject:object];
            }
        }
    }

    return [result copy];
}

+ (instancetype)createOrUpdateInRealm:(RLMRealm *)realm withJSONDictionary:(NSDictionary *)dictionary {
	return [self createOrUpdateInRealm:realm withValue:[self mc_createObjectFromJSONDictionary:dictionary]];
}

+ (instancetype)objectInRealm:(RLMRealm *)realm withPrimaryKeyValue:(id)primaryKeyValue {
	NSString *primaryKey = nil;
	id value = primaryKeyValue;

	SEL selector = NSSelectorFromString(@"primaryKey");
	if ([self respondsToSelector:selector]) {
		primaryKey = MCValueFromInvocation(self, selector);
	}

	NSAssert(primaryKey, @"No primary key on class %@", [self description]);

	NSString *primaryPredicate = [NSString stringWithFormat:@"%@ = %%@", primaryKey];
	RLMResults *results = [self objectsInRealm:realm where:primaryPredicate, value];

	if (results.count > 0) {
		return results.firstObject;
	}
	else {
		return nil;
	}
}

- (instancetype)initWithJSONDictionary:(NSDictionary *)dictionary {
	self = [self initWithValue:[[self class] mc_createObjectFromJSONDictionary:dictionary]];
	if (self) {
	}
	return self;
}

- (NSDictionary *)JSONDictionary {
	return [self mc_createJSONDictionary];
}

- (id)primaryKeyValue {
	NSString *primaryKey = [[self class] primaryKey];
	NSAssert(primaryKey, @"No primary key on class %@", [self description]);

	return [self valueForKeyPath:primaryKey];
}

+ (id)primaryKeyValueFromJSONDictionary:(NSDictionary *)dictionary {
	NSString *primaryKey = [[self class] primaryKey];
	if (!primaryKey) {
		return nil;
	}

	NSDictionary *inboundMapping = [self mc_inboundMapping];
	NSString *primaryKeyPath = [[inboundMapping allKeysForObject:primaryKey] firstObject];
	id primaryKeyValue = [dictionary valueForKeyPath:primaryKeyPath];

	NSValueTransformer *transformer = [self mc_transformerForPropertyKey:primaryKey];
	if (primaryKeyValue && transformer) {
		primaryKeyValue = [transformer transformedValue:primaryKeyValue];
	}

	return primaryKeyValue;
}

- (void)performInTransaction:(void (^)())transaction {
	NSAssert(transaction != nil, @"No transaction block provided");
	if (self.realm) {
		[self.realm transactionWithBlock:transaction];
	}
	else {
		transaction();
	}
}

- (void)removeFromRealm {
	[self performInTransaction: ^{
	    [self.realm deleteObject:self];
	}];
}

#pragma mark - Private

+ (id)mc_createObjectFromJSONDictionary:(NSDictionary *)dictionary {
	NSMutableDictionary *result = [NSMutableDictionary dictionary];
	NSDictionary *mapping = [[self class] mc_inboundMapping];

	for (NSString *dictionaryKeyPath in mapping) {
		NSString *objectKeyPath = mapping[dictionaryKeyPath];

		id value = [dictionary valueForKeyPath:dictionaryKeyPath];

		if (value) {
			Class propertyClass = [[self class] mc_classForPropertyKey:objectKeyPath];

			NSValueTransformer *transformer = [[self class] mc_transformerForPropertyKey:objectKeyPath];
			if (transformer) {
				value = [transformer transformedValue:value];
			}
			else if ([propertyClass isSubclassOfClass:[RLMObject class]]) {
				if (!value || [value isEqual:[NSNull null]]) {
					continue;
				}

				if ([value isKindOfClass:[NSDictionary class]]) {
					value = [propertyClass mc_createObjectFromJSONDictionary:value];
				}
			}
			else if ([propertyClass isSubclassOfClass:[RLMArray class]]) {
				RLMProperty *property = [self mc_propertyForPropertyKey:objectKeyPath];
				Class elementClass = [RLMSchema classForString: property.objectClassName];

				NSMutableArray *array = [NSMutableArray array];
				for (id item in(NSArray*) value) {
					[array addObject:[elementClass mc_createObjectFromJSONDictionary:item]];
				}
				value = [array copy];
			}

			if ([objectKeyPath isEqualToString:@"self"]) {
				return value;
			}

			NSArray *keyPathComponents = [objectKeyPath componentsSeparatedByString:@"."];
			id currentDictionary = result;
			for (NSString *component in keyPathComponents) {
				if ([currentDictionary valueForKey:component] == nil) {
					[currentDictionary setValue:[NSMutableDictionary dictionary] forKey:component];
				}
				currentDictionary = [currentDictionary valueForKey:component];
			}
			
            value = value ?: [NSNull null];
			[result setValue:value forKeyPath:objectKeyPath];
		}
	}

	return [result copy];
}

- (id)mc_createJSONDictionary {
	NSMutableDictionary *result = [NSMutableDictionary dictionary];
	NSDictionary *mapping = [[self class] mc_outboundMapping];

	for (NSString *objectKeyPath in mapping) {
		NSString *dictionaryKeyPath = mapping[objectKeyPath];

		id value = [self valueForKeyPath:objectKeyPath];
		if (value) {
			Class propertyClass = [[self class] mc_classForPropertyKey:objectKeyPath];

			NSValueTransformer *transformer = [[self class] mc_transformerForPropertyKey:objectKeyPath];
			if (transformer) {
				value = [transformer reverseTransformedValue:value];
			}
			else if ([propertyClass isSubclassOfClass:[RLMObject class]]) {
				value = [value mc_createJSONDictionary];
			}
			else if ([propertyClass isSubclassOfClass:[RLMArray class]]) {
				NSMutableArray *array = [NSMutableArray array];
				for (id item in(RLMArray *) value) {
					[array addObject:[item mc_createJSONDictionary]];
				}
				value = [array copy];
			}

			if ([dictionaryKeyPath isEqualToString:@"self"]) {
				return value;
			}

			NSArray *keyPathComponents = [dictionaryKeyPath componentsSeparatedByString:@"."];
			id currentDictionary = result;
			for (NSString *component in keyPathComponents) {
				if ([currentDictionary valueForKey:component] == nil) {
					[currentDictionary setValue:[NSMutableDictionary dictionary] forKey:component];
				}
				currentDictionary = [currentDictionary valueForKey:component];
			}

			[result setValue:value forKeyPath:dictionaryKeyPath];
		} else {
			[result setValue:[NSNull null] forKeyPath:dictionaryKeyPath];
		}
	}

	return [result copy];
}

#pragma mark - Properties

+ (NSDictionary *)mc_defaultInboundMapping {
    RLMObjectSchema *schema = [self sharedSchema];

	NSMutableDictionary *result = [NSMutableDictionary dictionary];
    for (RLMProperty *property in schema.properties) {
        result[[property.name camelToSnakeCase]] = property.name;

    }

	return [result copy];
}

+ (NSDictionary *)mc_defaultOutboundMapping {
    RLMObjectSchema *schema = [self sharedSchema];

    NSMutableDictionary *result = [NSMutableDictionary dictionary];
    for (RLMProperty *property in schema.properties) {
        result[property.name] = [property.name camelToSnakeCase];

    }

	return [result copy];
}

#pragma mark - Convenience Methods

+ (NSDictionary *)mc_inboundMapping {
    static NSMutableDictionary *mappingForClassName = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        mappingForClassName = [NSMutableDictionary dictionary];
    });
    @synchronized(mappingForClassName) {
        NSDictionary *mapping = mappingForClassName[[self className]];
        if (!mapping) {
            SEL selector = NSSelectorFromString(@"JSONInboundMappingDictionary");
            if ([self respondsToSelector:selector]) {
                mapping = MCValueFromInvocation(self, selector);
            }
            else {
                mapping = [self mc_defaultInboundMapping];
            }
            mappingForClassName[[self className]] = mapping;
        }
        return mapping;
    }
}

+ (NSDictionary *)mc_outboundMapping {
    static NSMutableDictionary *mappingForClassName = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        mappingForClassName = [NSMutableDictionary dictionary];
    });

    @synchronized(mappingForClassName) {
        NSDictionary *mapping = mappingForClassName[[self className]];
        if (!mapping) {
            SEL selector = NSSelectorFromString(@"JSONOutboundMappingDictionary");
            if ([self respondsToSelector:selector]) {
                mapping = MCValueFromInvocation(self, selector);
            }
            else {
                mapping = [self mc_defaultOutboundMapping];
            }
            mappingForClassName[[self className]] = mapping;
        }
        return mapping;
    }
}

+ (RLMProperty *)mc_propertyForPropertyKey:(NSString *)key {
    RLMObjectSchema *schema = [self sharedSchema];
    for (RLMProperty *property in schema.properties) {
        if ([property.name isEqualToString:key]) {
            return property;
        }
    }
    return nil;
}

+ (Class)mc_classForPropertyKey:(NSString *)key {
	NSString *attributes = MCTypeStringFromPropertyKey(self, key);
	if ([attributes hasPrefix:@"T@"]) {
        static NSCharacterSet *set = nil;
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            set = [NSCharacterSet characterSetWithCharactersInString:@"\"<"];
        });

        @synchronized(set) {
            NSString *string;
            NSScanner *scanner = [NSScanner scannerWithString:attributes];
            scanner.charactersToBeSkipped = set;
            [scanner scanUpToCharactersFromSet:set intoString:NULL];
            [scanner scanUpToCharactersFromSet:set intoString:&string];
            return NSClassFromString(string);
        }
	}
	return nil;
}

+ (NSValueTransformer *)mc_transformerForPropertyKey:(NSString *)key {
	Class propertyClass = [self mc_classForPropertyKey:key];
	SEL selector = NSSelectorFromString([key stringByAppendingString:@"JSONTransformer"]);

	NSValueTransformer *transformer = nil;
	if ([self respondsToSelector:selector]) {
		transformer = MCValueFromInvocation(self, selector);
	}
	else if ([propertyClass isSubclassOfClass:[NSDate class]]) {
		transformer = [NSValueTransformer valueTransformerForName:MCJSONDateTimeTransformerName];
	}

	return transformer;
}

@end

@implementation NSString (MCJSON)

- (NSString *)snakeToCamelCase {
	NSScanner *scanner = [NSScanner scannerWithString:self];
	NSCharacterSet *underscoreSet = [NSCharacterSet characterSetWithCharactersInString:@"_"];
	scanner.charactersToBeSkipped = underscoreSet;

	NSMutableString *result = [NSMutableString string];
	NSString *buffer = nil;

	while (![scanner isAtEnd]) {
		BOOL atStartPosition = scanner.scanLocation == 0;
		[scanner scanUpToCharactersFromSet:underscoreSet intoString:&buffer];
		[result appendString:atStartPosition ? buffer:[buffer capitalizedString]];
	}

	return result;
}

- (NSString *)camelToSnakeCase {
	NSScanner *scanner = [NSScanner scannerWithString:self];
	NSCharacterSet *uppercaseSet = [NSCharacterSet uppercaseLetterCharacterSet];
	scanner.charactersToBeSkipped = uppercaseSet;

	NSMutableString *result = [NSMutableString string];
	NSString *buffer = nil;

	while (![scanner isAtEnd]) {
		[scanner scanUpToCharactersFromSet:uppercaseSet intoString:&buffer];
		[result appendString:[buffer lowercaseString]];

		if (![scanner isAtEnd]) {
			[result appendString:@"_"];
			[result appendString:[[self substringWithRange:NSMakeRange(scanner.scanLocation, 1)] lowercaseString]];
		}
	}

	return result;
}

@end

@implementation RLMArray (JSON)

- (NSArray *)NSArray {
	NSMutableArray *array = [NSMutableArray arrayWithCapacity:self.count];
	for (id object in self) {
		[array addObject:object];
	}
	return [array copy];
}

- (NSArray *)JSONArray {
	NSMutableArray *array = [NSMutableArray array];
	for (RLMObject *object in self) {
		[array addObject:[object JSONDictionary]];
	}
	return [array copy];
}

@end
