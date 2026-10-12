#import "WordTestViewController.h"
#import "NCEStudyStore.h"
@implementation WordTestViewController
- (id)initWithBookId:(int)bookId withLessonId:(int)lessonId withFunction:(int)function {return [super initWithWords:[NCEStudyStore wordsForBook:bookId lesson:lessonId] key:[NSString stringWithFormat:@"legacy-%d-%d",bookId,lessonId] mode:function==5 ? 3 : 4];}
@end
