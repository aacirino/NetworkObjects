//
//  NOResourceProtocol.h
//  NetworkObjects
//
//  Created by Alsey Coleman Miller on 10/1/13.
//  Copyright (c) 2013 CDA. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol NOUserProtocol;
@protocol NOClientProtocol;

@protocol NOResourceProtocol <NSObject>

#pragma mark - Network Access

// URL instances of this resource can be accessed from
+(NSString *)resourcePath;

// require authorization for this resource to be accessed
+(BOOL)requireSession;

#pragma mark - Attributes and Relationship paths

// Core Data attribute must be Integer type, is the numerical identifier of this resource
+(NSString *)resourceIDKey;

#pragma mark - Access

+(BOOL)userCanCreateNewInstance:(NSManagedObject<NOUserProtocol> *)user
                         client:(NSManagedObject<NOClientProtocol> *)client;

-(BOOL)isVisibleToUser:(NSManagedObject<NOUserProtocol> *)user
                client:(NSManagedObject<NOClientProtocol> *)client;

-(BOOL)isEditableByUser:(NSManagedObject<NOUserProtocol> *)user
                 client:(NSManagedObject<NOClientProtocol> *)client;

-(BOOL)attribute:(NSString *)attributeKey
 isVisibleToUser:(NSManagedObject<NOUserProtocol> *)user
          client:(NSManagedObject<NOClientProtocol> *)client;

-(BOOL)attribute:(NSString *)attributeKey
isEditableByUser:(NSManagedObject<NOUserProtocol> *)user
          client:(NSManagedObject<NOClientProtocol> *)client;

-(BOOL)relationship:(NSString *)relationshipKey
    isVisibleToUser:(NSManagedObject<NOUserProtocol> *)user
             client:(NSManagedObject<NOClientProtocol> *)client;

-(BOOL)relationship:(NSString *)relationshipKey
   isEditableByUser:(NSManagedObject<NOUserProtocol> *)user
             client:(NSManagedObject<NOClientProtocol> *)client;

#pragma mark - Resource Functions

// if you want to add a function like liking a post or adding a friend without write access to a user's friend relationship

+(NSSet *)resourceFunctions;

-(NSUInteger)performFunction:(NSString *)functionName
          recievedJsonObject:(NSDictionary *)recievedJsonObject
                    response:(NSDictionary **)jsonObjectResponse;


@end