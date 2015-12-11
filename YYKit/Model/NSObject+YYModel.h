//
//  NSObject+YYModel.h
//  YYKit <https://github.com/ibireme/YYKit>
//
//  Created by ibireme on 15/5/10.
//  Copyright (c) 2015 ibireme.
//
//  This source code is licensed under the MIT-style license found in the
//  LICENSE file in the root directory of this source tree.
//

#import <Foundation/Foundation.h>

/**
 Provide some data-model method:
 
 * Convert json to any object, or convert any object to json.
 * Set object properties with a key-value dictionary (like KVC).
 * Implementations of `NSCoding`, `NSCopying`, `-hash` and `-isEqual:`.
 
 See `YYModel` protocol for custom methods.
 
 
 Sample Code:
    
     ********************** json convertor *********************
     @interface YYAuthor : NSObject
     @property (nonatomic, strong) NSString *name;
     @property (nonatomic, assign) NSDate *birthday;
     @end
     @implementation YYAuthor
     @end
 
     @interface YYBook : NSObject
     @property (nonatomic, copy) NSString *name;
     @property (nonatomic, assign) NSUInteger pages;
     @property (nonatomic, strong) YYAuthor *author;
     @end
     @implementation YYBook
     @end
    
     int main() {
         // create model from json
         YYBook *book = [YYBook modelWithJSON:@"{\"name\": \"Harry Potter\", \"pages\": 256, \"author\": {\"name\": \"J.K.Rowling\", \"birthday\": \"1965-07-31\" }}"];
 
         // convert model to json
         NSString *json = [book modelToJSONString];
         // {"author":{"name":"J.K.Rowling","birthday":"1965-07-31T00:00:00+0000"},"name":"Harry Potter","pages":256}
     }
 
     ********************** Coding/Copying/hash/equal *********************
    归档、拷贝、hash、eaual
     @interface YYShadow :NSObject <NSCoding, NSCopying>
     @property (nonatomic, copy) NSString *name;
     @property (nonatomic, assign) CGSize size;
     @end
 
     @implementation YYShadow
     - (void)encodeWithCoder:(NSCoder *)aCoder { [self modelEncodeWithCoder:aCoder]; }
     - (id)initWithCoder:(NSCoder *)aDecoder { self = [super init]; return [self modelInitWithCoder:aDecoder]; }
     - (id)copyWithZone:(NSZone *)zone { return [self modelCopy]; }
     - (NSUInteger)hash { return [self modelHash]; }
     - (BOOL)isEqual:(id)object { return [self modelIsEqual:object]; }
     @end
 
 */
@interface NSObject (YYModel)

/**
 Creates and returns a new instance of the receiver from a json.
 This method is thread-safe. -------------------------------------> 通过json创建并返回一个本类型的实例对象
 
 
 @param json  A json object in `NSDictionary`, `NSString` or `NSData`. -> json 一个json对象可以是NSDictionary，NSString或者NSData类型
 
 @return A new instance created from the json, or nil if an error occurs.-> 一个新有json对象转化的新的实例
 */
+ (instancetype)modelWithJSON:(id)json;

/**
 Creates and returns a new instance of the receiver from a key-value dictionary.-> 通过键-值字典创建并返回一个本类的实例对象，线程安全
 This method is thread-safe.
 
 @param dictionary  A key-value dictionary mapped to the instance's properties.-> 一个用来映射对象实例属性的键-值字典，
 Any invalid key-value pair in dictionary will be ignored.-> 任何无效的键值对字典将会被遗忘
 
 @return A new instance created from the dictionary, or nil if an error occurs.-> 返回一个由字典生成的实例对象
 
 @discussion The key in `dictionary` will mapped to the reciever's property name,-> 字典的键（key）将被映射为接受者（类对象）的属性名
 and the value will set to the property. If the value's type does not match the -> 并且值（value）将被设置到属性上，如果值的类型和属性类型不匹配，该方法的转换
 property, this method will try to convert the value based on these rules:-> 将会尝试基于以下规则去转化
 
     `NSString` or `NSNumber` -> c number, such as BOOL, int, long, float, NSUInteger...
     `NSString` -> NSDate, parsed with format "yyyy-MM-dd'T'HH:mm:ssZ", "yyyy-MM-dd HH:mm:ss" or "yyyy-MM-dd".
     `NSString` -> NSURL.
     `NSValue` -> struct or union, such as CGRect, CGSize, ...
     `NSString` -> SEL, Class.
 */
+ (instancetype)modelWithDictionary:(NSDictionary *)dictionary;

/**
 Set the receiver's properties with a json object. -> j用json对象的初始化一个模型的属性值
 
 @discussion Any invalid data in json will be ignored. -> 不合法的数据将会被忽略
 
 @param json  A json object of `NSDictionary`, `NSString` or `NSData`, mapped to the
 receiver's properties. 
 
 @return Whether succeed.
 */
- (BOOL)modelSetWithJSON:(id)json;

/**
 Set the receiver's properties with a key-value dictionary.
 -> 用字典设置接收对象的属性
 
 @param dic  A key-value dictionary mapped to the receiver's properties.
 Any invalid key-value pair in dictionary will be ignored.
 -> 用来映射属性的字典任何不合法的键值对字典将会被忽略
 
 @discussion The key in `dictionary` will mapped to the reciever's property name,
 and the value will set to the property. If the value's type doesn't match the
 property, this method will try to convert the value based on these rules:
 -> 字典键类型与属性类型不匹配时转换规则如下：
 
     `NSString`, `NSNumber` -> c number, such as BOOL, int, long, float, NSUInteger...
     `NSString` -> NSDate, parsed with format "yyyy-MM-dd'T'HH:mm:ssZ", "yyyy-MM-dd HH:mm:ss" or "yyyy-MM-dd".
     `NSString` -> NSURL.
     `NSValue` -> struct or union, such as CGRect, CGSize, ...
     `NSString` -> SEL, Class.
 
 @return Whether succeed.
 */
- (BOOL)modelSetWithDictionary:(NSDictionary *)dic;

/**
 Generate a json object from the receiver's properties.
 -> 用调用者的对象属性生成一个json对象
 
 @return A json object in `NSDictionary` or `NSArray`, or nil if an error occurs.
 See [NSJSONSerialization isValidJSONObject] for more information.
 -> 通过接受者模型对象返回一个json对象（字典或者数组）或者nil当出错时，
 
 @discussion Any of the invalid property is ignored.
 If the reciver is `NSArray`, `NSDictionary` or `NSSet`, it just convert
 the inner object to json object.
 */
- (id)modelToJSONObject;

/**
 Generate a json string's data from the receiver's properties.
 -> 通过调用对象生成一个json的NSData对象
 
 @return A json string's data, or nil if an error occurs.
 -> 返回一个json字符串的data二进制数据
 
 @discussion Any of the invalid property is ignored.
 If the reciver is `NSArray`, `NSDictionary` or `NSSet`, it will also convert the 
 inner object to json string.
 */
- (NSData *)modelToJSONData;

/**
 Generate a json string from the receiver's properties.
 
 @return A json string, or nil if an error occurs.
 
 @discussion Any of the invalid property is ignored.
 If the reciver is `NSArray`, `NSDictionary` or `NSSet`, it will also convert the 
 inner object to json string.
 */
- (NSString *)modelToJSONString;

/**
 Copy a instance with the receiver's properties.
 
 @return A copied instance, or nil if an error occurs.
 */
- (id)modelCopy;

/**
 Encode the receiver's properties to a coder.
 
 @param aCoder  An archiver object.
 */
- (void)modelEncodeWithCoder:(NSCoder *)aCoder;

/**
 Decode the receiver's properties from a decoder.
 
 @param aDecoder  An archiver object.
 
 @return self
 */
- (id)modelInitWithCoder:(NSCoder *)aDecoder;

/**
 Get a hash code with the receiver's properties.
 
 @return Hash code.
 */
- (NSUInteger)modelHash;

/**
 Compares the receiver with another object for equality, based on properties.
 
 @param model  Another object.
 
 @return `YES` if the reciever is equal to the object, otherwise `NO`.
 */
- (BOOL)modelIsEqual:(id)model;

@end



/**
 Provide some data-model method for NSArray.
 */
@interface NSArray (YYModel)

/**
 Creates and returns an array from a json-array.
 This method is thread-safe.
 
 @param cls  The instance's class in array.
 @param json  A json array of `NSArray`, `NSString` or `NSData`.
              Example: [{"name","Mary"},{name:"Joe"}]
 
 @return A array, or nil if an error occurs.
 */
+ (NSArray *)modelArrayWithClass:(Class)cls json:(id)json;

@end



/**
 Provide some data-model method for NSDictionary.
 */
@interface NSDictionary (YYModel)

/**
 Creates and returns a dictionary from a json.
 This method is thread-safe.
 
 @param cls  The value instance's class in dictionary.
 @param json  A json dictionary of `NSDictionary`, `NSString` or `NSData`.
              Example: {"user1":{"name","Mary"}, "user2": {name:"Joe"}}
 
 @return A array, or nil if an error occurs.
 */
+ (NSDictionary *)modelDictionaryWithClass:(Class)cls json:(id)json;
@end



/**
 If the default model transform does not fit to your model class, implement one or
 more method in this protocol to change the default key-value transform process.
 There's no need to add '<YYModel>' to your class header.
 */
@protocol YYModel <NSObject>
@optional

/**
 Custom property mapper.
 
 @discussion If the key in JSON/Dictionary does not match to the model's property name,
 implements this method and returns the additional mapper.
 
 Example:
    
    json: 
        {
            "n":"Harry Pottery",
            "p": 256,
            "ext" : {
                "desc" : "A book written by J.K.Rowing."
            },
            "ID" : 100010
        }
 
    model:
        @interface YYBook : NSObject
        @property NSString *name;
        @property NSInteger page;
        @property NSString *desc;
        @property NSString *bookID;
        @end
        
        @implementation YYBook
        + (NSDictionary *)modelCustomPropertyMapper {
            return @{@"name"  : @"n",
                     @"page"  : @"p",
                     @"desc"  : @"ext.desc",
                     @"bookID": @[@"id", @"ID", @"book_id"]};
        }
        @end
 
 @return A custom mapper for properties.
 */
+ (NSDictionary *)modelCustomPropertyMapper;

/**
 The generic class mapper for container properties.
-》 利用字典自定义模型转换的映射关系
 
 @discussion If the property is a container object, such as NSArray/NSSet/NSDictionary,
 implements this method and returns a property->class mapper, tells which kind of 
 object will be add to the array/set/dictionary.
 -》 如果属性是一个容器对象，实现这个方法可以返回一个属性和所属类的映射关系，告诉模型容器中应该存放什么样的对象
 
  Example:
        @class YYShadow, YYBorder, YYAttachment;
 
        @interface YYAttributes
        @property NSString *name;
        @property NSArray *shadows;
        @property NSSet *borders;
        @property NSDictionary *attachments;
        @end
 
        @implementation YYAttributes
        + (NSDictionary *)modelContainerPropertyGenericClass {
            return @{@"shadows" : [YYShadow class],
                     @"borders" : YYBorder.class,
                     @"attachments" : @"YYAttachment" };
        }
        @end
 
 @return A class mapper.
 */
+ (NSDictionary *)modelContainerPropertyGenericClass;

/**
 If you need to create instances of different classes during json->object transform,
 use the method to choose custom class based on dictionary data.
 
 如果你在json转对象的同时需要创建不同的类实例，可以使用该方法去使用字典来选择你的数据的自定义数据类型
 
 @discussion If the model implements this method, it will be called to determine resulting class
 during `+modelWithJSON:`, `+modelWithDictionary:`, conveting object of properties of parent objects 
 (both singular and containers via `+modelContainerPropertyGenericClass`).
 
 如果模型实现此方法，他将被调用来决定`+modelWithJSON:`, `+modelWithDictionary:`这两个方法转换属性对象的父对象，包括单个对象和容器对象取决于`+modelContainerPropertyGenericClass`
 
 Example:
        @class YYCircle, YYRectangle, YYLine;
 
        @implementation YYShape

        + (Class)modelCustomClassForDictionary:(NSDictionary*)dictionary {
            if (dictionary[@"radius"] != nil) {
                return [YYCircle class];
            } else if (dictionary[@"width"] != nil) {
                return [YYRectangle class];
            } else if (dictionary[@"y2"] != nil) {
                return [YYLine class];
            } else {
                return [self class];
            }
        }

        @end

 @param dictionary The json/kv dictionary.
 
 @return Class to create from this dictionary, `nil` to use current class.

 */
+ (Class)modelCustomClassForDictionary:(NSDictionary*)dictionary;

/**
 All the properties in blacklist will be ignored in model transform process.
 Returns nil to ignore this feature.
 
 @return An array of property's name (Array<NSString>).
 */
+ (NSArray *)modelPropertyBlacklist;

/**
 If a property is not in the whitelist, it will be ignored in model transform process.
 Returns nil to ignore this feature.
 
 @return An array of property's name (Array<NSString>).
 */
+ (NSArray *)modelPropertyWhitelist;

/**
 If the default json-to-model transform does not fit to your model object, implement
 this method to do additional process. You can also use this method to validate the 
 model's properties.
 
 @discussion If the model implements this method, it will be called at the end of
 `+modelWithJSON:`, `+modelWithDictionary:`, `-modelSetWithJSON:` and `-modelSetWithDictionary:`.
 If this method returns NO, the transform process will ignore this model.
 
 @param dic  The json/kv dictionary.
 
 @return Returns YES if the model is valid, or NO to ignore this model.
 */
- (BOOL)modelCustomTransformFromDictionary:(NSDictionary *)dic;

/**
 If the default model-to-json transform does not fit to your model class, implement
 this method to do additional process. You can also use this method to validate the
 json dictionary.
 
 @discussion If the model implements this method, it will be called at the end of
 `-modelToJSONObject` and `-modelToJSONString`.
 If this method returns NO, the transform process will ignore this json dictionary.
 
 @param dic  The json dictionary.
 
 @return Returns YES if the model is valid, or NO to ignore this model.
 */
- (BOOL)modelCustomTransformToDictionary:(NSMutableDictionary *)dic;

@end
