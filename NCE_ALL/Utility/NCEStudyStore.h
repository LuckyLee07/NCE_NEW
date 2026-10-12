#import <Foundation/Foundation.h>

// Book indices used by controllers are zero based. Database book_id is one based.
@interface NCEStudyStore : NSObject
+ (NSInteger)selectedBook;
+ (void)selectBook:(NSInteger)book;
+ (NSArray<NSDictionary *> *)lessonsForBook:(NSInteger)book;
+ (NSArray<NSDictionary *> *)wordsForBook:(NSInteger)book lesson:(NSInteger)lesson;
+ (NSString *)lessonTitle:(NSDictionary *)lesson;
+ (NSString *)lessonTranslation:(NSDictionary *)lesson;
+ (NSString *)meaningForWord:(NSDictionary *)word;
+ (NSDictionary *)exampleForWord:(NSDictionary *)word;
+ (NSDictionary *)resumeForBook:(NSInteger)book;
+ (NSArray<NSDictionary *> *)recentLessonsForBook:(NSInteger)book;
+ (void)recordLesson:(NSDictionary *)lesson book:(NSInteger)book sentence:(NSInteger)sentence;
+ (void)markWordWrong:(NSDictionary *)word;
+ (BOOL)isBookmarked:(NSDictionary *)word;
+ (void)toggleBookmark:(NSDictionary *)word;
@end
