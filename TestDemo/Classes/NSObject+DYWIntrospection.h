//
//  NSObject+DYWIntrospection.h
//  runtimeDemo
//
//  Created by 杜玉伟 on 2019/4/22.
//  Copyright © 2019 杜玉伟. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSObject (DYWIntrospection)

+ (NSArray *)classes;

+ (NSArray *)properties;

+ (NSArray *)instanceVariables;

+ (NSArray *)classMethods;

+ (NSArray *)instanceMethods;

+ (NSArray *)protocols;

+ (NSDictionary *)descriptionForProtocol:(Protocol *)protocol;

+ (NSString *)parentClassHierarchy;

@end

NS_ASSUME_NONNULL_END
