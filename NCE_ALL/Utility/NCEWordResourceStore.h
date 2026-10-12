#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NCEWordResourceStore : NSObject
+ (instancetype)sharedStore;
- (instancetype)initWithRootDirectory:(NSString *)directory NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;
- (nullable NSString *)audioPathForWord:(NSString *)word;
- (nullable NSString *)imagePathForWord:(NSString *)word;
- (nullable NSString *)imagePathForWord:(NSString *)word bookId:(NSInteger)bookId;
- (nullable NSString *)visualCaptionForWord:(NSString *)word bookId:(NSInteger)bookId;
- (nullable NSString *)visualPresentationForWord:(NSString *)word bookId:(NSInteger)bookId;
- (nullable NSString *)visualHintForWord:(NSString *)word bookId:(NSInteger)bookId;
- (nullable NSString *)displayNameForWord:(nullable NSString *)word;
- (NSString *)sourceTranslationForWord:(nullable NSString *)word fallback:(NSString *)translation;
- (NSString *)translationForWord:(nullable NSString *)word fallback:(NSString *)translation;
- (BOOL)answer:(NSString *)answer matchesWord:(NSString *)word;
@end

NS_ASSUME_NONNULL_END
