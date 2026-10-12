#import "WordDictationViewController.h"
#import "NCEStudyStore.h"
@implementation WordDictationViewController
- (id)initWithBookId:(int)bookId withLessonId:(int)lessonId {return [super initWithWords:[NCEStudyStore wordsForBook:bookId lesson:lessonId] key:[NSString stringWithFormat:@"legacy-%d-%d",bookId,lessonId] mode:2];}
@end
