#import "NCEStudyStore.h"
#import "NCEWordResourceStore.h"
#import "NCELessonResourceStore.h"
#import "NCELocalization.h"
#import <sqlite3.h>

@implementation NCEStudyStore
+ (NSInteger)selectedBook { return MIN(3, MAX(0, [NSUserDefaults.standardUserDefaults integerForKey:@"NCEAcademyBook"])); }
+ (void)selectBook:(NSInteger)book { [NSUserDefaults.standardUserDefaults setInteger:MIN(3,MAX(0,book)) forKey:@"NCEAcademyBook"]; }
+ (NSString *)text:(sqlite3_stmt *)stmt column:(int)column {
    const char *value=(const char *)sqlite3_column_text(stmt,column);
    return value ? @(value) : @"";
}
+ (NSArray<NSDictionary *> *)lessonsForBook:(NSInteger)book {
    sqlite3 *db=NULL; sqlite3_stmt *stmt=NULL; NSMutableArray *items=[NSMutableArray new];
    NSString *path=[NSBundle.mainBundle pathForResource:@"data/NCE" ofType:@"db"];
    if(path && sqlite3_open_v2(path.UTF8String,&db,SQLITE_OPEN_READONLY,NULL)==SQLITE_OK &&
       sqlite3_prepare_v2(db,"SELECT name,lesson_id FROM play_list_lessons WHERE book_id=? ORDER BY order_id",-1,&stmt,NULL)==SQLITE_OK) {
        sqlite3_bind_int(stmt,1,(int)book+1);
        while(sqlite3_step(stmt)==SQLITE_ROW) [items addObject:@{@"name":[self text:stmt column:0],@"id":[self text:stmt column:1]}];
    }
    sqlite3_finalize(stmt); if(db)sqlite3_close(db); return items;
}
+ (NSArray<NSDictionary *> *)wordsForBook:(NSInteger)book lesson:(NSInteger)lesson {
    sqlite3 *db=NULL; sqlite3_stmt *stmt=NULL; NSMutableArray *items=[NSMutableArray new];
    NSString *path=[NSHomeDirectory() stringByAppendingPathComponent:@"Documents/NCE.db"];
    if(![NSFileManager.defaultManager fileExistsAtPath:path])path=[NSBundle.mainBundle pathForResource:@"data/NCE" ofType:@"db"];
    if(path && sqlite3_open_v2(path.UTF8String,&db,SQLITE_OPEN_READONLY,NULL)==SQLITE_OK &&
       sqlite3_prepare_v2(db,"SELECT id,word_name,word_translation,lesson_id,book_id,word_status,wrong FROM words WHERE book_id=? AND (?=0 OR lesson_id=?) ORDER BY lesson_id,order_id",-1,&stmt,NULL)==SQLITE_OK) {
        sqlite3_bind_int(stmt,1,(int)book+1); sqlite3_bind_int(stmt,2,(int)lesson); sqlite3_bind_int(stmt,3,(int)lesson);
        while(sqlite3_step(stmt)==SQLITE_ROW) [items addObject:@{@"id":@(sqlite3_column_int(stmt,0)),@"english":[self text:stmt column:1],@"chinese":[self text:stmt column:2],@"lesson_id":[self text:stmt column:3],@"book_id":@(sqlite3_column_int(stmt,4)),@"status":@(sqlite3_column_int(stmt,5)),@"wrong":@(sqlite3_column_int(stmt,6))}];
    }
    sqlite3_finalize(stmt); if(db)sqlite3_close(db); return items;
}
+ (NSString *)lessonTitle:(NSDictionary *)lesson {
    NSArray *parts=[lesson[@"name"] componentsSeparatedByString:@"－"];
    return parts.count>1 ? parts[1] : lesson[@"name"] ?: @"";
}
+ (NSString *)lessonTranslation:(NSDictionary *)lesson {
    NSArray *parts=[lesson[@"name"] componentsSeparatedByString:@"－"];
    return parts.count>2 ? NCEChineseText(parts[2]) : @"";
}
+ (NSString *)meaningForWord:(NSDictionary *)word { return [NCEWordResourceStore.sharedStore translationForWord:word[@"english"] fallback:word[@"chinese"] ?: @""]; }
+ (NSDictionary *)exampleForWord:(NSDictionary *)word {
    NSInteger book=[word[@"book_id"] integerValue], lesson=[word[@"lesson_id"] integerValue];
    if(book<1 || lesson<1)return nil;
    sqlite3 *db=NULL; sqlite3_stmt *stmt=NULL; NSDictionary *example=nil;
    NSString *path=[NSBundle.mainBundle pathForResource:@"data/NCE" ofType:@"db"];
    if(path && sqlite3_open_v2(path.UTF8String,&db,SQLITE_OPEN_READONLY,NULL)==SQLITE_OK && sqlite3_prepare_v2(db,"SELECT name FROM play_list_sentences WHERE book_id=? AND lesson_id=? ORDER BY order_id",-1,&stmt,NULL)==SQLITE_OK) {
        sqlite3_bind_int(stmt,1,(int)book);sqlite3_bind_int(stmt,2,(int)lesson);
        NSString *display=[NCEWordResourceStore.sharedStore displayNameForWord:word[@"english"]];
        NSRegularExpression *regex=[NSRegularExpression regularExpressionWithPattern:[NSString stringWithFormat:@"(?i)\\b%@\\b",[NSRegularExpression escapedPatternForString:display ?: @""]] options:0 error:nil];
        while(sqlite3_step(stmt)==SQLITE_ROW) {
            NSString *name=[self text:stmt column:0];
            NSArray *parts=[[NCELessonResourceStore.sharedStore textForSentence:name bookID:book error:nil] componentsSeparatedByString:@"－"];
            if(parts.count<2 || [parts[0] length]>240 || ![regex firstMatchInString:parts[0] options:0 range:NSMakeRange(0,[parts[0] length])])continue;
            NSMutableCharacterSet *trim=NSCharacterSet.whitespaceAndNewlineCharacterSet.mutableCopy;[trim addCharactersInString:@"\uFEFF"];
            example=@{@"english":[parts[0] stringByTrimmingCharactersInSet:trim],@"translation":[[NCELocalization.sharedLocalization localizedLessonText:name fallback:parts[1]] stringByTrimmingCharactersInSet:trim]};break;
        }
    }
    sqlite3_finalize(stmt);if(db)sqlite3_close(db);return example;
}
+ (NSDictionary *)resumeForBook:(NSInteger)book {
    NSDictionary *saved=[NSUserDefaults.standardUserDefaults dictionaryForKey:@"NCEStudyResumeByBook"][@(book).stringValue];
    if(!saved){NSDictionary *legacy=[NSUserDefaults.standardUserDefaults dictionaryForKey:@"NCEAcademyResume"];if(legacy && [legacy[@"book"] integerValue]==book)saved=legacy;}
    return [saved[@"lesson"] isKindOfClass:NSDictionary.class] ? saved : nil;
}
+ (NSArray<NSDictionary *> *)recentLessonsForBook:(NSInteger)book {
    NSArray *history=[NSUserDefaults.standardUserDefaults arrayForKey:@"NCEStudyRecentLessons"] ?: @[];
    return [history filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(NSDictionary *entry, NSDictionary *bindings) {return [entry[@"book"] integerValue]==book;}]];
}
+ (void)recordLesson:(NSDictionary *)lesson book:(NSInteger)book sentence:(NSInteger)sentence {
    if(!lesson[@"id"])return;
    NSUserDefaults *defaults=NSUserDefaults.standardUserDefaults;
    NSDictionary *record=@{@"book":@(book),@"lesson":lesson,@"sentence":@(MAX(0,sentence))};
    NSMutableDictionary *all=[[defaults dictionaryForKey:@"NCEStudyResumeByBook"] mutableCopy] ?: [NSMutableDictionary new];all[@(book).stringValue]=record;
    [defaults setObject:all forKey:@"NCEStudyResumeByBook"];
    [defaults setObject:record forKey:@"NCEAcademyResume"];
    NSMutableArray *history=[[defaults arrayForKey:@"NCEStudyRecentLessons"] mutableCopy] ?: [NSMutableArray new];
    NSIndexSet *duplicates=[history indexesOfObjectsPassingTest:^BOOL(NSDictionary *item,NSUInteger idx,BOOL *stop){return [item[@"book"] integerValue]==book && [item[@"lesson"][@"id"] isEqual:lesson[@"id"]];}];
    [history removeObjectsAtIndexes:duplicates];[history insertObject:record atIndex:0];
    if(history.count>40)[history removeObjectsInRange:NSMakeRange(40,history.count-40)];
    [defaults setObject:history forKey:@"NCEStudyRecentLessons"];
}
+ (void)markWordWrong:(NSDictionary *)word {
    sqlite3 *db=NULL;sqlite3_stmt *stmt=NULL;
    NSString *path=[NSHomeDirectory() stringByAppendingPathComponent:@"Documents/NCE.db"];
    if(sqlite3_open_v2(path.UTF8String,&db,SQLITE_OPEN_READWRITE,NULL)==SQLITE_OK && sqlite3_prepare_v2(db,"UPDATE words SET wrong=1 WHERE book_id=? AND word_name=?",-1,&stmt,NULL)==SQLITE_OK){
        sqlite3_bind_int(stmt,1,[word[@"book_id"] intValue]);sqlite3_bind_text(stmt,2,[word[@"english"] UTF8String],-1,SQLITE_TRANSIENT);sqlite3_step(stmt);
    }sqlite3_finalize(stmt);if(db)sqlite3_close(db);
}
+ (NSString *)bookmarkKey:(NSDictionary *)word { return [NSString stringWithFormat:@"%@:%@",word[@"book_id"],word[@"english"]]; }
+ (BOOL)isBookmarked:(NSDictionary *)word { return [[NSUserDefaults.standardUserDefaults arrayForKey:@"NCEStudyBookmarks"] containsObject:[self bookmarkKey:word]]; }
+ (void)toggleBookmark:(NSDictionary *)word {
    NSMutableArray *items=[[NSUserDefaults.standardUserDefaults arrayForKey:@"NCEStudyBookmarks"] mutableCopy] ?: [NSMutableArray new];
    NSString *key=[self bookmarkKey:word];if([items containsObject:key])[items removeObject:key];else [items addObject:key];
    [NSUserDefaults.standardUserDefaults setObject:items forKey:@"NCEStudyBookmarks"];
}
@end
