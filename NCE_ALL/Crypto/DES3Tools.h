//
// DES3Tools.h
// Version 1.0.0
// Created by lizi on 17/9/1.
//

#import <Foundation/Foundation.h>

@interface DES3Tools : NSObject

// 加密方法
+ (NSString *)encrypt:(NSString *)plainText;

// 解密方法
+ (NSString *)decrypt:(NSString *)cipherText;

@end
