Realm+JSON ![License MIT](https://go-shields.herokuapp.com/license-MIT-blue.png)
==========

[![Badge w/ Version](https://cocoapod-badges.herokuapp.com/v/Realm+JSON/badge.png)](https://github.com/matthewcheok/Realm-JSON)
[![Badge w/ Platform](https://cocoapod-badges.herokuapp.com/p/Realm+JSON/badge.svg)](https://github.com/matthewcheok/Realm-JSON)

A concise Mantle-like way of working with [Realm](https://github.com/realm/realm-cocoa) and JSON.

## Installation

Add the following to your [CocoaPods](http://cocoapods.org/) Podfile

    pod 'Realm+JSON', '~> 0.1'

or clone as a git submodule,

or just copy files in the ```Realm+JSON``` folder into your project.

## Using Realm+JSON

Simply declare your model as normal:

    typedef NS_ENUM(NSInteger, MCEpisodeType) {
        MCEpisodeTypeFree = 0,
        MCEpisodeTypePaid
    };

    @interface MCEpisode : RLMObject

    @property NSInteger episodeID;
    @property NSInteger episodeNumber;
    @property MCEpisodeType episodeType;

    @property NSString *title;
    @property NSString *subtitle;
    @property NSString *thumbnailURL;

    @property NSDate *publishedDate;

    @end

    RLM_ARRAY_TYPE(MCEpisode)

Then pass the result of `NSJSONSerialization` or `AFNetworking` as follows:

      [MCEpisode createInRealm:[RLMRealm defaultRealm] withJSONArray:array];

or

      [MCEpisode createInRealm:[RLMRealm defaultRealm] withJSONDictionary:dictionary];

When you specify a `primaryKey` (see below), objects in the realm with same primary key value will be replaced instead of a duplicate version of the object added.

### Configuration

You should specify the inbound and outbound JSON mapping on your `RLMObject` subclass like this:

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

Leaving out either one of the above will result in a mapping that assumes camelCase for your properties which map to snake_case for the JSON equivalents.

Specify the primary key property like this:

    + (NSString *)primaryKey {
      return @"episodeID";
    }

As you can do with Mantle, you can specify `NSValueTransformers` for your properties:

    + (NSValueTransformer *)episodeTypeJSONTransformer {
      return [MCJSONValueTransformer valueTransformerWithMappingDictionary:@{
                  @"free": @(MCEpisodeTypeFree),
                  @"paid": @(MCEpisodeTypePaid)
          }];
    }

## License

Realm+JSON is under the MIT license.
