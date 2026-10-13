#import <Foundation/Foundation.h>
#import "../../NCE_ALL/Utility/NCEWordResourceStore.h"

static void Check(BOOL result, NSString *message) {
    if (!result) { fprintf(stderr,"%s\n",message.UTF8String); exit(1); }
}
int main(int argc,const char *argv[]) {
    @autoreleasepool {
        Check(argc==2,@"Usage: phonetics-store-test RESOURCES");
        NSString *root=@(argv[1]);
        NSDictionary *data=[NSJSONSerialization JSONObjectWithData:[NSData dataWithContentsOfFile:[root stringByAppendingPathComponent:@"phonetics-pilot.json"]] options:0 error:nil];
        NCEWordResourceStore *store=[[NCEWordResourceStore alloc] initWithRootDirectory:root];
        Check([data[@"records"] count]==100,@"Pilot must contain exactly 100 contexts");
        for (NSString *key in data[@"records"]) {
            NSArray *parts=[key componentsSeparatedByString:@"|"];
            Check([[store phoneticForWord:parts[2] bookId:[parts[0] integerValue] lessonId:[parts[1] integerValue]] isEqual:data[@"records"][key][@"ipa"]],key);
            Check([store phoneticForWord:parts[2] bookId:[parts[0] integerValue] lessonId:9999]==nil,@"Never reuse another lesson's homograph");
        }
        NSDictionary *book=[NSJSONSerialization JSONObjectWithData:[NSData dataWithContentsOfFile:[root stringByAppendingPathComponent:@"phonetics-book1.json"]] options:0 error:nil];
        Check([book[@"records"] count]==624,@"Book 1 must cover all 624 lesson contexts");
        for (NSString *key in book[@"records"]) {
            NSArray *parts=[key componentsSeparatedByString:@"|"];
            Check([[store phoneticForWord:parts[2] bookId:1 lessonId:[parts[1] integerValue]] isEqual:book[@"records"][key][@"ipa"]],key);
            Check([store phoneticForWord:parts[2] bookId:1 lessonId:9999]==nil,@"No cross-lesson fallback for book data");
        }
        NSDictionary *examples=@{@"5|Mr.":@"/ˈmɪstə/", @"25|Mrs.":@"/ˈmɪsɪz/",
            @"17|sales reps":@"/ˈseɪlz ˌreps/", @"63|get up":@"/ˌɡet ˈʌp/",
            @"45|minute":@"/ˈmɪnɪt/", @"55|live":@"/lɪv/", @"105|present":@"/ˈprezənt/",
            @"141|compact":@"/ˈkɒmpækt/", @"127|read":@"/riːd/",
            @"101|association":@"/əˌsəʊsiˈeɪʃən/", @"143|litter basket":@"/ˈlɪtə ˌbɑːskɪt/",
            @"41|chocolate":@"/ˈtʃɒklət/", @"53|subject":@"/ˈsʌbdʒekt/",
            @"61|medicine":@"/ˈmedɪsən/", @"75|uncomfortable":@"/ʌnˈkʌmftəbəl/",
            @"93|New York":@"/ˌnjuː ˈjɔːk/", @"67|absent":@"/ˈæbsənt/",
            @"39|vase":@"/vɑːz/", @"17|employee":@"/ɪmˈplɔɪiː/", @"53|interesting":@"/ˈɪntrestɪŋ/"};
        for (NSString *key in examples) {
            NSArray *parts=[key componentsSeparatedByString:@"|"];
            Check([[store phoneticForWord:parts[1] bookId:1 lessonId:[parts[0] integerValue]] isEqual:examples[key]],key);
        }
        Check([store phoneticForWord:@"extra" bookId:1 lessonId:0]==nil,@"Non-lesson fixture must not enter coverage");
        Check([[store phoneticForWord:@"excuse" bookId:1 lessonId:1] isEqual:@"/ɪkˈskjuːz/"],@"Verb excuse must retain voiced ending");
        Check([store phoneticForWord:@"fossil man" bookId:4 lessonId:1]==nil,@"Unreviewed phrases must stay empty");
        Check([store phoneticForWord:@"puma" bookId:2 lessonId:1]==nil,@"No cross-book reuse");
        NSString *temp=[NSTemporaryDirectory() stringByAppendingPathComponent:NSUUID.UUID.UUIDString];
        [NSFileManager.defaultManager createDirectoryAtPath:temp withIntermediateDirectories:YES attributes:nil error:nil];
        NSString *path=[temp stringByAppendingPathComponent:@"phonetics-pilot.json"];
        NSArray *invalid=@[@"broken",@"[]",@"{\"format_version\":2,\"records\":{}}",@"{\"format_version\":1,\"records\":[]}"];
        for (NSString *json in invalid) {
            [json writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:nil];
            Check([[[NCEWordResourceStore alloc] initWithRootDirectory:temp] phoneticForWord:@"puma" bookId:3 lessonId:1]==nil,@"Bad file must safely hide IPA");
        }
        for (NSDictionary *override in @[@{@"ipa":@3},@{@"ipa":@"puma"},@{@"ipa":@"/p\nu/"},@{@"status":@"pending"},@{@"accent":@"en-US"}]) {
            NSMutableDictionary *record=[@{@"ipa":@"/ˈpjuːmə/",@"status":@"source_checked",@"accent":@"en-GB"} mutableCopy];
            [record addEntriesFromDictionary:override];
            [[NSJSONSerialization dataWithJSONObject:@{@"format_version":@1,@"records":@{@"3|1|puma":record}} options:0 error:nil] writeToFile:path atomically:YES];
            Check([[[NCEWordResourceStore alloc] initWithRootDirectory:temp] phoneticForWord:@"puma" bookId:3 lessonId:1]==nil,@"Unapproved or malformed records must hide IPA");
        }
        [NSFileManager.defaultManager removeItemAtPath:path error:nil];
        Check([[[NCEWordResourceStore alloc] initWithRootDirectory:temp] phoneticForWord:@"puma" bookId:3 lessonId:1]==nil,@"Old bundles without IPA remain supported");
        // A malformed volume must not remove the independent pilot, and a volume
        // must never inject another book's records. A reviewed volume wins overlaps.
        NSDictionary *pilotRecord=@{@"ipa":@"/miː/",@"status":@"source_checked",@"accent":@"en-GB"};
        [[NSJSONSerialization dataWithJSONObject:@{@"format_version":@1,@"records":@{@"1|1|me":pilotRecord}} options:0 error:nil] writeToFile:path atomically:YES];
        NSString *bookPath=[temp stringByAppendingPathComponent:@"phonetics-book1.json"];
        for (id invalidVolume in @[@[], @{@"format_version":@2,@"book_id":@1,@"records":@{}},
                                  @{@"format_version":@1,@"book_id":@2,@"records":@{}},
                                  @{@"format_version":@1,@"book_id":@1,@"records":@[]}]) {
            [[NSJSONSerialization dataWithJSONObject:invalidVolume options:0 error:nil] writeToFile:bookPath atomically:YES];
            Check([[[[NCEWordResourceStore alloc] initWithRootDirectory:temp] phoneticForWord:@"me" bookId:1 lessonId:1] isEqual:@"/miː/"],@"Invalid volume preserves pilot");
        }
        NSDictionary *volumeRecord=@{@"ipa":@"/mi/",@"status":@"editorial_checked",@"accent":@"en-GB"};
        [[NSJSONSerialization dataWithJSONObject:@{@"format_version":@1,@"book_id":@1,@"records":@{@"1|1|me":volumeRecord,@"2|1|me":volumeRecord,@"1|1|bad":@[]}} options:0 error:nil] writeToFile:bookPath atomically:YES];
        NCEWordResourceStore *merged=[[NCEWordResourceStore alloc] initWithRootDirectory:temp];
        Check([[merged phoneticForWord:@"me" bookId:1 lessonId:1] isEqual:@"/mi/"],@"Volume takes precedence over pilot");
        Check([merged phoneticForWord:@"me" bookId:2 lessonId:1]==nil,@"Book 1 cannot inject book 2");
        Check([merged phoneticForWord:@"bad" bookId:1 lessonId:1]==nil,@"Malformed volume record safely hides IPA");
        [NSFileManager.defaultManager removeItemAtPath:temp error:nil];
        puts("PASS: 100 pilot + 624 book 1 lookups, phrase/homograph regressions, volume precedence/isolation, malformed/missing data and review status gates.");
    }
    return 0;
}
