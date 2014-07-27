//
//  MCEpisode.h
//  RealmJSONDemo
//
//  Created by Matthew Cheok on 27/7/14.
//  Copyright (c) 2014 Matthew Cheok. All rights reserved.
//

#import <Realm/Realm.h>

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

// This protocol enables typed collections. i.e.:
// RLMArray<MCEpisode>
RLM_ARRAY_TYPE(MCEpisode)
