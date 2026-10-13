#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
// Keeps curriculum keys intact; lookup aliases never change saved learning records.
@interface NCEWordLookup : NSObject
- (instancetype)initWithWords:(NSArray<NSDictionary *> *)words;
- (nullable NSDictionary *)matchWord:(NSString *)word bookID:(NSInteger)book lessonID:(NSInteger)lesson;
+ (NSArray<NSValue *> *)wordRangesInText:(NSString *)text;
@end
NS_ASSUME_NONNULL_END
