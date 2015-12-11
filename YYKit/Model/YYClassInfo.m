//
//  YYClassInfo.m
//  YYKit <https://github.com/ibireme/YYKit>
//
//  Created by ibireme on 15/5/9.
//  Copyright (c) 2015 ibireme.
//
//  This source code is licensed under the MIT-style license found in the
//  LICENSE file in the root directory of this source tree.
//

#import "YYClassInfo.h"
#import <objc/runtime.h>
#import <libkern/OSAtomic.h>

YYEncodingType YYEncodingGetType(const char *typeEncoding) {
    char *type = (char *)typeEncoding;
    if (!type) return YYEncodingTypeUnknown;
    size_t len = strlen(type);
    if (len == 0) return YYEncodingTypeUnknown;
    
    YYEncodingType qualifier = 0;
    bool prefix = true;
    while (prefix) {
        switch (*type) {
            case 'r': {
                /** 按位或 */
                qualifier |= YYEncodingTypeQualifierConst;
                type++;
            } break;
            case 'n': {
                qualifier |= YYEncodingTypeQualifierIn;
                type++;
            } break;
            case 'N': {
                qualifier |= YYEncodingTypeQualifierInout;
                type++;
            } break;
            case 'o': {
                qualifier |= YYEncodingTypeQualifierOut;
                type++;
            } break;
            case 'O': {
                qualifier |= YYEncodingTypeQualifierBycopy;
                type++;
            } break;
            case 'R': {
                qualifier |= YYEncodingTypeQualifierByref;
                type++;
            } break;
            case 'V': {
                qualifier |= YYEncodingTypeQualifierOneway;
                type++;
            } break;
            default: { prefix = false; } break;
        }
    }

    len = strlen(type);
    if (len == 0) return YYEncodingTypeUnknown | qualifier;

    switch (*type) {
        case 'v': return YYEncodingTypeVoid | qualifier;
        case 'B': return YYEncodingTypeBool | qualifier;
        case 'c': return YYEncodingTypeInt8 | qualifier;
        case 'C': return YYEncodingTypeUInt8 | qualifier;
        case 's': return YYEncodingTypeInt16 | qualifier;
        case 'S': return YYEncodingTypeUInt16 | qualifier;
        case 'i': return YYEncodingTypeInt32 | qualifier;
        case 'I': return YYEncodingTypeUInt32 | qualifier;
        case 'l': return YYEncodingTypeInt32 | qualifier;
        case 'L': return YYEncodingTypeUInt32 | qualifier;
        case 'q': return YYEncodingTypeInt64 | qualifier;
        case 'Q': return YYEncodingTypeUInt64 | qualifier;
        case 'f': return YYEncodingTypeFloat | qualifier;
        case 'd': return YYEncodingTypeDouble | qualifier;
        case 'D': return YYEncodingTypeLongDouble | qualifier;
        case '#': return YYEncodingTypeClass | qualifier;
        case ':': return YYEncodingTypeSEL | qualifier;
        case '*': return YYEncodingTypeCString | qualifier;
        case '^': return YYEncodingTypePointer | qualifier;
        case '[': return YYEncodingTypeCArray | qualifier;
        case '(': return YYEncodingTypeUnion | qualifier;
        case '{': return YYEncodingTypeStruct | qualifier;
        case '@': {
            if (len == 2 && *(type + 1) == '?')
                return YYEncodingTypeBlock | qualifier;
            else
                return YYEncodingTypeObject | qualifier;
        }
        default: return YYEncodingTypeUnknown | qualifier;
    }
}

@implementation YYClassIvarInfo

- (instancetype)initWithIvar:(Ivar)ivar {
    if (!ivar) return nil;
    self = [super init];
    _ivar = ivar;
    /** 获取ivar名 */
    const char *name = ivar_getName(ivar);
    if (name) {
        _name = [NSString stringWithUTF8String:name];
    }
    /** 获取偏移量 */
    _offset = ivar_getOffset(ivar);
    const char *typeEncoding = ivar_getTypeEncoding(ivar);
    if (typeEncoding) {
        _typeEncoding = [NSString stringWithUTF8String:typeEncoding];
        _type = YYEncodingGetType(typeEncoding);
    }
    return self;
}

@end

@implementation YYClassMethodInfo

- (instancetype)initWithMethod:(Method)method {
    if (!method) return nil;
    self = [super init];
    _method = method;
    /** 获取sel指针 */
    _sel = method_getName(method);
    /** 获取方法实现 */
    _imp = method_getImplementation(method);
    const char *name = sel_getName(_sel);
    if (name) {
        /** 获取oc字符串方法名 */
        _name = [NSString stringWithUTF8String:name];
    }
    /** 获取方法的返回值和参数的类型 */
    const char *typeEncoding = method_getTypeEncoding(method);
    if (typeEncoding) {
        _typeEncoding = [NSString stringWithUTF8String:typeEncoding];
    }
    /** 获取返回值类型 */
    char *returnType = method_copyReturnType(method);
    if (returnType) {
        _returnTypeEncoding = [NSString stringWithUTF8String:returnType];
        /** 及时释放内存 */
        free(returnType);
    }
    /** 获取参数数量 */
    unsigned int argumentCount = method_getNumberOfArguments(method);
    if (argumentCount > 0) {
        NSMutableArray *argumentTypes = [NSMutableArray new];
        /** 遍历找出所有参数的类型 */
        for (unsigned int i = 0; i < argumentCount; i++) {
            char *argumentType = method_copyArgumentType(method, i);
            NSString *type = argumentType ? [NSString stringWithUTF8String:argumentType] : nil;
            [argumentTypes addObject:type ? type : @""];
            if (argumentType) free(argumentType);
        }
        _argumentTypeEncodings = argumentTypes;
    }
    return self;
}

@end

@implementation YYClassPropertyInfo

- (instancetype)initWithProperty:(objc_property_t)property {
    if (!property) return nil;
    self = [self init];
    _property = property;
    /** 返回属性名 */
    const char *name = property_getName(property);
    if (name) {
        _name = [NSString stringWithUTF8String:name];
    }
    
    YYEncodingType type = 0;
    unsigned int attrCount;
    objc_property_attribute_t *attrs = property_copyAttributeList(property, &attrCount);
    for (unsigned int i = 0; i < attrCount; i++) {
        /** 判断属性的富文本名挨个取出并对type赋值 */
        switch (attrs[i].name[0]) {
            case 'T': { // Type encoding 属性类型判断
                if (attrs[i].value) {
                    _typeEncoding = [NSString stringWithUTF8String:attrs[i].value];
                    type = YYEncodingGetType(attrs[i].value);
                    if (type & YYEncodingTypeObject) {
                        size_t len = strlen(attrs[i].value);
                        if (len > 3) {
                            char name[len - 2];
                            name[len - 3] = '\0';
                            memcpy(name, attrs[i].value + 2, len - 3);
                            /** 查找属性类别的类class */
                            _cls = objc_getClass(name);
                        }
                    }
                }
            } break;
            case 'V': { // Instance variable 实例变量
                if (attrs[i].value) {
                    _ivarName = [NSString stringWithUTF8String:attrs[i].value];
                }
            } break;
            case 'R': { /** 只读属性 */
                /** 按位或 */
                type |= YYEncodingTypePropertyReadonly;
            } break;
            case 'C': { /** copy属性 */
                type |= YYEncodingTypePropertyCopy;
            } break;
            case '&': { /** 保留属性 */
                type |= YYEncodingTypePropertyRetain;
            } break;
            case 'N': { /** 非原子性 */
                type |= YYEncodingTypePropertyNonatomic;
            } break;
            case 'D': { /** 动态属性（不生成get set方法） */
                type |= YYEncodingTypePropertyDynamic;
            } break;
            case 'W': { /** weak属性 */
                type |= YYEncodingTypePropertyWeak;
            } break;
            case 'G': { /** 自定义get属性 */
                type |= YYEncodingTypePropertyCustomGetter;
                if (attrs[i].value) {
                    _getter = [NSString stringWithUTF8String:attrs[i].value];
                }
            } break;
            case 'S': { /** 自定义set属性 */
                type |= YYEncodingTypePropertyCustomSetter;
                if (attrs[i].value) {
                    _setter = [NSString stringWithUTF8String:attrs[i].value];
                }
            } break;
            default: break;
        }
    }
    if (attrs) {
        free(attrs);
        attrs = NULL;
    }
    
    /** 记录最后按位或的类型 */
    _type = type;
    if (_name.length) {
        if (!_getter) {     // 记录get方法名
            _getter = _name;
        }
        if (!_setter) {     // 记录set方法名
            _setter = [NSString stringWithFormat:@"set%@%@:", [_name substringToIndex:1].uppercaseString, [_name substringFromIndex:1]];
        }
    }
    return self;
}

@end

@implementation YYClassInfo {
    BOOL _needUpdate;
}

- (instancetype)initWithClass:(Class)cls {
    if (!cls) return nil;
    self = [super init];
    /** 记录当前类，父类，判断是否为元类 */
    _cls = cls;
    _superCls = class_getSuperclass(cls);
    _isMeta = class_isMetaClass(cls);
    /** 为元类赋值 */
    if (!_isMeta) {
        _metaCls = objc_getMetaClass(class_getName(cls));
    }
    _name = NSStringFromClass(cls);
    [self _update];
    /** 递归产生超类类信息 */
    _superClassInfo = [self.class classInfoWithClass:_superCls];
    return self;
}
/** 更新 */
- (void)_update {
    _ivarInfos = nil;
    _methodInfos = nil;
    _propertyInfos = nil;
    
    Class cls = self.cls;
    unsigned int methodCount = 0;
    Method *methods = class_copyMethodList(cls, &methodCount);
    if (methods) {
        NSMutableDictionary *methodInfos = [NSMutableDictionary new];
        _methodInfos = methodInfos;
        for (unsigned int i = 0; i < methodCount; i++) {
            YYClassMethodInfo *info = [[YYClassMethodInfo alloc] initWithMethod:methods[i]];
            if (info.name) methodInfos[info.name] = info;
        }
        free(methods);
    }
    unsigned int propertyCount = 0;
    objc_property_t *properties = class_copyPropertyList(cls, &propertyCount);
    if (properties) {
        NSMutableDictionary *propertyInfos = [NSMutableDictionary new];
        _propertyInfos = propertyInfos;
        for (unsigned int i = 0; i < propertyCount; i++) {
            YYClassPropertyInfo *info = [[YYClassPropertyInfo alloc] initWithProperty:properties[i]];
            if (info.name) propertyInfos[info.name] = info;
        }
        free(properties);
    }
    
    unsigned int ivarCount = 0;
    Ivar *ivars = class_copyIvarList(cls, &ivarCount);
    if (ivars) {
        NSMutableDictionary *ivarInfos = [NSMutableDictionary new];
        _ivarInfos = ivarInfos;
        for (unsigned int i = 0; i < ivarCount; i++) {
            YYClassIvarInfo *info = [[YYClassIvarInfo alloc] initWithIvar:ivars[i]];
            if (info.name) ivarInfos[info.name] = info;
        }
        free(ivars);
    }
    _needUpdate = NO;
}

- (void)setNeedUpdate {
    _needUpdate = YES;
}

+ (instancetype)classInfoWithClass:(Class)cls {
    if (!cls) return nil;
    static CFMutableDictionaryRef classCache;
    static CFMutableDictionaryRef metaCache;
    static dispatch_once_t onceToken;
    static OSSpinLock lock;
    dispatch_once(&onceToken, ^{
        classCache = CFDictionaryCreateMutable(CFAllocatorGetDefault(), 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
        metaCache = CFDictionaryCreateMutable(CFAllocatorGetDefault(), 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
        lock = OS_SPINLOCK_INIT;
    });
    OSSpinLockLock(&lock);
    YYClassInfo *info = CFDictionaryGetValue(class_isMetaClass(cls) ? metaCache : classCache, (__bridge const void *)(cls));
    if (info && info->_needUpdate) {
        [info _update];
    }
    OSSpinLockUnlock(&lock);
    if (!info) {
        info = [[YYClassInfo alloc] initWithClass:cls];
        if (info) {
            OSSpinLockLock(&lock);
            CFDictionarySetValue(info.isMeta ? metaCache : classCache, (__bridge const void *)(cls), (__bridge const void *)(info));
            OSSpinLockUnlock(&lock);
        }
    }
    return info;
}

+ (instancetype)classInfoWithClassName:(NSString *)className {
    Class cls = NSClassFromString(className);
    return [self classInfoWithClass:cls];
}

@end
