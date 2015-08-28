Realm+JSON ![License MIT](https://go-shields.herokuapp.com/license-MIT-blue.png)
==========

[![Badge w/ Version](https://cocoapod-badges.herokuapp.com/v/Realm+JSON/badge.png)](https://github.com/matthewcheok/Realm-JSON)
[![Badge w/ Platform](https://cocoapod-badges.herokuapp.com/p/Realm+JSON/badge.svg)](https://github.com/matthewcheok/Realm-JSON)

A concise [Mantle](https://github.com/Mantle/Mantle)-like way of working with [Realm](https://github.com/realm/realm-cocoa) and JSON.

## Breaking Change

- Method `- deepCopy` replaces the previous functionality of `- shallowCopy`, which no longer maintains an object's primary key
- Updated to use native primary key support in Realm 0.85.0
- Update your code to use methods `-createOrUpdateInRealm:withJSONArray:` or `-createOrUpdateInRealm:withJSONDictionary:`
- You must wrap these methods in a write transaction (between `[realm beginWriteTransaction];` and `[realm commitWriteTransaction];`)
- These methods call `-createOrUpdateInRealm:withObject:` behind the scenes for performance.

## Installation

Add the following to your [CocoaPods](http://cocoapods.org/) Podfile

    pod 'Realm+JSON', '~> 0.2'

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

      [MCEpisode createOrUpdateInRealm:[RLMRealm defaultRealm] withJSONArray:array];

or

      [MCEpisode createOrUpdateInRealm:[RLMRealm defaultRealm] withJSONDictionary:dictionary];

Use the `-JSONDictionary` method to get a JSON-ready dictionary for your network requests.

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

As you can do with Mantle, you can specify `NSValueTransformers` for your properties:

    + (NSValueTransformer *)episodeTypeJSONTransformer {
      return [MCJSONValueTransformer valueTransformerWithMappingDictionary:@{
                  @"free": @(MCEpisodeTypeFree),
                  @"paid": @(MCEpisodeTypePaid)
          }];
    }

## Working with background threads

Realm requires that you use different `RLMRealm` objects when working across different threads. This means you shouldn't access the same `RLMObject` instances from different threads. To make this easier to work with, use `- primaryKeyValue` to retrieve the wrapped primary key value from an instance and query for it later using `+ objectInRealm:withPrimaryKeyValue:`.

    id primaryKeyValue = [episode primaryKeyValue];
    dispatch_async(dispatch_get_main_queue(), ^{
        MCEpisode *episode = [MCEpisode objectInRealm:[RLMRealm defaultRealm] withPrimaryKeyValue:primaryKeyValue];

        // do something with episode here
    });


## Working with (temporary) copies (RLMObject+Copying)

If you need to display UI that may or may not change an object's properties, it is sometimes useful to work with an object not bound to a realm as a backing model object. When it is time to commit changes, the properties can be copied back to the stored model.

Methods `- shallowCopy` and `- mergePropertiesFromObject:` are provided. The later of which needs to be performed in a realm transaction.

    #import <Realm+Copying.h>

    MCEpisode *anotherEpisode = [episode shallowCopy];
    anotherEpisode.title = @"New title";

    // ...

    [episode performInTransaction:^{
        [episode mergePropertiesFromObject:anotherEpisode];
    }];

Additionally, method `- deepCopy` is provided. Unlike `- shallowCopy`, it maintains the object's primary key.

## License

Realm+JSON is under the MIT license.
