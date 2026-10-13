#import <Foundation/Foundation.h>
#import "../../NCE_ALL/Utility/NCEWordLookup.h"
static NSDictionary *Word(NSString *name,NSInteger book,NSInteger lesson){return @{@"english":name,@"book_id":@(book),@"lesson_id":@(lesson)};}
static void Check(BOOL ok,NSString *message){if(!ok){NSLog(@"FAILED: %@",message);exit(1);}}
int main(void){@autoreleasepool{
    NSDictionary *current=Word(@"bank",3,4),*other=Word(@"bank",1,2);
    NSArray *words=@[other,current,Word(@"bank",3,8),Word(@"puma",3,1),Word(@"go",1,2),Word(@"run",1,2),Word(@"child",1,2),Word(@"study",1,2),Word(@"like",1,2),Word(@"use",1,1),Word(@"us",1,1),Word(@"care",1,1),Word(@"car",1,1),Word(@"cat-like",3,1),Word(@"saw",2,1),Word(@"see",2,2),@{@"english":@"Mew Jersey",@"lookup_name":@"New Jersey",@"book_id":@4,@"lesson_id":@1}];
    NCEWordLookup *lookup=[[NCEWordLookup alloc] initWithWords:words];
    Check([lookup matchWord:@"BANK" bookID:3 lessonID:4]==current,@"Current-lesson exact match");
    Check([[lookup matchWord:@"bank" bookID:3 lessonID:99][@"book_id"] intValue]==3,@"Current-book fallback");
    for(NSArray *pair in @[@[@"Pumas",@"puma"],@[@"went",@"go"],@[@"running",@"run"],@[@"children",@"child"],@[@"studied",@"study"],@[@"likes",@"like"],@[@"saw",@"saw"],@[@"uses",@"use"],@[@"cared",@"care"],@[@"cat‑like",@"cat-like"]])Check([[lookup matchWord:pair[0] bookID:3 lessonID:1][@"english"] isEqual:pair[1]],pair[0]);
    Check([lookup matchWord:@"zzunknown" bookID:1 lessonID:1]==nil,@"Unknown must not invent a definition");
    Check([[lookup matchWord:@"New Jersey" bookID:4 lessonID:1][@"english"] isEqual:@"Mew Jersey"],@"Display aliases preserve original keys");
    NSString *text=@"  Pumas, cat-like animals. I'm John’s friend! 42";
    NSMutableArray *tokens=[NSMutableArray new];for(NSValue *v in [NCEWordLookup wordRangesInText:text])[tokens addObject:[text substringWithRange:v.rangeValue]];
    Check([tokens isEqual:@[@"Pumas",@"cat-like",@"animals",@"I'm",@"John’s",@"friend"]],@"Token ranges exclude punctuation and preserve apostrophes/hyphens");
    puts("Word lookup checks passed: context, aliases, inflections, unknown words, punctuation and exact ranges.");
}return 0;}
