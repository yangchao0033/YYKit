//
//  NSObject+YYModel.m
//  YYKit <https://github.com/ibireme/YYKit>
//
//  Created by ibireme on 15/5/10.
//  Copyright (c) 2015 ibireme.
//
//  This source code is licensed under the MIT-style license found in the
//  LICENSE file in the root directory of this source tree.
//

#import "NSObject+YYModel.h"
#import "YYClassInfo.h"
#import <libkern/OSAtomic.h>
#import <objc/message.h>

#define force_inline __inline__ __attribute__((always_inline))

/// Foundation Class Type
typedef NS_ENUM (NSUInteger, YYEncodingNSType) {
    YYEncodingTypeNSUnknown = 0,
    YYEncodingTypeNSString,
    YYEncodingTypeNSMutableString,
    YYEncodingTypeNSValue,
    YYEncodingTypeNSNumber,
    YYEncodingTypeNSDecimalNumber,
    YYEncodingTypeNSData,
    YYEncodingTypeNSMutableData,
    YYEncodingTypeNSDate,
    YYEncodingTypeNSURL,
    YYEncodingTypeNSArray,
    YYEncodingTypeNSMutableArray,
    YYEncodingTypeNSDictionary,
    YYEncodingTypeNSMutableDictionary,
    YYEncodingTypeNSSet,
    YYEncodingTypeNSMutableSet,
};

/// Get the Foundation class type from property info.
static force_inline YYEncodingNSType YYClassGetNSType(Class cls) {
    if (!cls) return YYEncodingTypeNSUnknown;
    if ([cls isSubclassOfClass:[NSMutableString class]]) return YYEncodingTypeNSMutableString;
    if ([cls isSubclassOfClass:[NSString class]]) return YYEncodingTypeNSString;
    if ([cls isSubclassOfClass:[NSDecimalNumber class]]) return YYEncodingTypeNSDecimalNumber;
    if ([cls isSubclassOfClass:[NSNumber class]]) return YYEncodingTypeNSNumber;
    if ([cls isSubclassOfClass:[NSValue class]]) return YYEncodingTypeNSValue;
    if ([cls isSubclassOfClass:[NSMutableData class]]) return YYEncodingTypeNSMutableData;
    if ([cls isSubclassOfClass:[NSData class]]) return YYEncodingTypeNSData;
    if ([cls isSubclassOfClass:[NSDate class]]) return YYEncodingTypeNSDate;
    if ([cls isSubclassOfClass:[NSURL class]]) return YYEncodingTypeNSURL;
    if ([cls isSubclassOfClass:[NSMutableArray class]]) return YYEncodingTypeNSMutableArray;
    if ([cls isSubclassOfClass:[NSArray class]]) return YYEncodingTypeNSArray;
    if ([cls isSubclassOfClass:[NSMutableDictionary class]]) return YYEncodingTypeNSMutableDictionary;
    if ([cls isSubclassOfClass:[NSDictionary class]]) return YYEncodingTypeNSDictionary;
    if ([cls isSubclassOfClass:[NSMutableSet class]]) return YYEncodingTypeNSMutableSet;
    if ([cls isSubclassOfClass:[NSSet class]]) return YYEncodingTypeNSSet;
    return YYEncodingTypeNSUnknown;
}

/// Whether the type is c number.
static force_inline BOOL YYEncodingTypeIsCNumber(YYEncodingType type) {
    switch (type & YYEncodingTypeMask) {
        case YYEncodingTypeBool:
        case YYEncodingTypeInt8:
        case YYEncodingTypeUInt8:
        case YYEncodingTypeInt16:
        case YYEncodingTypeUInt16:
        case YYEncodingTypeInt32:
        case YYEncodingTypeUInt32:
        case YYEncodingTypeInt64:
        case YYEncodingTypeUInt64:
        case YYEncodingTypeFloat:
        case YYEncodingTypeDouble:
        case YYEncodingTypeLongDouble: return YES;
        default: return NO;
    }
}

/// Parse a number value from 'id'.
/** 解析一个来自id类型的数字，对其进行必要的重构，吧各种各样的值处理为数字 */
static force_inline NSNumber *YYNSNumberCreateFromID(__unsafe_unretained id value) {
    static NSCharacterSet *dot;
    static NSDictionary *dic;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        dot = [NSCharacterSet characterSetWithRange:NSMakeRange('.', 1)];
        dic = @{@"TRUE" :   @(YES),
                @"True" :   @(YES),
                @"true" :   @(YES),
                @"FALSE" :  @(NO),
                @"False" :  @(NO),
                @"false" :  @(NO),
                @"YES" :    @(YES),
                @"Yes" :    @(YES),
                @"yes" :    @(YES),
                @"NO" :     @(NO),
                @"No" :     @(NO),
                @"no" :     @(NO),
                @"NIL" :    (id)kCFNull,
                @"Nil" :    (id)kCFNull,
                @"nil" :    (id)kCFNull,
                @"NULL" :   (id)kCFNull,
                @"Null" :   (id)kCFNull,
                @"null" :   (id)kCFNull,
                @"(NULL)" : (id)kCFNull,
                @"(Null)" : (id)kCFNull,
                @"(null)" : (id)kCFNull,
                @"<NULL>" : (id)kCFNull,
                @"<Null>" : (id)kCFNull,
                @"<null>" : (id)kCFNull};
    });
    
    if (!value || value == (id)kCFNull) return nil;
    if ([value isKindOfClass:[NSNumber class]]) return value;
    if ([value isKindOfClass:[NSString class]]) {
        /** 用字典key处理num对象 */
        NSNumber *num = dic[value];
        if (num) {
            if (num == (id)kCFNull) return nil;
            return num;
        }
        /** 如果值中存在点“.” */
        if ([(NSString *)value rangeOfCharacterFromSet:dot].location != NSNotFound) {
            /** 转c字符串 */
            const char *cstring = ((NSString *)value).UTF8String;
            if (!cstring) return nil;
            /** 
             1. 函数名： atof
             功 能： 把字符串转换成浮点数
             名字来源：ascii to floating point numbers 的缩写
             用 法： double atof(const char *nptr); 
             */
            double num = atof(cstring);
            /** 
             返回一个 Boolean 值，指明提供的值是否是保留值 NaN （不是数字）。
             NaN 即 Not a Number
             isNaN(numValue)
             必选项 numvalue 参数为要检查是否为 NAN 的值。
             说明
             假如值是 NaN， 那么 isNaN 函数返回 true ，否则返回 false。 使用这个函数的典型情况是检查 parseInt 和 parseFloat 方法的输入值。
             还有一种办法，变量可以与它自身进行比较。 假如比较的结果不等，那么它就是 NaN 。 这是因为 NaN 是唯一与自身不等的值。
             函数名称： isinf
             函数功能： 判断数组的元素是否是无界的（比如， 无穷大、无穷小）。
             语法格式：
             TF = isinf(A)
             返回一个和A尺寸一样的数组， 如果A中某个元素是inf， 则对应TF中元素是1， 否则TF中对应元素是0。

             */
            if (isnan(num) || isinf(num)) return nil;
            return @(num);
        } else { /** 如果不存在“.” */
            const char *cstring = ((NSString *)value).UTF8String;
            if (!cstring) return nil;
            /** 
             函数名: atoll
             功 能: 把字符串转换成长长整型数（64位）
             用 法: long long atoll(const char *nptr);
             注:unix下可用，与atol、atoi等类似
             */
            return @(atoll(cstring));
        }
    }
    return nil;
}

/// Parse string to date.
static NSDate *YYNSDateFromString(__unsafe_unretained NSString *string) {
    typedef NSDate* (^YYNSDateParseBlock)(NSString *string);
    #define kParserNum 32
    static YYNSDateParseBlock blocks[kParserNum + 1] = {0};
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        {
            /*
             2014-01-20  // Google
             */
            NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
            formatter.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
            formatter.timeZone = [NSTimeZone timeZoneForSecondsFromGMT:0];
            formatter.dateFormat = @"yyyy-MM-dd";
            blocks[10] = ^(NSString *string) { return [formatter dateFromString:string]; };
        }
        
        {
            /*
             2014-01-20 12:24:48
             2014-01-20T12:24:48   // Google
             */
            NSDateFormatter *formatter1 = [[NSDateFormatter alloc] init];
            formatter1.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
            formatter1.timeZone = [NSTimeZone timeZoneForSecondsFromGMT:0];
            formatter1.dateFormat = @"yyyy-MM-dd'T'HH:mm:ss";
            
            NSDateFormatter *formatter2 = [[NSDateFormatter alloc] init];
            formatter2.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
            formatter2.timeZone = [NSTimeZone timeZoneForSecondsFromGMT:0];
            formatter2.dateFormat = @"yyyy-MM-dd HH:mm:ss";
            
            blocks[19] = ^(NSString *string) {
                if ([string characterAtIndex:10] == 'T') {
                    return [formatter1 dateFromString:string];
                } else {
                    return [formatter2 dateFromString:string];
                }
            };
        }
        
        {
            /*
             2014-01-20T12:24:48Z        // Github, Apple
             2014-01-20T12:24:48+0800    // Facebook
             2014-01-20T12:24:48+12:00   // Google
             */
            NSDateFormatter *formatter = [NSDateFormatter new];
            formatter.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
            formatter.dateFormat = @"yyyy-MM-dd'T'HH:mm:ssZ";
            blocks[20] = ^(NSString *string) { return [formatter dateFromString:string]; };
            blocks[24] = ^(NSString *string) { return [formatter dateFromString:string]; };
            blocks[25] = ^(NSString *string) { return [formatter dateFromString:string]; };
        }
        
        {
            /*
             Fri Sep 04 00:12:21 +0800 2015 // Weibo, Twitter
             */
            NSDateFormatter *formatter = [NSDateFormatter new];
            formatter.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
            formatter.dateFormat = @"EEE MMM dd HH:mm:ss Z yyyy";
            blocks[30] = ^(NSString *string) { return [formatter dateFromString:string]; };
        }
    });
    if (!string) return nil;
    if (string.length > kParserNum) return nil;
    YYNSDateParseBlock parser = blocks[string.length];
    if (!parser) return nil;
    return parser(string);
    #undef kParserNum
}


/// Get the 'NSBlock' class.
static force_inline Class YYNSBlockClass() {
    static Class cls;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        void (^block)(void) = ^{};
        cls = ((NSObject *)block).class;
        while (class_getSuperclass(cls) != [NSObject class]) {
            cls = class_getSuperclass(cls);
        }
    });
    return cls; // current is "NSBlock"
}



/**
 Get the ISO date formatter.
 
 ISO8601 format example:
 2010-07-09T16:13:30+12:00
 2011-01-11T11:11:11+0000
 2011-01-26T19:06:43Z
 
 length: 20/24/25
 */
static force_inline NSDateFormatter *YYISODateFormatter() {
    static NSDateFormatter *formatter = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        formatter = [[NSDateFormatter alloc] init];
        formatter.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
        formatter.dateFormat = @"yyyy-MM-dd'T'HH:mm:ssZ";
    });
    return formatter;
}

/// Get the value with key paths from dictionary
/// The dic should be NSDictionary, and the keyPath should not be nil.
static force_inline id YYValueForKeyPath(__unsafe_unretained NSDictionary *dic, __unsafe_unretained NSArray *keyPaths) {
    id value = nil;
    for (NSUInteger i = 0, max = keyPaths.count; i < max; i++) {
        value = dic[keyPaths[i]];
        if (i + 1 < max) {
            if ([value isKindOfClass:[NSDictionary class]]) {
                dic = value;
            } else {
                return nil;
            }
        }
    }
    return value;
}

/// Get the value with multi key (or key path) from dictionary
/// The dic should be NSDictionary
static force_inline id YYValueForMultiKeys(__unsafe_unretained NSDictionary *dic, __unsafe_unretained NSArray *multiKeys) {
    id value = nil;
    for (NSString *key in multiKeys) {
        if ([key isKindOfClass:[NSString class]]) {
            value = dic[key];
            if (value) break;
        } else {
            value = YYValueForKeyPath(dic, (NSArray *)key);
            if (value) break;
        }
    }
    return value;
}




/// A property info in object model.
/** 对象模型中属性的信息的内部类 */
@interface _YYModelPropertyMeta : NSObject {
    @package
    //    属性名
    NSString *_name;             ///< property's name
    //    属性C语言类型
    YYEncodingType _type;        ///< property's type
    //    属性OC中Foundation框架中的类型（NS...）
    YYEncodingNSType _nsType;    ///< property's Foundation type
    //    是否是C语言数字
    BOOL _isCNumber;             ///< is c number type
    //    属性类对象
    Class _cls;                  ///< property's class, or nil
    //    容器泛型类，如果么有容器泛型类为nil
    Class _genericCls;           ///< container's generic class, or nil if threr's no generic class
    /** getter方法 */
    SEL _getter;                 ///< getter, or nil if the instances cannot respond
    /** setter方法 */
    SEL _setter;                 ///< setter, or nil if the instances cannot respond
    /** 是否能通过KVC访问 */
    BOOL _isKVCCompatible;       ///< YES if it can access with key-value coding
    /** 结构是否支持归档 */
    BOOL _isStructAvailableForKeyedArchiver; ///< YES if the struct can encoded with keyed archiver/unarchiver
    /** 判断类或通用类中实现了+modelCustomClassForDictionary:方法的 */
    BOOL _hasCustomClassFromDictionary; ///< class/generic class implements +modelCustomClassForDictionary:
    
    /*
     property->key:       _mappedToKey:key     _mappedToKeyPath:nil            _mappedToKeyArray:nil
     property->keyPath:   _mappedToKey:keyPath _mappedToKeyPath:keyPath(array) _mappedToKeyArray:nil
     property->keys:      _mappedToKey:keys[0] _mappedToKeyPath:nil/keyPath    _mappedToKeyArray:keys(array)
     */
    /** 属性中映射的键 */
    NSString *_mappedToKey;      ///< the key mapped to
    /** 属性中映射的键路径 */
    NSArray *_mappedToKeyPath;   ///< the key path mapped to (nil if the name is not key path)
    /** 属性中映射的数组 */
    NSArray *_mappedToKeyArray;  ///< the key(NSString) or keyPath(NSArray) array (nil if not mapped to multiple keys)
    /** 属性类的信息 */
    YYClassPropertyInfo *_info;  ///< property's info
    /** 下一个元 如果存在多个属性映射为同一个键l */
    _YYModelPropertyMeta *_next; ///< next meta if there are multiple properties mapped to the same key.
}
@end

@implementation _YYModelPropertyMeta
+ (instancetype)metaWithClassInfo:(YYClassInfo *)classInfo propertyInfo:(YYClassPropertyInfo *)propertyInfo generic:(Class)generic {
    _YYModelPropertyMeta *meta = [self new];
    meta->_name = propertyInfo.name;
    meta->_type = propertyInfo.type;
    meta->_info = propertyInfo;
    meta->_genericCls = generic;
    
    if ((meta->_type & YYEncodingTypeMask) == YYEncodingTypeObject) {
        meta->_nsType = YYClassGetNSType(propertyInfo.cls);
    } else {
        meta->_isCNumber = YYEncodingTypeIsCNumber(meta->_type);
    }
    if ((meta->_type & YYEncodingTypeMask) == YYEncodingTypeStruct) {
        /*
         It seems that NSKeyedUnarchiver cannot decode NSValue except these structs:
         */
        static NSSet *types = nil;
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            NSMutableSet *set = [NSMutableSet new];
            // 32 bit
            [set addObject:@"{CGSize=ff}"];
            [set addObject:@"{CGPoint=ff}"];
            [set addObject:@"{CGRect={CGPoint=ff}{CGSize=ff}}"];
            [set addObject:@"{CGAffineTransform=ffffff}"];
            [set addObject:@"{UIEdgeInsets=ffff}"];
            [set addObject:@"{UIOffset=ff}"];
            // 64 bit
            [set addObject:@"{CGSize=dd}"];
            [set addObject:@"{CGPoint=dd}"];
            [set addObject:@"{CGRect={CGPoint=dd}{CGSize=dd}}"];
            [set addObject:@"{CGAffineTransform=dddddd}"];
            [set addObject:@"{UIEdgeInsets=dddd}"];
            [set addObject:@"{UIOffset=dd}"];
            types = set;
        });
        if ([types containsObject:propertyInfo.typeEncoding]) {
            meta->_isStructAvailableForKeyedArchiver = YES;
        }
    }
    meta->_cls = propertyInfo.cls;
    
    if (generic) {
        meta->_hasCustomClassFromDictionary = [generic respondsToSelector:@selector(modelCustomClassForDictionary:)];
    } else if (meta->_cls && meta->_nsType == YYEncodingTypeNSUnknown) {
        meta->_hasCustomClassFromDictionary = [meta->_cls respondsToSelector:@selector(modelCustomClassForDictionary:)];
    }
    
    if (propertyInfo.getter) {
        SEL sel = NSSelectorFromString(propertyInfo.getter);
        if ([classInfo.cls instancesRespondToSelector:sel]) {
            meta->_getter = sel;
        }
    }
    if (propertyInfo.setter) {
        SEL sel = NSSelectorFromString(propertyInfo.setter);
        if ([classInfo.cls instancesRespondToSelector:sel]) {
            meta->_setter = sel;
        }
    }
    
    if (meta->_getter && meta->_setter) {
        /*
         KVC invalid type:
         long double
         pointer (such as SEL/CoreFoundation object)
         */
        switch (meta->_type & YYEncodingTypeMask) {
            case YYEncodingTypeBool:
            case YYEncodingTypeInt8:
            case YYEncodingTypeUInt8:
            case YYEncodingTypeInt16:
            case YYEncodingTypeUInt16:
            case YYEncodingTypeInt32:
            case YYEncodingTypeUInt32:
            case YYEncodingTypeInt64:
            case YYEncodingTypeUInt64:
            case YYEncodingTypeFloat:
            case YYEncodingTypeDouble:
            case YYEncodingTypeObject:
            case YYEncodingTypeClass:
            case YYEncodingTypeBlock:
            case YYEncodingTypeStruct:
            case YYEncodingTypeUnion: {
                meta->_isKVCCompatible = YES;
            } break;
            default: break;
        }
    }
    
    return meta;
}
@end


/// A class info in object model.
@interface _YYModelMeta : NSObject {
    @package
    /// Key:mapped key and key path, Value:_YYModelPropertyInfo.
    NSDictionary *_mapper;
    /// Array<_YYModelPropertyInfo>, all property meta of this model.
    NSArray *_allPropertyMetas;
    /// Array<_YYModelPropertyInfo>, property meta which is mapped to a key path.
    NSArray *_keyPathPropertyMetas;
    /// Array<_YYModelPropertyInfo>, property meta which is mapped to multi keys.
    NSArray *_multiKeysPropertyMetas;
    /// The number of mapped key (and key path), same to _mapper.count.
    NSUInteger _keyMappedCount;
    /// Model class type.
    YYEncodingNSType _nsType;
    
    BOOL _hasCustomTransformFromDictionary;
    BOOL _hasCustomTransformToDictionary;
    BOOL _hasCustomClassFromDictionary;
}
@end

@implementation _YYModelMeta
/** 获取元类模型对象 */
- (instancetype)initWithClass:(Class)cls {
    /** 查询类信息到模型中 */
    YYClassInfo *classInfo = [YYClassInfo classInfoWithClass:cls];
    if (!classInfo) return nil;
    self = [super init];
    
    // Get black list
    NSSet *blacklist = nil;
    if ([cls respondsToSelector:@selector(modelPropertyBlacklist)]) {
        NSArray *properties = [(id<YYModel>)cls modelPropertyBlacklist];
        if (properties) {
            blacklist = [NSSet setWithArray:properties];
        }
    }
    
    // Get white list
    NSSet *whitelist = nil;
    if ([cls respondsToSelector:@selector(modelPropertyWhitelist)]) {
        NSArray *properties = [(id<YYModel>)cls modelPropertyWhitelist];
        if (properties) {
            whitelist = [NSSet setWithArray:properties];
        }
    }
    
    // Get container property's generic class
    NSDictionary *genericMapper = nil;
    if ([cls respondsToSelector:@selector(modelContainerPropertyGenericClass)]) {
        genericMapper = [(id<YYModel>)cls modelContainerPropertyGenericClass];
        if (genericMapper) {
            NSMutableDictionary *tmp = [NSMutableDictionary new];
            [genericMapper enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
                if (![key isKindOfClass:[NSString class]]) return;
                Class meta = object_getClass(obj);
                if (!meta) return;
                if (class_isMetaClass(meta)) {
                    tmp[key] = obj;
                } else if ([obj isKindOfClass:[NSString class]]) {
                    Class cls = NSClassFromString(obj);
                    if (cls) {
                        tmp[key] = cls;
                    }
                }
            }];
            genericMapper = tmp;
        }
    }
    
    // Create all property metas.
    NSMutableDictionary *allPropertyMetas = [NSMutableDictionary new];
    YYClassInfo *curClassInfo = classInfo;
    while (curClassInfo && curClassInfo.superCls != nil) { // recursive parse super class, but ignore root class (NSObject/NSProxy)
        for (YYClassPropertyInfo *propertyInfo in curClassInfo.propertyInfos.allValues) {
            if (!propertyInfo.name) continue;
            if (blacklist && [blacklist containsObject:propertyInfo.name]) continue;
            if (whitelist && ![whitelist containsObject:propertyInfo.name]) continue;
            _YYModelPropertyMeta *meta = [_YYModelPropertyMeta metaWithClassInfo:classInfo
                                                                    propertyInfo:propertyInfo
                                                                         generic:genericMapper[propertyInfo.name]];
            if (!meta || !meta->_name) continue;
            if (!meta->_getter && !meta->_setter) continue;
            if (allPropertyMetas[meta->_name]) continue;
            allPropertyMetas[meta->_name] = meta;
        }
        curClassInfo = curClassInfo.superClassInfo;
    }
    if (allPropertyMetas.count) _allPropertyMetas = allPropertyMetas.allValues.copy;
    
    // create mapper
    NSMutableDictionary *mapper = [NSMutableDictionary new];
    NSMutableArray *keyPathPropertyMetas = [NSMutableArray new];
    NSMutableArray *multiKeysPropertyMetas = [NSMutableArray new];
    
    if ([cls respondsToSelector:@selector(modelCustomPropertyMapper)]) {
        NSDictionary *customMapper = [(id <YYModel>)cls modelCustomPropertyMapper];
        [customMapper enumerateKeysAndObjectsUsingBlock:^(NSString *propertyName, NSString *mappedToKey, BOOL *stop) {
            _YYModelPropertyMeta *propertyMeta = allPropertyMetas[propertyName];
            if (!propertyMeta) return;
            [allPropertyMetas removeObjectForKey:propertyName];
            
            if ([mappedToKey isKindOfClass:[NSString class]]) {
                if (mappedToKey.length == 0) return;
                
                propertyMeta->_mappedToKey = mappedToKey;
                NSArray *keyPath = [mappedToKey componentsSeparatedByString:@"."];
                if (keyPath.count > 1) {
                    propertyMeta->_mappedToKeyPath = keyPath;
                    [keyPathPropertyMetas addObject:propertyMeta];
                }
                propertyMeta->_next = mapper[mappedToKey] ?: nil;
                mapper[mappedToKey] = propertyMeta;
                
            } else if ([mappedToKey isKindOfClass:[NSArray class]]) {
                
                NSMutableArray *mappedToKeyArray = [NSMutableArray new];
                for (NSString *oneKey in ((NSArray *)mappedToKey)) {
                    if (![oneKey isKindOfClass:[NSString class]]) continue;
                    if (oneKey.length == 0) continue;
                    
                    NSArray *keyPath = [oneKey componentsSeparatedByString:@"."];
                    if (keyPath.count > 1) {
                        [mappedToKeyArray addObject:keyPath];
                    } else {
                        [mappedToKeyArray addObject:oneKey];
                    }
                    
                    if (!propertyMeta->_mappedToKey) {
                        propertyMeta->_mappedToKey = oneKey;
                        propertyMeta->_mappedToKeyPath = keyPath.count > 1 ? keyPath : nil;
                    }
                }
                if (!propertyMeta->_mappedToKey) return;
                
                propertyMeta->_mappedToKeyArray = mappedToKeyArray;
                [multiKeysPropertyMetas addObject:propertyMeta];
                
                propertyMeta->_next = mapper[mappedToKey] ?: nil;
                mapper[mappedToKey] = propertyMeta;
            }
        }];
    }
    
    [allPropertyMetas enumerateKeysAndObjectsUsingBlock:^(NSString *name, _YYModelPropertyMeta *propertyMeta, BOOL *stop) {
        propertyMeta->_mappedToKey = name;
        propertyMeta->_next = mapper[name] ?: nil;
        mapper[name] = propertyMeta;
    }];
    
    if (mapper.count) _mapper = mapper;
    if (keyPathPropertyMetas) _keyPathPropertyMetas = keyPathPropertyMetas;
    if (multiKeysPropertyMetas) _multiKeysPropertyMetas = multiKeysPropertyMetas;
    
    _keyMappedCount = _allPropertyMetas.count;
    _nsType = YYClassGetNSType(cls);
    _hasCustomTransformFromDictionary = ([cls instancesRespondToSelector:@selector(modelCustomTransformFromDictionary:)]);
    _hasCustomTransformToDictionary = ([cls instancesRespondToSelector:@selector(modelCustomTransformToDictionary:)]);
    _hasCustomClassFromDictionary = ([cls respondsToSelector:@selector(modelCustomClassForDictionary:)]);
    
    return self;
}

/// Returns the cached model class meta
/** 返回当前类的metaClass */
+ (instancetype)metaWithClass:(Class)cls {
    if (!cls) return nil;
    /** core fundation的可变字典 */
    static CFMutableDictionaryRef cache;
    static dispatch_once_t onceToken;
    static OSSpinLock lock;
    dispatch_once(&onceToken, ^{
        cache = CFDictionaryCreateMutable(CFAllocatorGetDefault(), 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
        lock = OS_SPINLOCK_INIT;
    });
    /** 优化后的线程加锁 */
    OSSpinLockLock(&lock);
    _YYModelMeta *meta = CFDictionaryGetValue(cache, (__bridge const void *)(cls));
    OSSpinLockUnlock(&lock);
    if (!meta) {
        meta = [[_YYModelMeta alloc] initWithClass:cls];
        if (meta) {
            OSSpinLockLock(&lock);
            CFDictionarySetValue(cache, (__bridge const void *)(cls), (__bridge const void *)(meta));
            OSSpinLockUnlock(&lock);
        }
    }
    return meta;
}

@end


/**
 Get number from property.
 @discussion Caller should hold strong reference to the parameters before this function returns.
 @param model Should not be nil.
 @param meta  Should not be nil, meta.isCNumber should be YES, meta.getter should not be nil.
 @return A number object, or nil if failed.
 */
static force_inline NSNumber *ModelCreateNumberFromProperty(__unsafe_unretained id model,
                                                            __unsafe_unretained _YYModelPropertyMeta *meta) {
    switch (meta->_type & YYEncodingTypeMask) {
        case YYEncodingTypeBool: {
            return @(((bool (*)(id, SEL))(void *) objc_msgSend)((id)model, meta->_getter));
        }
        case YYEncodingTypeInt8: {
            return @(((int8_t (*)(id, SEL))(void *) objc_msgSend)((id)model, meta->_getter));
        }
        case YYEncodingTypeUInt8: {
            return @(((uint8_t (*)(id, SEL))(void *) objc_msgSend)((id)model, meta->_getter));
        }
        case YYEncodingTypeInt16: {
            return @(((int16_t (*)(id, SEL))(void *) objc_msgSend)((id)model, meta->_getter));
        }
        case YYEncodingTypeUInt16: {
            return @(((uint16_t (*)(id, SEL))(void *) objc_msgSend)((id)model, meta->_getter));
        }
        case YYEncodingTypeInt32: {
            return @(((int32_t (*)(id, SEL))(void *) objc_msgSend)((id)model, meta->_getter));
        }
        case YYEncodingTypeUInt32: {
            return @(((uint32_t (*)(id, SEL))(void *) objc_msgSend)((id)model, meta->_getter));
        }
        case YYEncodingTypeInt64: {
            return @(((int64_t (*)(id, SEL))(void *) objc_msgSend)((id)model, meta->_getter));
        }
        case YYEncodingTypeUInt64: {
            return @(((uint64_t (*)(id, SEL))(void *) objc_msgSend)((id)model, meta->_getter));
        }
        case YYEncodingTypeFloat: {
            float num = ((float (*)(id, SEL))(void *) objc_msgSend)((id)model, meta->_getter);
            if (isnan(num) || isinf(num)) return nil;
            return @(num);
        }
        case YYEncodingTypeDouble: {
            double num = ((double (*)(id, SEL))(void *) objc_msgSend)((id)model, meta->_getter);
            if (isnan(num) || isinf(num)) return nil;
            return @(num);
        }
        case YYEncodingTypeLongDouble: {
            double num = ((long double (*)(id, SEL))(void *) objc_msgSend)((id)model, meta->_getter);
            if (isnan(num) || isinf(num)) return nil;
            return @(num);
        }
        default: return nil;
    }
}

/**
 Set number to property.
 @discussion Caller should hold strong reference to the parameters before this function returns.
 @param model Should not be nil.
 @param num   Can be nil.
 @param meta  Should not be nil, meta.isCNumber should be YES, meta.setter should not be nil.
 */
static force_inline void ModelSetNumberToProperty(__unsafe_unretained id model,
                                                  __unsafe_unretained NSNumber *num,
                                                  __unsafe_unretained _YYModelPropertyMeta *meta) {
    switch (meta->_type & YYEncodingTypeMask) {
        case YYEncodingTypeBool: {
            ((void (*)(id, SEL, bool))(void *) objc_msgSend)((id)model, meta->_setter, num.boolValue);
        } break;
        case YYEncodingTypeInt8: {
            ((void (*)(id, SEL, int8_t))(void *) objc_msgSend)((id)model, meta->_setter, (int8_t)num.charValue);
        } break;
        case YYEncodingTypeUInt8: {
            ((void (*)(id, SEL, uint8_t))(void *) objc_msgSend)((id)model, meta->_setter, (uint8_t)num.unsignedCharValue);
        } break;
        case YYEncodingTypeInt16: {
            ((void (*)(id, SEL, int16_t))(void *) objc_msgSend)((id)model, meta->_setter, (int16_t)num.shortValue);
        } break;
        case YYEncodingTypeUInt16: {
            ((void (*)(id, SEL, uint16_t))(void *) objc_msgSend)((id)model, meta->_setter, (uint16_t)num.unsignedShortValue);
        } break;
        case YYEncodingTypeInt32: {
            ((void (*)(id, SEL, int32_t))(void *) objc_msgSend)((id)model, meta->_setter, (int32_t)num.intValue);
        }
        case YYEncodingTypeUInt32: {
            ((void (*)(id, SEL, uint32_t))(void *) objc_msgSend)((id)model, meta->_setter, (uint32_t)num.unsignedIntValue);
        } break;
        case YYEncodingTypeInt64: {
            if ([num isKindOfClass:[NSDecimalNumber class]]) {
                ((void (*)(id, SEL, int64_t))(void *) objc_msgSend)((id)model, meta->_setter, (int64_t)num.stringValue.longLongValue);
            } else {
                ((void (*)(id, SEL, uint64_t))(void *) objc_msgSend)((id)model, meta->_setter, (uint64_t)num.longLongValue);
            }
        } break;
        case YYEncodingTypeUInt64: {
            if ([num isKindOfClass:[NSDecimalNumber class]]) {
                ((void (*)(id, SEL, int64_t))(void *) objc_msgSend)((id)model, meta->_setter, (int64_t)num.stringValue.longLongValue);
            } else {
                ((void (*)(id, SEL, uint64_t))(void *) objc_msgSend)((id)model, meta->_setter, (uint64_t)num.unsignedLongLongValue);
            }
        } break;
        case YYEncodingTypeFloat: {
            float f = num.floatValue;
            if (isnan(f) || isinf(f)) f = 0;
            ((void (*)(id, SEL, float))(void *) objc_msgSend)((id)model, meta->_setter, f);
        } break;
        case YYEncodingTypeDouble: {
            double d = num.doubleValue;
            if (isnan(d) || isinf(d)) d = 0;
            ((void (*)(id, SEL, double))(void *) objc_msgSend)((id)model, meta->_setter, d);
        } break;
        case YYEncodingTypeLongDouble: {
            long double d = num.doubleValue;
            if (isnan(d) || isinf(d)) d = 0;
            ((void (*)(id, SEL, long double))(void *) objc_msgSend)((id)model, meta->_setter, (long double)d);
        } break;
        default: break;
    }
}

/**
 Set value to model with a property meta.
 用属性元设置value值给模型
 
 @discussion Caller should hold strong reference to the parameters before this function returns.
 
 @param model Should not be nil.
 @param value Should not be nil, but can be NSNull.
 @param meta  Should not be nil, and meta->_setter should not be nil.
 */
static void ModelSetValueForProperty(__unsafe_unretained id model,
                                     __unsafe_unretained id value,
                                     __unsafe_unretained _YYModelPropertyMeta *meta) {
#pragma mark property meta CNumber
    /** 如果属性元类型是c数字 */
    if (meta->_isCNumber) {
        /** 执行函数获取oc的NSNumber对象 */
        NSNumber *num = YYNSNumberCreateFromID(value);
        /** 设置Number对象到模型属性 */
        ModelSetNumberToProperty(model, num, meta);
        /** 保留num，延长其周期 */
        if (num) [num class]; // hold the number
    /** 如果属性元是foundation框架的基本类型 */
    } else if (meta->_nsType) {
        /** 如果为null，设置属性为nil */
#pragma mark property meta NULL
        if (value == (id)kCFNull) {
            ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model, meta->_setter, (id)nil);
        } else {
            switch (meta->_nsType) {
#pragma mark property meta String
                    /** 处理元类为字符串类型 */
                case YYEncodingTypeNSString:
                case YYEncodingTypeNSMutableString: {
                    /** 值为字符串类型 */
                    if ([value isKindOfClass:[NSString class]]) {
                        if (meta->_nsType == YYEncodingTypeNSString) {
                            /** 不可变直接发送消息赋值 */
                            ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model, meta->_setter, value);
                        } else {
                            /** 属性为可变类型则对其进行可变copy */
                            ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model, meta->_setter, ((NSString *)value).mutableCopy);
                        }
                        /** 处理元类型为字符串，值为num类型，对value进行相应地处理 */
                    } else if ([value isKindOfClass:[NSNumber class]]) {
                        /** 同上，可变给可变字符串不可变给不可变字符串，通过num对象的stringValue获取字符串 */
                        ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model,
                                                                       meta->_setter,
                                                                       (meta->_nsType == YYEncodingTypeNSString) ?
                                                                       ((NSNumber *)value).stringValue :
                                                                       ((NSNumber *)value).stringValue.mutableCopy);
                        /** 处理元类为字符串，值为二进制data */
                    } else if ([value isKindOfClass:[NSData class]]) {
                        /** 从data数据中解析出可变字符串 */
                        NSMutableString *string = [[NSMutableString alloc] initWithData:value encoding:NSUTF8StringEncoding];
                        ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model, meta->_setter, string);
                        /** 处理元类为字符串，值为url */
                    } else if ([value isKindOfClass:[NSURL class]]) {
                        /** 取出绝对string */
                        ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model,
                                                                       meta->_setter,
                                                                       (meta->_nsType == YYEncodingTypeNSString) ?
                                                                       ((NSURL *)value).absoluteString :
                                                                       ((NSURL *)value).absoluteString.mutableCopy);
                        /** 处理元类型为字符串，值为属性字符串 */
                    } else if ([value isKindOfClass:[NSAttributedString class]]) {
                        ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model,
                                                                       meta->_setter,
                                                                       (meta->_nsType == YYEncodingTypeNSString) ?
                                                                       ((NSAttributedString *)value).string :
                                                                       ((NSAttributedString *)value).string.mutableCopy);
                    }
                } break;
#pragma mark property meta Value
                /** 属性元类型为NSValue、NSNumber、NSDecimalNumber */
                case YYEncodingTypeNSValue:
                case YYEncodingTypeNSNumber:
                case YYEncodingTypeNSDecimalNumber: {
                    /** 属性类型为NSNumber */
                    if (meta->_nsType == YYEncodingTypeNSNumber) {
                        ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model, meta->_setter, YYNSNumberCreateFromID(value));
                        
                    } else if (meta->_nsType == YYEncodingTypeNSDecimalNumber) {
                        /** 属性类型和value类型一致为NSDecimalNumber */
                        if ([value isKindOfClass:[NSDecimalNumber class]]) {
                            ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model, meta->_setter, value);
                            /** value为Number */
                        } else if ([value isKindOfClass:[NSNumber class]]) {
                            /** 转为decimal对象之后直接调用set方法 */
                            NSDecimalNumber *decNum = [NSDecimalNumber decimalNumberWithDecimal:[((NSNumber *)value) decimalValue]];
                            ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model, meta->_setter, decNum);
                            /** value字符串 */
                        } else if ([value isKindOfClass:[NSString class]]) {
                            /** 获取decimal对象 */
                            NSDecimalNumber *decNum = [NSDecimalNumber decimalNumberWithString:value];
                            NSDecimal dec = decNum.decimalValue;
                            /** 值过滤，如果为is not number（NaN） */
                            if (dec._length == 0 && dec._isNegative) {// length == 0 && isNegative -> NaN
                                decNum = nil; // NaN
                            }
                            ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model, meta->_setter, decNum);
                        }
                        /** value是value */
                    } else { // YYEncodingTypeNSValue
                        if ([value isKindOfClass:[NSValue class]]) {
                            ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model, meta->_setter, value);
                        }
                    }
                } break;
                   /** 属性元为二进制data或可变data */
                case YYEncodingTypeNSData:
                case YYEncodingTypeNSMutableData: {
                    /** value为data或其子类 */
                    if ([value isKindOfClass:[NSData class]]) {
                        /** 并且属性元为data，直接set */
                        if (meta->_nsType == YYEncodingTypeNSData) {
                            ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model, meta->_setter, value);
                        } else {
                            /** 属性元为可变data需转换 */
                            NSMutableData *data = ((NSData *)value).mutableCopy;
                            ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model, meta->_setter, data);
                        }
                        /** 
                         *   value为可变String
                         */
                    } else if ([value isKindOfClass:[NSString class]]) {
                        /** 转为data */
                        NSData *data = [(NSString *)value dataUsingEncoding:NSUTF8StringEncoding];
                        /** 元类型可变则需要处理 */
                        if (meta->_nsType == YYEncodingTypeNSMutableData) {
                            data = ((NSData *)data).mutableCopy;
                        }
                        ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model, meta->_setter, data);
                    }
                } break;
                    /** 属性元类为日期类型 */
                case YYEncodingTypeNSDate: {
                    if ([value isKindOfClass:[NSDate class]]) {                                         // value为date
                        ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model, meta->_setter, value);
                    } else if ([value isKindOfClass:[NSString class]]) {                                // value为字符串
                        ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model, meta->_setter, YYNSDateFromString(value));
                    }
                } break;
                    /** 属性元为NSURL */
                case YYEncodingTypeNSURL: {
                    /** value为NSURL */
                    if ([value isKindOfClass:[NSURL class]]) {
                        ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model, meta->_setter, value);
                        /** value为字符串 */
                    } else if ([value isKindOfClass:[NSString class]]) {
                        /** 返回一个Unicode的字符集 */
                        NSCharacterSet *set = [NSCharacterSet whitespaceAndNewlineCharacterSet];
                        /** 通过字符集拿到字符串 */
                        NSString *str = [value stringByTrimmingCharactersInSet:set];
                        if (str.length == 0) {
                            ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model, meta->_setter, nil);
                        } else {
                            ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model, meta->_setter, [[NSURL alloc] initWithString:str]);
                        }
                    }
                } break;
                    
                case YYEncodingTypeNSArray:
                case YYEncodingTypeNSMutableArray: {
                    if (meta->_genericCls) {
                        NSArray *valueArr = nil;
                        if ([value isKindOfClass:[NSArray class]]) valueArr = value;
                        else if ([value isKindOfClass:[NSSet class]]) valueArr = ((NSSet *)value).allObjects;
                        if (valueArr) {
                            NSMutableArray *objectArr = [NSMutableArray new];
                            for (id one in valueArr) {
                                if ([one isKindOfClass:meta->_genericCls]) {
                                    [objectArr addObject:one];
                                } else if ([one isKindOfClass:[NSDictionary class]]) {
                                    Class cls = meta->_genericCls;
                                    if (meta->_hasCustomClassFromDictionary) {
                                        cls = [cls modelCustomClassForDictionary:one];
                                        if (!cls) cls = meta->_genericCls; // for xcode code coverage
                                    }
                                    NSObject *newOne = [cls new];
                                    [newOne modelSetWithDictionary:one];
                                    if (newOne) [objectArr addObject:newOne];
                                }
                            }
                            ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model, meta->_setter, objectArr);
                        }
                    } else {
                        if ([value isKindOfClass:[NSArray class]]) {
                            if (meta->_nsType == YYEncodingTypeNSArray) {
                                ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model, meta->_setter, value);
                            } else {
                                ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model,
                                                                               meta->_setter,
                                                                               ((NSArray *)value).mutableCopy);
                            }
                        } else if ([value isKindOfClass:[NSSet class]]) {
                            if (meta->_nsType == YYEncodingTypeNSArray) {
                                ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model, meta->_setter, ((NSSet *)value).allObjects);
                            } else {
                                ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model,
                                                                               meta->_setter,
                                                                               ((NSSet *)value).allObjects.mutableCopy);
                            }
                        }
                    }
                } break;
                    
                case YYEncodingTypeNSDictionary:
                case YYEncodingTypeNSMutableDictionary: {
                    if ([value isKindOfClass:[NSDictionary class]]) {
                        if (meta->_genericCls) {
                            NSMutableDictionary *dic = [NSMutableDictionary new];
                            [((NSDictionary *)value) enumerateKeysAndObjectsUsingBlock:^(NSString *oneKey, id oneValue, BOOL *stop) {
                                if ([oneValue isKindOfClass:[NSDictionary class]]) {
                                    Class cls = meta->_genericCls;
                                    if (meta->_hasCustomClassFromDictionary) {
                                        cls = [cls modelCustomClassForDictionary:oneValue];
                                        if (!cls) cls = meta->_genericCls; // for xcode code coverage
                                    }
                                    NSObject *newOne = [cls new];
                                    [newOne modelSetWithDictionary:(id)oneValue];
                                    if (newOne) dic[oneKey] = newOne;
                                }
                            }];
                            ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model, meta->_setter, dic);
                        } else {
                            if (meta->_nsType == YYEncodingTypeNSDictionary) {
                                ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model, meta->_setter, value);
                            } else {
                                ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model,
                                                                               meta->_setter,
                                                                               ((NSDictionary *)value).mutableCopy);
                            }
                        }
                    }
                } break;
                    
                case YYEncodingTypeNSSet:
                case YYEncodingTypeNSMutableSet: {
                    NSSet *valueSet = nil;
                    if ([value isKindOfClass:[NSArray class]]) valueSet = [NSMutableSet setWithArray:value];
                    else if ([value isKindOfClass:[NSSet class]]) valueSet = ((NSSet *)value);
                    
                    if (meta->_genericCls) {
                        NSMutableSet *set = [NSMutableSet new];
                        for (id one in valueSet) {
                            if ([one isKindOfClass:meta->_genericCls]) {
                                [set addObject:one];
                            } else if ([one isKindOfClass:[NSDictionary class]]) {
                                Class cls = meta->_genericCls;
                                if (meta->_hasCustomClassFromDictionary) {
                                    cls = [cls modelCustomClassForDictionary:one];
                                    if (!cls) cls = meta->_genericCls; // for xcode code coverage
                                }
                                NSObject *newOne = [cls new];
                                [newOne modelSetWithDictionary:one];
                                if (newOne) [set addObject:newOne];
                            }
                        }
                        ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model, meta->_setter, set);
                    } else {
                        if (meta->_nsType == YYEncodingTypeNSSet) {
                            ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model, meta->_setter, valueSet);
                        } else {
                            ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model,
                                                                           meta->_setter,
                                                                           ((NSSet *)valueSet).mutableCopy);
                        }
                    }
                } break;
                    
                default: break;
            }
        }
    } else {
        BOOL isNull = (value == (id)kCFNull);
        switch (meta->_type & YYEncodingTypeMask) {
            case YYEncodingTypeObject: {
                if (isNull) {
                    ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model, meta->_setter, (id)nil);
                } else if ([value isKindOfClass:meta->_cls]) {
                    ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model, meta->_setter, (id)value);
                } else if ([value isKindOfClass:[NSDictionary class]]) {
                    NSObject *one = nil;
                    if (meta->_getter) {
                        one = ((id (*)(id, SEL))(void *) objc_msgSend)((id)model, meta->_getter);
                    }
                    if (one) {
                        [one modelSetWithDictionary:value];
                    } else {
                        Class cls = meta->_cls;
                        if (meta->_hasCustomClassFromDictionary) {
                            cls = [cls modelCustomClassForDictionary:value];
                            if (!cls) cls = meta->_genericCls; // for xcode code coverage
                        }
                        one = [cls new];
                        [one modelSetWithDictionary:value];
                        ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model, meta->_setter, (id)one);
                    }
                }
            } break;
                
            case YYEncodingTypeClass: {
                if (isNull) {
                    ((void (*)(id, SEL, Class))(void *) objc_msgSend)((id)model, meta->_setter, (Class)NULL);
                } else {
                    Class cls = nil;
                    if ([value isKindOfClass:[NSString class]]) {
                        cls = NSClassFromString(value);
                        if (cls) {
                            ((void (*)(id, SEL, Class))(void *) objc_msgSend)((id)model, meta->_setter, (Class)cls);
                        }
                    } else {
                        cls = object_getClass(value);
                        if (cls) {
                            if (class_isMetaClass(cls)) {
                                ((void (*)(id, SEL, Class))(void *) objc_msgSend)((id)model, meta->_setter, (Class)value);
                            } else {
                                ((void (*)(id, SEL, Class))(void *) objc_msgSend)((id)model, meta->_setter, (Class)cls);
                            }
                        }
                    }
                }
            } break;
                
            case  YYEncodingTypeSEL: {
                if (isNull) {
                    ((void (*)(id, SEL, SEL))(void *) objc_msgSend)((id)model, meta->_setter, (SEL)NULL);
                } else if ([value isKindOfClass:[NSString class]]) {
                    SEL sel = NSSelectorFromString(value);
                    if (sel) ((void (*)(id, SEL, SEL))(void *) objc_msgSend)((id)model, meta->_setter, (SEL)sel);
                }
            } break;
                
            case YYEncodingTypeBlock: {
                if (isNull) {
                    ((void (*)(id, SEL, void (^)()))(void *) objc_msgSend)((id)model, meta->_setter, (void (^)())NULL);
                } else if ([value isKindOfClass:YYNSBlockClass()]) {
                    ((void (*)(id, SEL, void (^)()))(void *) objc_msgSend)((id)model, meta->_setter, (void (^)())value);
                }
            } break;
                
            case YYEncodingTypeStruct:
            case YYEncodingTypeUnion:
            case YYEncodingTypeCArray: {
                if ([value isKindOfClass:[NSValue class]]) {
                    const char *valueType = ((NSValue *)value).objCType;
                    const char *metaType = meta->_info.typeEncoding.UTF8String;
                    if (valueType && metaType && strcmp(valueType, metaType) == 0) {
                        [model setValue:value forKey:meta->_name];
                    }
                }
            } break;
                
            case YYEncodingTypePointer:
            case YYEncodingTypeCString: {
                if (isNull) {
                    ((void (*)(id, SEL, void *))(void *) objc_msgSend)((id)model, meta->_setter, (void *)NULL);
                } else if ([value isKindOfClass:[NSValue class]]) {
                    NSValue *nsValue = value;
                    if (nsValue.objCType && strcmp(nsValue.objCType, "^v") == 0) {
                        ((void (*)(id, SEL, void *))(void *) objc_msgSend)((id)model, meta->_setter, nsValue.pointerValue);
                    }
                }
            } break;
                
            default: break;
        }
    }
}


typedef struct {
    void *modelMeta;  ///< _YYModelMeta
    void *model;      ///< id (self)
    void *dictionary; ///< NSDictionary (json)
} ModelSetContext;

/**
 Apply function for dictionary, to set the key-value pair to model.
 应用于字典的函数，用来设置键值对到模型中去
 
 @param _key     should not be nil, NSString.
 @param _value   should not be nil.
 @param _context _context.modelMeta and _context.model should not be nil.
 */
static void ModelSetWithDictionaryFunction(const void *_key, const void *_value, void *_context) {
    ModelSetContext *context = _context;
    __unsafe_unretained _YYModelMeta *meta = (__bridge _YYModelMeta *)(context->modelMeta);
    __unsafe_unretained _YYModelPropertyMeta *propertyMeta = [meta->_mapper objectForKey:(__bridge id)(_key)];
    __unsafe_unretained id model = (__bridge id)(context->model);
    while (propertyMeta) {
        if (propertyMeta->_setter) {
            ModelSetValueForProperty(model, (__bridge __unsafe_unretained id)_value, propertyMeta);
        }
        propertyMeta = propertyMeta->_next;
    };
}

/**
 Apply function for model property meta, to set dictionary to model.
 
 
 @param _propertyMeta should not be nil, _YYModelPropertyMeta.
 @param _context      _context.model and _context.dictionary should not be nil.
 */
static void ModelSetWithPropertyMetaArrayFunction(const void *_propertyMeta, void *_context) {
    ModelSetContext *context = _context;
    __unsafe_unretained NSDictionary *dictionary = (__bridge NSDictionary *)(context->dictionary);
    __unsafe_unretained _YYModelPropertyMeta *propertyMeta = (__bridge _YYModelPropertyMeta *)(_propertyMeta);
    if (!propertyMeta->_setter) return;
    id value = nil;
    
    if (propertyMeta->_mappedToKeyArray) {
        value = YYValueForMultiKeys(dictionary, propertyMeta->_mappedToKeyArray);
    } else if (propertyMeta->_mappedToKeyPath) {
        value = YYValueForKeyPath(dictionary, propertyMeta->_mappedToKeyPath);
    } else {
        value = [dictionary objectForKey:propertyMeta->_mappedToKey];
    }
    
    if (value) {
        __unsafe_unretained id model = (__bridge id)(context->model);
        ModelSetValueForProperty(model, value, propertyMeta);
    }
}

/**
 Returns a valid JSON object (NSArray/NSDictionary/NSString/NSNumber/NSNull), 
 or nil if an error occurs.
 -> 返回一个合法的json对象(NSArray/NSDictionary/NSString/NSNumber/NSNull)
 
 @param model Model, can be nil.
 @return JSON object, nil if an error occurs.
 */
static id ModelToJSONObjectRecursive(NSObject *model) {
    /** 判断如果是空或为系统自带基本类型（即json的最基本的支持的数据类型）则返回原模型，不做转换 */
    if (!model || model == (id)kCFNull) return model;
    if ([model isKindOfClass:[NSString class]]) return model;
    if ([model isKindOfClass:[NSNumber class]]) return model;
    /** 字典类型模型处理 */
    if ([model isKindOfClass:[NSDictionary class]]) {
        /** 使用系统方法判断模型是否为合法的json模型，说明不用转换，返回即可 */
        if ([NSJSONSerialization isValidJSONObject:model]) return model;
        NSMutableDictionary *newDic = [NSMutableDictionary new];
        [((NSDictionary *)model) enumerateKeysAndObjectsUsingBlock:^(NSString *key, id obj, BOOL *stop) {
            NSString *stringKey = [key isKindOfClass:[NSString class]] ? key : key.description;
            if (!stringKey) return;
            /** 对遍历出的value进行迭代，产生合法的json对象 */
            id jsonObj = ModelToJSONObjectRecursive(obj);
            /** 返回空对象 */
            if (!jsonObj) jsonObj = (id)kCFNull;
            /** 对遍历出的key进行值的自定义分配 */
            newDic[stringKey] = jsonObj;
        }];
        /** 返回重构的json结构字典 */
        return newDic;
    }
    /** NSSet类型模型处理 */
    if ([model isKindOfClass:[NSSet class]]) {
        /** set -> array */
        NSArray *array = ((NSSet *)model).allObjects;
        /** 数组满足json对象，返回数组 */
        if ([NSJSONSerialization isValidJSONObject:array]) return array;
        /** 否则，构造自己的数组 */
        NSMutableArray *newArray = [NSMutableArray new];
        for (id obj in array) {
            /** json串中支持的数据类型直接添加，否则进行迭代判断拆解 */
            if ([obj isKindOfClass:[NSString class]] || [obj isKindOfClass:[NSNumber class]]) {
                [newArray addObject:obj];
            } else {
                id jsonObj = ModelToJSONObjectRecursive(obj);
                /** 迭代出的json对象不为空则添加进数组 */
                if (jsonObj && jsonObj != (id)kCFNull) [newArray addObject:jsonObj];
            }
        }
        return newArray;
    }
    /** 处理数组类型的模型 */
    if ([model isKindOfClass:[NSArray class]]) {
        /** 判断模型是否合法，合法则停止迭代转换 */
        if ([NSJSONSerialization isValidJSONObject:model]) return model;
        NSMutableArray *newArray = [NSMutableArray new];
        for (id obj in (NSArray *)model) {
            /** 遇到json基础类型直接加，否则继续迭代 */
            if ([obj isKindOfClass:[NSString class]] || [obj isKindOfClass:[NSNumber class]]) {
                [newArray addObject:obj];
            } else {
                id jsonObj = ModelToJSONObjectRecursive(obj);
                if (jsonObj && jsonObj != (id)kCFNull) [newArray addObject:jsonObj];
            }
        }
        return newArray;
    }
    /** 将所有其他基本数据类型转换为字符串 */
    if ([model isKindOfClass:[NSURL class]]) return ((NSURL *)model).absoluteString;
    if ([model isKindOfClass:[NSAttributedString class]]) return ((NSAttributedString *)model).string;
    /** 统一日期输出格式 */
    if ([model isKindOfClass:[NSDate class]]) return [YYISODateFormatter() stringFromDate:(id)model];
    /** 二进制格式不予转换 */
    if ([model isKindOfClass:[NSData class]]) return nil;
    
    /** 获取模型的元类，用来存储所有元类模型需要的一切信息 */
    _YYModelMeta *modelMeta = [_YYModelMeta metaWithClass:[model class]];
    if (!modelMeta || modelMeta->_keyMappedCount == 0) return nil;
    NSMutableDictionary *result = [[NSMutableDictionary alloc] initWithCapacity:64];
    __unsafe_unretained NSMutableDictionary *dic = result; // avoid retain and release in block
    /** 遍历元属性模型 */
    [modelMeta->_mapper enumerateKeysAndObjectsUsingBlock:^(NSString *propertyMappedKey, _YYModelPropertyMeta *propertyMeta, BOOL *stop) {
        if (!propertyMeta->_getter) return;
        
        id value = nil;
        if (propertyMeta->_isCNumber) {
            value = ModelCreateNumberFromProperty(model, propertyMeta);
        } else if (propertyMeta->_nsType) {
            id v = ((id (*)(id, SEL))(void *) objc_msgSend)((id)model, propertyMeta->_getter);
            value = ModelToJSONObjectRecursive(v);
        } else {
            switch (propertyMeta->_type & YYEncodingTypeMask) {
                case YYEncodingTypeObject: {
                    id v = ((id (*)(id, SEL))(void *) objc_msgSend)((id)model, propertyMeta->_getter);
                    value = ModelToJSONObjectRecursive(v);
                    if (value == (id)kCFNull) value = nil;
                } break;
                case YYEncodingTypeClass: {
                    Class v = ((Class (*)(id, SEL))(void *) objc_msgSend)((id)model, propertyMeta->_getter);
                    value = v ? NSStringFromClass(v) : nil;
                } break;
                case YYEncodingTypeSEL: {
                    SEL v = ((SEL (*)(id, SEL))(void *) objc_msgSend)((id)model, propertyMeta->_getter);
                    value = v ? NSStringFromSelector(v) : nil;
                } break;
                default: break;
            }
        }
        if (!value) return;
        
        if (propertyMeta->_mappedToKeyPath) {
            NSMutableDictionary *superDic = dic;
            NSMutableDictionary *subDic = nil;
            for (NSUInteger i = 0, max = propertyMeta->_mappedToKeyPath.count; i < max; i++) {
                NSString *key = propertyMeta->_mappedToKeyPath[i];
                if (i + 1 == max) { // end
                    if (!superDic[key]) superDic[key] = value;
                    break;
                }
                
                subDic = superDic[key];
                if (subDic) {
                    if ([subDic isKindOfClass:[NSDictionary class]]) {
                        if (![subDic isKindOfClass:[NSMutableDictionary class]]) {
                            subDic = subDic.mutableCopy;
                            superDic[key] = subDic;
                        }
                    } else {
                        break;
                    }
                } else {
                    subDic = [NSMutableDictionary new];
                    superDic[key] = subDic;
                }
                superDic = subDic;
                subDic = nil;
            }
        } else {
            if (!dic[propertyMeta->_mappedToKey]) {
                dic[propertyMeta->_mappedToKey] = value;
            }
        }
    }];
    
    if (modelMeta->_hasCustomTransformToDictionary) {
        BOOL suc = [((id<YYModel>)model) modelCustomTransformToDictionary:dic];
        if (!suc) return nil;
    }
    return result;
}



@implementation NSObject (YYModel)

+ (NSDictionary *)_yy_dictionaryWithJSON:(id)json {
    if (!json || json == (id)kCFNull) return nil;
    NSDictionary *dic = nil;
    NSData *jsonData = nil;
    if ([json isKindOfClass:[NSDictionary class]]) {
        dic = json;
    } else if ([json isKindOfClass:[NSString class]]) {
        /** 属于json字符串时，转换为二进制数据 */
        jsonData = [(NSString *)json dataUsingEncoding : NSUTF8StringEncoding];
    } else if ([json isKindOfClass:[NSData class]]) {
        jsonData = json;
    }
    /** 如果为二进制数据 */
    if (jsonData) {
        /** 使用系统自带方法对二进制数据进行字典反解 */
        dic = [NSJSONSerialization JSONObjectWithData:jsonData options:kNilOptions error:NULL];
        if (![dic isKindOfClass:[NSDictionary class]]) dic = nil;
    }
    return dic;
}

+ (instancetype)modelWithJSON:(id)json {
    /** 转字典后转模型 */
    NSDictionary *dic = [self _yy_dictionaryWithJSON:json];
    return [self modelWithDictionary:dic];
}

+ (instancetype)modelWithDictionary:(NSDictionary *)dictionary {
    if (!dictionary || dictionary == (id)kCFNull) return nil;
    if (![dictionary isKindOfClass:[NSDictionary class]]) return nil;
    
    Class cls = [self class];
    /** 获取元类 */
    _YYModelMeta *modelMeta = [_YYModelMeta metaWithClass:cls];
    /** 非属性不恩能够使用点语法 */
    /** 如果有来自字典的自定义类 */
    if (modelMeta->_hasCustomClassFromDictionary) {
        cls = [cls modelCustomClassForDictionary:dictionary] ?: cls;
    }
    
    NSObject *one = [cls new];
    if ([one modelSetWithDictionary:dictionary]) return one;
    return nil;
}

- (BOOL)modelSetWithJSON:(id)json {
    NSDictionary *dic = [NSObject _yy_dictionaryWithJSON:json];
    return [self modelSetWithDictionary:dic];
}

- (BOOL)modelSetWithDictionary:(NSDictionary *)dic {
    if (!dic || dic == (id)kCFNull) return NO;
    if (![dic isKindOfClass:[NSDictionary class]]) return NO;
    
    
    _YYModelMeta *modelMeta = [_YYModelMeta metaWithClass:object_getClass(self)];
    if (modelMeta->_keyMappedCount == 0) return NO;
    ModelSetContext context = {0};
    context.modelMeta = (__bridge void *)(modelMeta);
    context.model = (__bridge void *)(self);
    context.dictionary = (__bridge void *)(dic);
    /**  */
    if (modelMeta->_keyMappedCount >= CFDictionaryGetCount((CFDictionaryRef)dic)) {
        CFDictionaryApplyFunction((CFDictionaryRef)dic, ModelSetWithDictionaryFunction, &context);
        if (modelMeta->_keyPathPropertyMetas) {
            CFArrayApplyFunction((CFArrayRef)modelMeta->_keyPathPropertyMetas,
                                 CFRangeMake(0, CFArrayGetCount((CFArrayRef)modelMeta->_keyPathPropertyMetas)),
                                 ModelSetWithPropertyMetaArrayFunction,
                                 &context);
        }
        if (modelMeta->_multiKeysPropertyMetas) {
            CFArrayApplyFunction((CFArrayRef)modelMeta->_multiKeysPropertyMetas,
                                 CFRangeMake(0, CFArrayGetCount((CFArrayRef)modelMeta->_multiKeysPropertyMetas)),
                                 ModelSetWithPropertyMetaArrayFunction,
                                 &context);
        }
    } else {
        CFArrayApplyFunction((CFArrayRef)modelMeta->_allPropertyMetas,
                             CFRangeMake(0, modelMeta->_keyMappedCount),
                             ModelSetWithPropertyMetaArrayFunction,
                             &context);
    }
    
    if (modelMeta->_hasCustomTransformFromDictionary) {
        return [((id<YYModel>)self) modelCustomTransformFromDictionary:dic];
    }
    return YES;
}

- (id)modelToJSONObject {
    /*
     Apple said:
     The top level object is an NSArray or NSDictionary.
     All objects are instances of NSString, NSNumber, NSArray, NSDictionary, or NSNull.
     All dictionary keys are instances of NSString.
     Numbers are not NaN or infinity.
     -> 苹果说：
     最高层的对象是一个NSArray或者一个NSDictionary
     所有对象都是NSString, NSNumber, NSArray, NSDictionary, or NSNull的实例对象
     所有字典的键都是NSString类型
     */
    id jsonObject = ModelToJSONObjectRecursive(self);
    /** 如果转换后的json对象不是数组或者字典，则说明转换失败，返回nil */
    if ([jsonObject isKindOfClass:[NSArray class]]) return jsonObject;
    if ([jsonObject isKindOfClass:[NSDictionary class]]) return jsonObject;
    return nil;
}

- (NSData *)modelToJSONData {
    id jsonObject = [self modelToJSONObject];
    if (!jsonObject) return nil;
    return [NSJSONSerialization dataWithJSONObject:jsonObject options:0 error:NULL];
}

- (NSString *)modelToJSONString {
    NSData *jsonData = [self modelToJSONData];
    if (jsonData.length == 0) return nil;
    return [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
}

- (id)modelCopy{
    if (self == (id)kCFNull) return self;
    _YYModelMeta *modelMeta = [_YYModelMeta metaWithClass:self.class];
    if (modelMeta->_nsType) return [self copy];
    
    NSObject *one = [self.class new];
    for (_YYModelPropertyMeta *propertyMeta in modelMeta->_allPropertyMetas) {
        if (!propertyMeta->_getter || !propertyMeta->_setter) continue;
        
        if (propertyMeta->_isCNumber) {
            switch (propertyMeta->_type & YYEncodingTypeMask) {
                case YYEncodingTypeBool: {
                    bool num = ((bool (*)(id, SEL))(void *) objc_msgSend)((id)self, propertyMeta->_getter);
                    ((void (*)(id, SEL, bool))(void *) objc_msgSend)((id)one, propertyMeta->_setter, num);
                } break;
                case YYEncodingTypeInt8:
                case YYEncodingTypeUInt8: {
                    uint8_t num = ((bool (*)(id, SEL))(void *) objc_msgSend)((id)self, propertyMeta->_getter);
                    ((void (*)(id, SEL, uint8_t))(void *) objc_msgSend)((id)one, propertyMeta->_setter, num);
                } break;
                case YYEncodingTypeInt16:
                case YYEncodingTypeUInt16: {
                    uint16_t num = ((uint16_t (*)(id, SEL))(void *) objc_msgSend)((id)self, propertyMeta->_getter);
                    ((void (*)(id, SEL, uint16_t))(void *) objc_msgSend)((id)one, propertyMeta->_setter, num);
                } break;
                case YYEncodingTypeInt32:
                case YYEncodingTypeUInt32: {
                    uint32_t num = ((uint32_t (*)(id, SEL))(void *) objc_msgSend)((id)self, propertyMeta->_getter);
                    ((void (*)(id, SEL, uint32_t))(void *) objc_msgSend)((id)one, propertyMeta->_setter, num);
                } break;
                case YYEncodingTypeInt64:
                case YYEncodingTypeUInt64: {
                    uint64_t num = ((uint64_t (*)(id, SEL))(void *) objc_msgSend)((id)self, propertyMeta->_getter);
                    ((void (*)(id, SEL, uint64_t))(void *) objc_msgSend)((id)one, propertyMeta->_setter, num);
                } break;
                case YYEncodingTypeFloat: {
                    float num = ((float (*)(id, SEL))(void *) objc_msgSend)((id)self, propertyMeta->_getter);
                    ((void (*)(id, SEL, float))(void *) objc_msgSend)((id)one, propertyMeta->_setter, num);
                } break;
                case YYEncodingTypeDouble: {
                    double num = ((double (*)(id, SEL))(void *) objc_msgSend)((id)self, propertyMeta->_getter);
                    ((void (*)(id, SEL, double))(void *) objc_msgSend)((id)one, propertyMeta->_setter, num);
                } break;
                case YYEncodingTypeLongDouble: {
                    long double num = ((long double (*)(id, SEL))(void *) objc_msgSend)((id)self, propertyMeta->_getter);
                    ((void (*)(id, SEL, long double))(void *) objc_msgSend)((id)one, propertyMeta->_setter, num);
                } break;
                default: break;
            }
        } else {
            switch (propertyMeta->_type & YYEncodingTypeMask) {
                case YYEncodingTypeObject:
                case YYEncodingTypeClass:
                case YYEncodingTypeBlock: {
                    id value = ((id (*)(id, SEL))(void *) objc_msgSend)((id)self, propertyMeta->_getter);
                    ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)one, propertyMeta->_setter, value);
                } break;
                case YYEncodingTypeSEL:
                case YYEncodingTypePointer:
                case YYEncodingTypeCString: {
                    size_t value = ((size_t (*)(id, SEL))(void *) objc_msgSend)((id)self, propertyMeta->_getter);
                    ((void (*)(id, SEL, size_t))(void *) objc_msgSend)((id)one, propertyMeta->_setter, value);
                } break;
                case YYEncodingTypeStruct:
                case YYEncodingTypeUnion: {
                    @try {
                        NSValue *value = [self valueForKey:NSStringFromSelector(propertyMeta->_getter)];
                        if (value) {
                            [one setValue:value forKey:propertyMeta->_name];
                        }
                    }
                    @catch (NSException *exception) {
                        // do nothing...
                    }
                } break;
                default: break;
            }
        }
    }
    return one;
}

- (void)modelEncodeWithCoder:(NSCoder *)aCoder {
    if (!aCoder) return;
    if (self == (id)kCFNull) {
        [((id<NSCoding>)self)encodeWithCoder:aCoder];
        return;
    }
    
    _YYModelMeta *modelMeta = [_YYModelMeta metaWithClass:self.class];
    if (modelMeta->_nsType) {
        [((id<NSCoding>)self)encodeWithCoder:aCoder];
        return;
    }
    
    for (_YYModelPropertyMeta *propertyMeta in modelMeta->_allPropertyMetas) {
        if (!propertyMeta->_getter) return;
        
        if (propertyMeta->_isCNumber) {
            NSNumber *value = ModelCreateNumberFromProperty(self, propertyMeta);
            if (value) [aCoder encodeObject:value forKey:propertyMeta->_name];
        } else {
            switch (propertyMeta->_type & YYEncodingTypeMask) {
                case YYEncodingTypeObject: {
                    id value = ((id (*)(id, SEL))(void *)objc_msgSend)((id)self, propertyMeta->_getter);
                    if (value && (propertyMeta->_nsType || [value respondsToSelector:@selector(encodeWithCoder:)])) {
                        if ([value isKindOfClass:[NSValue class]]) {
                            if ([value isKindOfClass:[NSNumber class]]) {
                                [aCoder encodeObject:value forKey:propertyMeta->_name];
                            }
                        } else {
                            [aCoder encodeObject:value forKey:propertyMeta->_name];
                        }
                    }
                } break;
                case YYEncodingTypeSEL: {
                    SEL value = ((SEL (*)(id, SEL))(void *)objc_msgSend)((id)self, propertyMeta->_getter);
                    if (value) {
                        NSString *str = NSStringFromSelector(value);
                        [aCoder encodeObject:str forKey:propertyMeta->_name];
                    }
                } break;
                case YYEncodingTypeStruct:
                case YYEncodingTypeUnion: {
                    if (propertyMeta->_isKVCCompatible && propertyMeta->_isStructAvailableForKeyedArchiver) {
                        @try {
                            NSValue *value = [self valueForKey:NSStringFromSelector(propertyMeta->_getter)];
                            [aCoder encodeObject:value forKey:propertyMeta->_name];
                        }
                        @catch (NSException *exception) {
                            // do nothing...
                        }
                    }
                } break;
                    
                default:
                    break;
            }
        }
    }
}

- (id)modelInitWithCoder:(NSCoder *)aDecoder {
    if (!aDecoder) return self;
    if (self == (id)kCFNull) return self;    
    _YYModelMeta *modelMeta = [_YYModelMeta metaWithClass:self.class];
    if (modelMeta->_nsType) return self;
    
    for (_YYModelPropertyMeta *propertyMeta in modelMeta->_allPropertyMetas) {
        if (!propertyMeta->_setter) continue;
        
        if (propertyMeta->_isCNumber) {
            NSNumber *value = [aDecoder decodeObjectForKey:propertyMeta->_name];
            if ([value isKindOfClass:[NSNumber class]]) {
                ModelSetNumberToProperty(self, value, propertyMeta);
                [value class];
            }
        } else {
            YYEncodingType type = propertyMeta->_type & YYEncodingTypeMask;
            switch (type) {
                case YYEncodingTypeObject: {
                    id value = [aDecoder decodeObjectForKey:propertyMeta->_name];
                    ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)self, propertyMeta->_setter, value);
                } break;
                case YYEncodingTypeSEL: {
                    NSString *str = [aDecoder decodeObjectForKey:propertyMeta->_name];
                    if ([str isKindOfClass:[NSString class]]) {
                        SEL sel = NSSelectorFromString(str);
                        ((void (*)(id, SEL, SEL))(void *) objc_msgSend)((id)self, propertyMeta->_setter, sel);
                    }
                } break;
                case YYEncodingTypeStruct:
                case YYEncodingTypeUnion: {
                    if (propertyMeta->_isKVCCompatible) {
                        @try {
                            NSValue *value = [aDecoder decodeObjectForKey:propertyMeta->_name];
                            if (value) [self setValue:value forKey:propertyMeta->_name];
                        }
                        @catch (NSException *exception) {
                            // do nothing...
                        }
                    }
                } break;
                    
                default:
                    break;
            }
        }
    }
    return self;
}

- (NSUInteger)modelHash {
    if (self == (id)kCFNull) return [self hash];
    _YYModelMeta *modelMeta = [_YYModelMeta metaWithClass:self.class];
    if (modelMeta->_nsType) return [self hash];
    
    NSUInteger value = 0;
    NSUInteger count = 0;
    for (_YYModelPropertyMeta *propertyMeta in modelMeta->_allPropertyMetas) {
        if (!propertyMeta->_isKVCCompatible) continue;
        value ^= [[self valueForKey:NSStringFromSelector(propertyMeta->_getter)] hash];
        count++;
    }
    if (count == 0) value = (long)((__bridge void *)self);
    return value;
}

- (BOOL)modelIsEqual:(id)model {
    if (self == model) return YES;
    if (![model isMemberOfClass:self.class]) return NO;
    _YYModelMeta *modelMeta = [_YYModelMeta metaWithClass:self.class];
    if (modelMeta->_nsType) return [self isEqual:model];
    if ([self hash] != [model hash]) return NO;
    
    for (_YYModelPropertyMeta *propertyMeta in modelMeta->_allPropertyMetas) {
        if (!propertyMeta->_isKVCCompatible) continue;
        id this = [self valueForKey:NSStringFromSelector(propertyMeta->_getter)];
        id that = [model valueForKey:NSStringFromSelector(propertyMeta->_getter)];
        if (this == that) continue;
        if (this == nil || that == nil) return NO;
        if ([this isEqual:that]) continue;
    }
    return YES;
}

@end



@implementation NSArray (YYModel)

+ (NSArray *)modelArrayWithClass:(Class)cls json:(id)json {
    if (!json) return nil;
    NSArray *arr = nil;
    NSData *jsonData = nil;
    if ([json isKindOfClass:[NSArray class]]) {
        arr = json;
    } else if ([json isKindOfClass:[NSString class]]) {
        jsonData = [(NSString *)json dataUsingEncoding : NSUTF8StringEncoding];
    } else if ([json isKindOfClass:[NSData class]]) {
        jsonData = json;
    }
    if (jsonData) {
        arr = [NSJSONSerialization JSONObjectWithData:jsonData options:kNilOptions error:NULL];
        if (![arr isKindOfClass:[NSArray class]]) arr = nil;
    }
    return [self modelArrayWithClass:cls array:arr];
}

+ (NSArray *)modelArrayWithClass:(Class)cls array:(NSArray *)arr {
    if (!cls || !arr) return nil;
    NSMutableArray *result = [NSMutableArray new];
    for (NSDictionary *dic in arr) {
        if (![dic isKindOfClass:[NSDictionary class]]) continue;
        NSObject *obj = [cls modelWithDictionary:dic];
        if (obj) [result addObject:obj];
    }
    return result;
}

@end


@implementation NSDictionary (YYModel)

+ (NSDictionary *)modelDictionaryWithClass:(Class)cls json:(id)json {
    if (!json) return nil;
    NSDictionary *dic = nil;
    NSData *jsonData = nil;
    if ([json isKindOfClass:[NSDictionary class]]) {
        dic = json;
    } else if ([json isKindOfClass:[NSString class]]) {
        jsonData = [(NSString *)json dataUsingEncoding : NSUTF8StringEncoding];
    } else if ([json isKindOfClass:[NSData class]]) {
        jsonData = json;
    }
    if (jsonData) {
        dic = [NSJSONSerialization JSONObjectWithData:jsonData options:kNilOptions error:NULL];
        if (![dic isKindOfClass:[NSDictionary class]]) dic = nil;
    }
    return [self modelDictionaryWithClass:cls dictionary:dic];
}

+ (NSDictionary *)modelDictionaryWithClass:(Class)cls dictionary:(NSDictionary *)dic {
    if (!cls || !dic) return nil;
    NSMutableDictionary *result = [NSMutableDictionary new];
    for (NSString *key in dic.allKeys) {
        if (![key isKindOfClass:[NSString class]]) continue;
        NSObject *obj = [cls modelWithDictionary:dic[key]];
        if (obj) result[key] = obj;
    }
    return result;
}

@end
