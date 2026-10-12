#import <Foundation/Foundation.h>
#import "../../NCE_ALL/Utility/NCEPracticeSession.h"
static void Check(BOOL ok,NSString *message){if(!ok){fprintf(stderr,"%s\n",message.UTF8String);exit(1);}}
int main(){@autoreleasepool{
    NSString *suite=[@"NCEStudySessionTests." stringByAppendingString:NSUUID.UUID.UUIDString];NSUserDefaults *defaults=[[NSUserDefaults alloc] initWithSuiteName:suite];
    NSDictionary *a=@{@"english":@"engineer",@"book_id":@1},*b=@{@"english":@"teacher",@"book_id":@1},*c=@{@"english":@"doctor",@"book_id":@1};NSArray *words=@[a,b,c];
    NCEPracticeSession *s=[[NCEPracticeSession alloc] initWithItems:words key:@"round" defaults:defaults];s.input=@"enginer";s.options=@[b,a,c];s.selectedOption=1;[s save];
    s=[[NCEPracticeSession alloc] initWithItems:words key:@"round" defaults:defaults];Check([s.input isEqual:@"enginer"] && s.selectedOption==1 && [s.options isEqual:@[b,a,c]],@"Unsubmitted draft and option order must survive reopening");
    Check([s submit:s.input correct:NO skipped:NO],@"First submission failed");Check(![s submit:@"engineer" correct:YES skipped:NO],@"Duplicate grading must be rejected");
    s=[[NCEPracticeSession alloc] initWithItems:words key:@"round" defaults:defaults];Check(s.answered && s.index==0 && s.wrongWords.count==1,@"Graded question must resume without advancing");[s advance];
    [s submit:@"teacher" correct:YES skipped:NO];[s advance];[s submit:@"" correct:NO skipped:YES];[s advance];Check(s.complete && s.correctCount==1 && s.wrongWords.count==1 && s.skippedCount==1,@"Correct, wrong and skipped must be disjoint");Check([[defaults arrayForKey:@"NCEPracticeHistory"] count]==1,@"Completed session must enter history once");[s advance];Check([[defaults arrayForKey:@"NCEPracticeHistory"] count]==1,@"Completion must be idempotent");
    NSArray *wrong=s.wrongWords;[s restartWithItems:wrong];Check(s.items.count==1 && !s.answered && !s.complete && !s.input.length,@"Wrong-only retry starts a clean round");[s submit:@"engineer" correct:YES skipped:NO];[s advance];Check(s.correctCount==1 && s.wrongWords.count==0 && [[defaults arrayForKey:@"NCEPracticeHistory"] count]==2,@"Retry must preserve original history");
    NCEPracticeSession *other=[[NCEPracticeSession alloc] initWithItems:words key:@"other-book" defaults:defaults];Check(other.index==0 && !other.answered,@"Book/mode drafts must remain independent");
    [defaults removePersistentDomainForName:suite];puts("Practice session checks passed: draft, grading, skip, retry, history, isolation.");
}return 0;}
