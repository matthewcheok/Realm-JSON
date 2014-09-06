//
//  RLMObject+JSON.m
//  RealmJSONDemo
//
//  Created by Matthew Cheok on 27/7/14.
//  Copyright (c) 2014 Matthew Cheok. All rights reserved.
//

#import "RLMObject+JSON.h"
#import "RLMObject+MCInternal.h"

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

@implementation RLMObject (JSON)

+ (NSArray *)createInRealm:(RLMRealm *)realm withJSONArray:(NSArray *)array {
	return [self createInRealm:realm withJSONArray:array returnNewObjectsOnly:NO];
}

+ (NSArray *)createInRealm:(RLMRealm *)realm withJSONArray:(NSArray *)array returnNewObjectsOnly:(BOOL)newOnly {
	NSMutableArray *result = [NSMutableArray array];

	[realm beginWriteTransaction];
	for (NSDictionary *dictionary in array) {
		if (newOnly) {
			id primaryKeyValue = [self primaryKeyValueFromJSONDictionary:dictionary];
			BOOL exists = primaryKeyValue && [self objectInRealm:realm withPrimaryKeyValue:primaryKeyValue] != nil;

			id object = [self mc_createOrUpdateInRealm:realm withJSONDictionary:dictionary];
			if (!exists) {
				[result addObject:object];
			}
		}
		else {
			id object = [self mc_createOrUpdateInRealm:realm withJSONDictionary:dictionary];
			[result addObject:object];
		}
	}
	[realm commitWriteTransaction];

	return [result copy];
}

+ (instancetype)createInRealm:(RLMRealm *)realm withJSONDictionary:(NSDictionary *)dictionary {
	[realm beginWriteTransaction];
	id object = [self mc_createOrUpdateInRealm:realm withJSONDictionary:dictionary];
	[realm commitWriteTransaction];

	return object;
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
	RLMArray *array = [self objectsInRealm:realm where:primaryPredicate, value];

	if (array.count > 0) {
		return array.firstObject;
	}
	else {
		return nil;
	}
}

- (instancetype)initWithJSONDictionary:(NSDictionary *)dictionary {
	self = [super init];
	if (self) {
		[self mc_setValuesFromJSONDictionary:dictionary inRealm:nil];
	}
	return self;
}

- (NSDictionary *)JSONDictionary {
	return [self mc_createJSONDictionary];
}

- (id)primaryKeyValue {
	NSString *primaryKey = [[self class] mc_primaryKey];
	NSAssert(primaryKey, @"No primary key on class %@", [self description]);

	return [self valueForKeyPath:primaryKey];
}

+ (id)primaryKeyValueFromJSONDictionary:(NSDictionary *)dictionary {
	NSString *primaryKey = [[self class] mc_primaryKey];
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

+ (NSString *)mc_primaryKey {
	NSString *primaryKey = nil;
	SEL selector = NSSelectorFromString(@"primaryKey");
	if ([self respondsToSelector:selector]) {
		primaryKey = MCValueFromInvocation(self, selector);
	}

	return primaryKey;
}

+ (instancetype)mc_createFromJSONDictionary:(NSDictionary *)dictionary {
	id object = [[self alloc] init];
	[object mc_setValuesFromJSONDictionary:dictionary inRealm:nil];
	return object;
}

+ (instancetype)mc_createOrUpdateInRealm:(RLMRealm *)realm withJSONDictionary:(NSDictionary *)dictionary {
	if (!dictionary || [dictionary isEqual:[NSNull null]]) {
		return nil;
	}

	id object = nil;
	id primaryKeyValue = [self primaryKeyValueFromJSONDictionary:dictionary];

	if (primaryKeyValue) {
		object = [self objectInRealm:realm withPrimaryKeyValue:primaryKeyValue];
	}

	if (object) {
		[object mc_setValuesFromJSONDictionary:dictionary inRealm:realm];
	}
	else {
		object = [[self alloc] init];
		[object mc_setValuesFromJSONDictionary:dictionary inRealm:realm];
		[realm addObject:object];
	}

	return object;
}

- (void)mc_setValuesFromJSONDictionary:(NSDictionary *)dictionary inRealm:(RLMRealm *)realm {
	NSDictionary *mapping = [[self class] mc_inboundMapping];

	for (NSString *dictionaryKeyPath in mapping) {
		NSString *objectKeyPath = mapping[dictionaryKeyPath];

		id value = [dictionary valueForKeyPath:dictionaryKeyPath];

		if (value) {
			Class modelClass = [[self class] mc_normalizedClass];
			Class propertyClass = [modelClass mc_classForPropertyKey:objectKeyPath];

			if ([propertyClass isSubclassOfClass:[RLMObject class]]) {
				if (!value || [value isEqual:[NSNull null]]) {
					continue;
				}

				if (realm) {
					value = [propertyClass mc_createOrUpdateInRealm:realm withJSONDictionary:value];
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
					if (realm) {
						id item = [itemClass mc_createOrUpdateInRealm:realm withJSONDictionary:itemDictionary];
						[array addObject:item];
					}
					else {
						id item = [itemClass mc_createFromJSONDictionary:value];
						[array addObject:item];
					}
				}
				continue;
			}
			else {
				NSValueTransformer *transformer = [[self class] mc_transformerForPropertyKey:objectKeyPath];

				if (transformer) {
					if ([value isEqual:[NSNull null]]) {
						value = nil;
					}
					value = [transformer transformedValue:value];
					if (!value) {
						value = [NSNull null];
					}
				}

				if ([value isEqual:[NSNull null]]) {
					if ([propertyClass isSubclassOfClass:[NSDate class]]) {
						value = [NSDate distantPast];
					}
					else if ([propertyClass isSubclassOfClass:[NSString class]]) {
						value = @"";
					}
					else {
						value = @0;
					}
				}
			}

			[self setValue:value forKeyPath:objectKeyPath];
		}
	}
}

- (id)mc_createJSONDictionary {
	NSMutableDictionary *result = [NSMutableDictionary dictionary];
	NSDictionary *mapping = [[self class] mc_outboundMapping];

	for (NSString *objectKeyPath in mapping) {
		NSString *dictionaryKeyPath = mapping[objectKeyPath];

		id value = [self valueForKeyPath:objectKeyPath];
		if (value) {
			Class modelClass = [[self class] mc_normalizedClass];
			Class propertyClass = [modelClass mc_classForPropertyKey:objectKeyPath];

			if ([propertyClass isSubclassOfClass:[RLMObject class]]) {
				value = [value mc_createJSONDictionary];
			}
			else if ([propertyClass isSubclassOfClass:[RLMArray class]]) {
				NSMutableArray *array = [NSMutableArray array];
				for (id item in(RLMArray *) value) {
					[array addObject:[item mc_createJSONDictionary]];
				}
				value = [array copy];
			}
			else {
				NSValueTransformer *transformer = [modelClass mc_transformerForPropertyKey:objectKeyPath];

				if (value && transformer) {
					value = [transformer reverseTransformedValue:value];
				}
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
	Class objectClass = [self mc_normalizedClass];
	static NSMutableDictionary *mappingForClassName = nil;
	if (!mappingForClassName) {
		mappingForClassName = [NSMutableDictionary dictionary];
	}

	NSDictionary *mapping = mappingForClassName[[objectClass description]];
	if (!mapping) {
		SEL selector = NSSelectorFromString(@"JSONInboundMappingDictionary");
		if ([objectClass respondsToSelector:selector]) {
			mapping = MCValueFromInvocation(objectClass, selector);
		}
		else {
			mapping = [objectClass mc_defaultInboundMapping];
		}
		mappingForClassName[[objectClass description]] = mapping;
	}
	return mapping;
}

+ (NSDictionary *)mc_outboundMapping {
	Class objectClass = [self mc_normalizedClass];
	static NSMutableDictionary *mappingForClassName = nil;
	if (!mappingForClassName) {
		mappingForClassName = [NSMutableDictionary dictionary];
	}

	NSDictionary *mapping = mappingForClassName[[objectClass description]];
	if (!mapping) {
		SEL selector = NSSelectorFromString(@"JSONOutboundMappingDictionary");
		if ([objectClass respondsToSelector:selector]) {
			mapping = MCValueFromInvocation(objectClass, selector);
		}
		else {
			mapping = [objectClass mc_defaultOutboundMapping];
		}
		mappingForClassName[[objectClass description]] = mapping;
	}
	return mapping;
}

+ (Class)mc_classForPropertyKey:(NSString *)key {
	NSString *attributes = MCTypeStringFromPropertyKey(self, key);
	if ([attributes hasPrefix:@"T@"]) {
		static NSCharacterSet *set = nil;
		if (!set) {
			set = [NSCharacterSet characterSetWithCharactersInString:@"\"<"];
		}

		NSString *string;
		NSScanner *scanner = [NSScanner scannerWithString:attributes];
		scanner.charactersToBeSkipped = set;
		[scanner scanUpToCharactersFromSet:set intoString:NULL];
		[scanner scanUpToCharactersFromSet:set intoString:&string];
		return NSClassFromString(string);
	}
	return nil;
}

+ (NSValueTransformer *)mc_transformerForPropertyKey:(NSString *)key {
	Class modelClass = [[self class] mc_normalizedClass];
	Class propertyClass = [modelClass mc_classForPropertyKey:key];
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

@implementation RLMArray (SWAdditions)

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
