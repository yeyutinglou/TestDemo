//
//  NSObject+DYWIntrospection.m
//  runtimeDemo
//
//  Created by 杜玉伟 on 2019/4/22.
//  Copyright © 2019 杜玉伟. All rights reserved.
//

#import "NSObject+DYWIntrospection.h"
#import <objc/message.h>

@interface NSString (DYWIntrospection)

+ (NSString *)decodeType:(const char *)cString;

@end

@implementation NSString (DYWIntrospection)
//https://developer.apple.com/library/mac/#documentation/Cocoa/Conceptual/ObjCRuntimeGuide/Articles/ocrtTypeEncodings.html
+ (NSString *)decodeType:(const char *)cString {
    if (!strcmp(cString, @encode(char))) return @"char";
    if (!strcmp(cString, @encode(int))) return @"int";
    if (!strcmp(cString, @encode(short))) return @"short";
    if (!strcmp(cString, @encode(long))) return @"long";
    if (!strcmp(cString, @encode(long long))) return @"long long";
    
    if (!strcmp(cString, @encode(unsigned char))) return @"unsigned char";
    if (!strcmp(cString, @encode(unsigned int))) return @"unsigned int";
    if (!strcmp(cString, @encode(unsigned short))) return @"unsigned short";
    if (!strcmp(cString, @encode(unsigned long))) return @"unsigned long";
    if (!strcmp(cString, @encode(unsigned long long))) return @"unsigned long long";
    
    if (!strcmp(cString, @encode(float))) return @"float";
    if (!strcmp(cString, @encode(double))) return @"double";

    if (!strcmp(cString, @encode(BOOL))) return @"BOOL";
    if (!strcmp(cString, @encode(void))) return @"void";
    if (!strcmp(cString, @encode(char *))) return @"char *";
    if (!strcmp(cString, @encode(id))) return @"id";
    if (!strcmp(cString, @encode(Class))) return @"class";
    if (!strcmp(cString, @encode(SEL))) return @"SEL";
    
    NSString *result = [NSString stringWithCString:cString encoding:NSUTF8StringEncoding];
    if ([[result substringToIndex:1] isEqualToString:@"@"]  && [result rangeOfString:@"?"].location == NSNotFound) {
        result = [[result substringWithRange:NSMakeRange(2, result.length - 3)] stringByAppendingString:@"*"];
    } else if ([[result substringToIndex:1] isEqualToString:@"^"]) {
        result = [NSString stringWithFormat:@"%@ *",
                  [NSString decodeType:[[result substringFromIndex:1] cStringUsingEncoding:NSUTF8StringEncoding]]];
    }
    return result;
}

@end

static void getSuper(Class class, NSMutableString *result) {
    [result appendFormat:@" -> %@", NSStringFromClass(class)];
    if ([class superclass]) {
        getSuper([class superclass], result);
    }
}

@implementation NSObject (DYWIntrospection)


+ (NSArray *)classes {
    unsigned int classesCount;
    Class *classes = objc_copyClassList(&classesCount);
    NSMutableArray *result = [NSMutableArray new];
    for (unsigned int i = 0; i < classesCount; i++) {
        [result addObject:NSStringFromClass(classes[i])];
    }
    return [result sortedArrayUsingSelector:@selector(compare:)];
}

+ (NSArray *)properties {
    unsigned int outCount;
    objc_property_t *properties = class_copyPropertyList([self class], &outCount);
    NSMutableArray *result = [NSMutableArray new];
    for (unsigned int i = 0; i < outCount; i++) {
        [result addObject:[self formattedProperty:properties[i]]];
    }
    return [result sortedArrayUsingSelector:@selector(compare:)];
}

+ (NSArray *)instanceVariables {
    unsigned int outCount;
    Ivar *ivars = class_copyIvarList([self class], &outCount);
    NSMutableArray *result = [NSMutableArray new];
    
    for (unsigned int i = 0; i < outCount; i++) {
        NSString *type = [NSString decodeType:ivar_getTypeEncoding(ivars[i])];
        NSString *name = [NSString stringWithCString:ivar_getName(ivars[i]) encoding:NSUTF8StringEncoding];
        NSString *ivarDescription = [NSString stringWithFormat:@"%@ %@", type, name];
        [result addObject:ivarDescription];
    }
    free(ivars);
    return result.count ? [result copy] : nil;
}


+ (NSArray *)classMethods {
    return [self methodsForClass:object_getClass([self class]) typeFormat:@"+"];
}

+ (NSArray *)instanceMethods {
    return [self methodsForClass:[self class] typeFormat:@"-"];
}


+ (NSArray *)protocols {
    unsigned int outCount;
    Protocol * const *protocols = class_copyProtocolList([self class], &outCount);
    
    NSMutableArray *result = [NSMutableArray new];
    
    for (unsigned int i = 0; i < outCount; i++) {
        unsigned int adoptedCount;
        Protocol * const *adopedProtocols = protocol_copyProtocolList(protocols[i], &adoptedCount);
        NSString *protocolName = [NSString stringWithCString:protocol_getName(protocols[i]) encoding:NSUTF8StringEncoding];
        
        NSMutableArray *adoptedProtocolNames = [NSMutableArray new];
        for (unsigned int idx = 0; idx < adoptedCount; idx++) {
            [adoptedProtocolNames addObject:[NSString stringWithCString:protocol_getName(adopedProtocols[i]) encoding:NSUTF8StringEncoding]];
        }
        NSString *protocolDescription = protocolName;
        if (adoptedProtocolNames.count) {
            protocolDescription = [NSString stringWithFormat:@"%@ <%@>", protocolName, [adoptedProtocolNames componentsJoinedByString:@", "]];
        }
        [result addObject:protocolDescription];
    }
    return result.count ? [result copy] : nil;
}


+ (NSDictionary *)descriptionForProtocol:(Protocol *)protocol {
    NSMutableDictionary *methodsAndProperties = [NSMutableDictionary new];
    NSArray *requiredMethods = [[[self class] formattedMethodsForProtocol:protocol required:YES instance:NO] arrayByAddingObjectsFromArray:[[self class] formattedMethodsForProtocol:protocol required:YES instance:YES]];
    
    NSArray *optionalMethods = [[[self class] formattedMethodsForProtocol:protocol required:NO instance:NO] arrayByAddingObjectsFromArray:[[self class] formattedMethodsForProtocol:protocol required:NO instance:YES]];
    
    unsigned int propertiesCount;
    NSMutableArray *propertyDescriptions = [NSMutableArray new];
    objc_property_t *properties = protocol_copyPropertyList(protocol, &propertiesCount);
    for (unsigned int i = 0; i < propertiesCount; i++) {
        [propertyDescriptions addObject:[self formattedProperty:properties[i]]];
    }
    
    if (requiredMethods.count) {
        [methodsAndProperties setObject:requiredMethods forKey:@"@required"];
    }
    if (optionalMethods.count) {
        [methodsAndProperties setObject:optionalMethods forKey:@"@optional"];
    }
    if (propertyDescriptions.count) {
        [methodsAndProperties setObject:[propertyDescriptions copy] forKey:@"@properties"];
    }
    
    free(properties);
    return methodsAndProperties.count ? [methodsAndProperties copy] : nil;
    
}


+ (NSString *)parentClassHierarchy {
    NSMutableString *result = [NSMutableString new];
    getSuper([self class], result);
    return result;
}

#pragma mark - Private Method

+ (NSArray *)formattedMethodsForProtocol:(Protocol *)protocol required:(BOOL)required instance:(BOOL)instance {
    unsigned int methodCount;
    struct objc_method_description *methods = protocol_copyMethodDescriptionList(protocol, required, instance, &methodCount);
    NSMutableArray *methodsDescription = [NSMutableArray new];
    for (unsigned int i = 0; i < methodCount; i++) {
        [methodsDescription addObject:[NSString stringWithFormat:@"%@ (%@)%@", instance ? @"-" : @"+", @"void", NSStringFromSelector(methods[i].name)]];
    }
    free(methods);
    return [methodsDescription copy];
}

+ (NSString *)formattedProperty:(objc_property_t)property {
    unsigned int outCount;
    objc_property_attribute_t *attrs = property_copyAttributeList(property, &outCount);
    NSMutableDictionary *attributes = [NSMutableDictionary new];
    for (unsigned int i = 0; i < outCount; i++) {
        NSString *name = [NSString stringWithCString:attrs[i].name encoding:NSUTF8StringEncoding];
        NSString *value = [NSString stringWithCString:attrs[i].value encoding:NSUTF8StringEncoding];
        [attributes setObject:value forKey:name];
    }
    free(attrs);
    NSMutableString *proStr = [NSMutableString stringWithFormat:@"@property "];
    NSMutableArray *attrsArr = [NSMutableArray new];
    
    //https://developer.apple.com/library/mac/#documentation/Cocoa/Conceptual/ObjCRuntimeGuide/Articles/ocrtPropertyIntrospection.html#//apple_ref/doc/uid/TP40008048-CH101-SW5
    [attrsArr addObject:[attributes objectForKey:@"N"] ? @"nonatomic" : @"atmoic"];
    
    if ([attributes objectForKey:@"&"]) {
        [attrsArr addObject:@"strong"];
    } else if ([attributes objectForKey:@"C"]) {
        [attrsArr addObject:@"copy"];
    } else if ([attributes objectForKey:@"W"]) {
        [attrsArr addObject:@"weak"];
    } else {
        [attrsArr addObject:@"assign"];
    }
    
    if ([attributes objectForKey:@"R"]) {
        [attrsArr addObject:@"retain"];
    }
    if ([attributes objectForKey:@"G"]) {
        [attrsArr addObject:[NSString stringWithFormat:@"getter=%@", [attributes objectForKey:@"G"]]];
    }
    if ([attributes objectForKey:@"S"]) {
         [attrsArr addObject:[NSString stringWithFormat:@"setter=%@", [attributes objectForKey:@"S"]]];
    }
    [proStr appendFormat:@"(%@) %@ %@", [attrsArr componentsJoinedByString:@", "], [NSString decodeType:[[attributes objectForKey:@"T"] cStringUsingEncoding:NSUTF8StringEncoding]], [NSString stringWithCString:property_getName(property) encoding:NSUTF8StringEncoding]];
    
    return [proStr copy];
}


+ (NSArray *)methodsForClass:(Class)class typeFormat:(NSString *)type {
    unsigned int outCount;
    Method *methods = class_copyMethodList(class, &outCount);
    NSMutableArray *result = [NSMutableArray new];
    
    for (unsigned int i = 0; i < outCount; i++) {
        NSString *methodDescription = [NSString stringWithFormat:@"%@ (%@)%@", type, [NSString decodeType:method_copyReturnType(methods[i])], NSStringFromSelector(method_getName(methods[i]))];
        NSInteger args = method_getNumberOfArguments(methods[i]);
        NSMutableArray *selParts = [[methodDescription componentsSeparatedByString:@":"] mutableCopy];
        NSInteger offset = 2;
        
        for (NSUInteger idx = offset; idx < args; idx++) {
            NSString *returnType = [NSString decodeType:method_copyArgumentType(methods[i], (unsigned int)idx)];
            selParts[idx - offset] = [NSString stringWithFormat:@"%@:(%@)arg%lu",
                                      selParts[idx - offset],
                                      returnType,
                                      idx - 2];
        }
        [result addObject:[selParts componentsJoinedByString:@" "]];
    }
    free(methods);
    return result.count ? [result copy] : nil;
}
@end
