#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSString * const NCELessonResourceErrorDomain;

@interface NCELessonResourceStore : NSObject

+ (instancetype)sharedStore;
- (instancetype)initWithResourceDirectory:(NSString *)directory NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

// Book IDs use the database's 1-based numbering, not the UI's 0-based numbering.
- (nullable NSData *)audioDataForSentence:(NSString *)sentence
                                 bookID:(NSInteger)bookID
                                  error:(NSError * _Nullable * _Nullable)error;
- (nullable NSString *)textForSentence:(NSString *)sentence
                               bookID:(NSInteger)bookID
                                error:(NSError * _Nullable * _Nullable)error;

@end

NS_ASSUME_NONNULL_END
