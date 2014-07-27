//
//  MCEpisode.m
//  RealmJSONDemo
//
//  Created by Matthew Cheok on 27/7/14.
//  Copyright (c) 2014 Matthew Cheok. All rights reserved.
//

#import "MCEpisode.h"
#import "RLMObject+JSON.h"

@implementation MCEpisode

+ (NSDictionary *)JSONInboundMappingDictionary {
	return @{
			   @"episode.title": @"title",
			   @"episode.description": @"subtitle",
			   @"episode.id": @"episodeID",
			   @"episode.episode_number": @"episodeNumber",
			   @"episode.episode_type": @"episodeType",
			   @"episode.thumbnail_url": @"thumbnailURL",
			   @"episode.published_at": @"publishedDate",
	};
}

+ (NSDictionary *)JSONOutboundMappingDictionary {
	return @{
			   @"title": @"title",
			   @"subtitle": @"episode.description",
			   @"episodeID": @"id",
			   @"episodeNumber": @"episode.number",
			   @"publishedDate": @"published_at",
	};
}

+ (NSString *)primaryKey {
	return @"episodeID";
}

+ (NSValueTransformer *)episodeTypeJSONTransformer {
	return [MCJSONValueTransformer valueTransformerWithMappingDictionary:@{
	            @"free": @(MCEpisodeTypeFree),
	            @"paid": @(MCEpisodeTypePaid)
			}];
}

// Specify default values for properties

+ (NSDictionary *)defaultPropertyValues {
	return @{ @"publishedDate": [NSDate date] };
}

// Specify properties to ignore (Realm won't persist these)

//+ (NSArray *)ignoredProperties
//{
//    return @[];
//}

@end
