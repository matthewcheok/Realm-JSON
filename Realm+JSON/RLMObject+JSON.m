 //
//  RLMObject+JSON.m
//  RealmJSONDemo
//
//  Created by Matthew Cheok on 27/7/14.
//  Copyright (c) 2014 Matthew Cheok. All rights reserved.
//

#import "RLMObject+JSON.h"
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
	const char *type = property_getAttributes(class_getProperty(class, [key UTF8String]));
	return [NSString stringWithUTF8String:type];
}

@interface NSString (MCJSON)

- (NSString *)snakeToCamelCase;
- (NSString *)camelToSnakeCase;

@end

@implementation RLMObject (JSON)

+ (void)createInRealm:(RLMRealm *)realm withJSONArray:(NSArray *)array {
	[realm beginWriteTransaction];
	for (NSDictionary *dictionary in array) {
		[self mc_createOrUpdateInRealm:realm withJSONDictionary:dictionary];
	}
	[realm commitWriteTransaction];
}

+ (instancetype)createInRealm:(RLMRealm *)realm withJSONDictionary:(NSDictionary *)dictionary {
	[realm beginWriteTransaction];
	id object = [self mc_createOrUpdateInRealm:realm withJSONDictionary:dictionary];
	[realm commitWriteTransaction];

	return object;
}

- (instancetype)initWithJSONDictionary:(NSDictionary *)dictionary {
	self = [super init];
	if (self) {
		[self mc_setValuesFromJSONDictionary:dictionary shouldModifiyRealm:NO];
	}
	return self;
}

- (NSDictionary *)JSONDictionary {
	return [self mc_createJSONDictionary];
}

#pragma mark - Private

+ (instancetype)mc_createFromJSONDictionary:(NSDictionary *)dictionary {
	id object = [[self alloc] init];
	[object mc_setValuesFromJSONDictionary:dictionary shouldModifiyRealm:NO];
	return object;
}

+ (instancetype)mc_createOrUpdateInRealm:(RLMRealm *)realm withJSONDictionary:(NSDictionary *)dictionary {
	static NSString *primaryKey = nil;
	static NSString *primaryPredicate = nil;
	static NSString *primarykeyPath = nil;
	if (!primaryKey) {
		SEL selector = NSSelectorFromString(@"primaryKey");
		if ([self respondsToSelector:selector]) {
			primaryKey = MCValueFromInvocation(self, selector);
		}

		if (primaryKey) {
			NSDictionary *inboundMapping = [self mc_inboundMapping];
			primarykeyPath = [[inboundMapping allKeysForObject:primaryKey] firstObject];
			primaryPredicate = [NSString stringWithFormat:@"%@ = %%@", primaryKey];
		}
	}

	id object = nil;
	if (primaryKey) {
		id primaryKeyValue = [dictionary valueForKeyPath:primarykeyPath];
		RLMArray *array = [self objectsInRealm:realm where:primaryPredicate, primaryKeyValue];

		if (array.count > 0) {
			object = [array firstObject];
			[object mc_setValuesFromJSONDictionary:dictionary shouldModifiyRealm:YES];
//			NSLog(@"updated object with \"%@\" value %@", primaryKey, primaryKeyValue);
		}
	}

	if (!object) {
		object = [[self alloc] init];
		[object mc_setValuesFromJSONDictionary:dictionary shouldModifiyRealm:YES];
		[realm addObject:object];
//		NSLog(@"created object with \"%@\" value %@", primaryKey, [dictionary valueForKeyPath:primarykeyPath]);
	}

	return object;
}

- (void)mc_setValuesFromJSONDictionary:(NSDictionary *)dictionary shouldModifiyRealm:(BOOL)shouldModifyRealm {
	NSDictionary *mapping = [[self class] mc_inboundMapping];

	for (NSString *dictionaryKeyPath in mapping) {
		NSString *objectKeyPath = mapping[dictionaryKeyPath];

		id value = [dictionary valueForKeyPath:dictionaryKeyPath];

		if (value) {
			Class modelClass = [self class];
			Class propertyClass = [modelClass mc_classForPropertyKey:objectKeyPath];
			SEL selector = NSSelectorFromString([objectKeyPath stringByAppendingString:@"JSONTransformer"]);

			if ([propertyClass isSubclassOfClass:[RLMObject class]]) {
				if (shouldModifyRealm) {
					value = [propertyClass mc_createOrUpdateInRealm:self.realm withJSONDictionary:value];
				}
				else {
					value = [propertyClass mc_createFromJSONDictionary:value];
				}
			}
			else if ([propertyClass isSubclassOfClass:[RLMArray class]]) {
				RLMArray *array = [self valueForKeyPath:objectKeyPath];
				[array removeAllObjects];

				Class itemClass = NSClassFromString(array.objectClassName);
				for (NSDictionary *itemDictionary in(NSArray *) value) {
					if (shouldModifyRealm) {
						id item = [itemClass mc_createOrUpdateInRealm:self.realm withJSONDictionary:itemDictionary];
						[array addObject:item];
					}
					else {
						id item = [itemClass mc_createFromJSONDictionary:value];
						[array addObject:item];
					}
				}
			}
			else {
				NSValueTransformer *transformer = nil;
				if ([modelClass respondsToSelector:selector]) {
					transformer = MCValueFromInvocation(modelClass, selector);
				}
				else if ([propertyClass isSubclassOfClass:[NSDate class]]) {
					transformer = [NSValueTransformer valueTransformerForName:MCJSONDateTimeTransformerName];
				}

				if (transformer) {
					value = [transformer transformedValue:value];
				}
			}

			[self setValue:value forKeyPath:objectKeyPath];
		}
	}
}

- (NSDictionary *)mc_createJSONDictionary {
	NSMutableDictionary *result = [NSMutableDictionary dictionary];
	NSDictionary *mapping = [[self class] mc_outboundMapping];

	for (NSString *objectKeyPath in mapping) {
		NSString *dictionaryKeyPath = mapping[objectKeyPath];

		id value = [self valueForKeyPath:objectKeyPath];
		if (value) {
			Class modelClass = [self class];
			Class propertyClass = [modelClass mc_classForPropertyKey:objectKeyPath];
			SEL selector = NSSelectorFromString([objectKeyPath stringByAppendingString:@"JSONTransformer"]);

            if ([propertyClass isSubclassOfClass:[RLMObject class]]) {
                value = [value mc_createJSONDictionary];
			}
			else if ([propertyClass isSubclassOfClass:[RLMArray class]]) {
                NSMutableArray *array = [NSMutableArray array];
                for (id item in (RLMArray *)value) {
                    [array addObject:[item mc_createJSONDictionary]];
                }
                value = [array copy];
			}
			else {
				NSValueTransformer *transformer = nil;
				if ([modelClass respondsToSelector:selector]) {
					transformer = MCValueFromInvocation(modelClass, selector);
				}
				else if ([propertyClass isSubclassOfClass:[NSDate class]]) {
					transformer = [NSValueTransformer valueTransformerForName:MCJSONDateTimeTransformerName];
				}
                
				if (transformer) {
					value = [transformer reverseTransformedValue:value];
				}
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
		}
	}

	return [result copy];
}

#pragma mark - Properties

+ (NSDictionary *)mc_defaultInboundMapping {
	unsigned count = 0;
	objc_property_t *properties = class_copyPropertyList(self, &count);

	NSMutableDictionary *result = [NSMutableDictionary dictionary];
	for (unsigned i = 0; i < count; i++) {
		objc_property_t property = properties[i];
		NSString *name = [NSString stringWithUTF8String:property_getName(property)];
		result[[name camelToSnakeCase]] = name;
	}

	return [result copy];
}

+ (NSDictionary *)mc_defaultOutboundMapping {
	unsigned count = 0;
	objc_property_t *properties = class_copyPropertyList(self, &count);

	NSMutableDictionary *result = [NSMutableDictionary dictionary];
	for (unsigned i = 0; i < count; i++) {
		objc_property_t property = properties[i];
		NSString *name = [NSString stringWithUTF8String:property_getName(property)];
		result[name] = [name camelToSnakeCase];
	}

	return [result copy];
}

#pragma mark - Convenience Methods

+ (NSDictionary *)mc_inboundMapping {
	static NSDictionary *mapping = nil;
	if (!mapping) {
        NSString *className = NSStringFromClass(self);
        className = [className stringByReplacingOccurrencesOfString:@"RLMAccessor_" withString:@""];
        className = [className stringByReplacingOccurrencesOfString:@"RLMStandalone_" withString:@""];
        Class objectClass = NSClassFromString(className);

		SEL selector = NSSelectorFromString(@"JSONInboundMappingDictionary");
		if ([objectClass respondsToSelector:selector]) {
			mapping = MCValueFromInvocation(objectClass, selector);
		}
		else {
			mapping = [objectClass mc_defaultInboundMapping];
		}
	}
	return mapping;
}

+ (NSDictionary *)mc_outboundMapping {
	static NSDictionary *mapping = nil;
	if (!mapping) {
        NSString *className = NSStringFromClass(self);
        className = [className stringByReplacingOccurrencesOfString:@"RLMAccessor_" withString:@""];
        className = [className stringByReplacingOccurrencesOfString:@"RLMStandalone_" withString:@""];
        Class objectClass = NSClassFromString(className);
        
		SEL selector = NSSelectorFromString(@"JSONOutboundMappingDictionary");
		if ([objectClass respondsToSelector:selector]) {
			mapping = MCValueFromInvocation(objectClass, selector);
		}
		else {
			mapping = [objectClass mc_defaultOutboundMapping];
		}
	}
	return mapping;
}

+ (Class)mc_classForPropertyKey:(NSString *)key {
	NSString *attributes = MCTypeStringFromPropertyKey(self, key);
	if ([attributes hasPrefix:@"T@"]) {
		NSString *string;
		NSScanner *scanner = [NSScanner scannerWithString:attributes];
		[scanner scanUpToString:@"\"" intoString:NULL];
		[scanner scanString:@"\"" intoString:NULL];
		[scanner scanUpToString:@"\"" intoString:&string];
		return NSClassFromString(string);
	}
	return nil;
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
