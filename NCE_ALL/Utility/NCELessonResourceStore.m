#import "NCELessonResourceStore.h"
#import "../ThirdParty/minizip/unzip.h"

NSString * const NCELessonResourceErrorDomain = @"NCELessonResourceErrorDomain";

static NSError *NCEPackError(NSString *description)
{
    return [NSError errorWithDomain:NCELessonResourceErrorDomain code:1
                          userInfo:@{NSLocalizedDescriptionKey: description}];
}

@interface NCELessonArchive : NSObject
{
    unzFile _file;
    NSDictionary<NSString *, NSValue *> *_positions;
}
- (instancetype)initWithPath:(NSString *)path error:(NSError **)error;
- (NSData *)dataForEntry:(NSString *)entry maximumSize:(NSUInteger)maximumSize error:(NSError **)error;
@end

@implementation NCELessonArchive

- (instancetype)initWithPath:(NSString *)path error:(NSError **)error
{
    self = [super init];
    if (!self) return nil;
    _file = unzOpen64(path.fileSystemRepresentation);
    unz_global_info64 globalInfo;
    if (!_file || unzGetGlobalInfo64(_file, &globalInfo) != UNZ_OK ||
        globalInfo.number_entry == 0 || globalInfo.number_entry > 10000) {
        if (error) *error = NCEPackError(@"The bundled lesson ZIP is missing or invalid.");
        return nil;
    }

    NSMutableDictionary *positions = [NSMutableDictionary dictionary];
    int status = unzGoToFirstFile(_file);
    for (ZPOS64_T index = 0; index < globalInfo.number_entry; index++) {
        unz_file_info64 info;
        if (status != UNZ_OK || unzGetCurrentFileInfo64(_file, &info, NULL, 0, NULL, 0, NULL, 0) != UNZ_OK ||
            info.size_filename == 0 || info.size_filename > 1024 || (info.flag & 1) ||
            (info.compression_method != 0 && info.compression_method != Z_DEFLATED)) {
            if (error) *error = NCEPackError(@"Invalid or unsupported ZIP entry.");
            return nil;
        }
        NSMutableData *nameData = [NSMutableData dataWithLength:info.size_filename + 1];
        unz64_file_pos position;
        if (unzGetCurrentFileInfo64(_file, &info, nameData.mutableBytes, (uLong)nameData.length,
                                    NULL, 0, NULL, 0) != UNZ_OK || unzGetFilePos64(_file, &position) != UNZ_OK) {
            if (error) *error = NCEPackError(@"Unable to index the bundled lesson ZIP.");
            return nil;
        }
        NSString *name = [[NSString alloc] initWithBytes:nameData.bytes length:info.size_filename
                                               encoding:NSUTF8StringEncoding];
        if (!name || positions[name]) {
            if (error) *error = NCEPackError(@"Invalid UTF-8 or duplicate ZIP entry name.");
            return nil;
        }
        positions[name] = [NSValue valueWithBytes:&position objCType:@encode(unz64_file_pos)];
        status = unzGoToNextFile(_file);
    }
    _positions = positions.copy;
    return self;
}

- (NSData *)dataForEntry:(NSString *)entry maximumSize:(NSUInteger)maximumSize error:(NSError **)error
{
    NSValue *value = _positions[entry];
    unz64_file_pos position = {0};
    [value getValue:&position size:sizeof(position)];
    unz_file_info64 info;
    if (!value || unzGoToFilePos64(_file, &position) != UNZ_OK ||
        unzGetCurrentFileInfo64(_file, &info, NULL, 0, NULL, 0, NULL, 0) != UNZ_OK ||
        info.uncompressed_size == 0 || info.uncompressed_size > maximumSize ||
        unzOpenCurrentFile(_file) != UNZ_OK) {
        if (error) *error = NCEPackError([NSString stringWithFormat:@"Missing or invalid lesson entry: %@", entry]);
        return nil;
    }

    NSMutableData *data = [NSMutableData dataWithCapacity:(NSUInteger)info.uncompressed_size];
    unsigned char buffer[16384];
    int readSize;
    while ((readSize = unzReadCurrentFile(_file, buffer, sizeof(buffer))) > 0) {
        if (data.length + (NSUInteger)readSize > maximumSize) break;
        [data appendBytes:buffer length:(NSUInteger)readSize];
    }
    int closeStatus = unzCloseCurrentFile(_file);
    if (readSize != 0 || closeStatus != UNZ_OK || data.length != info.uncompressed_size) {
        if (error) *error = NCEPackError([NSString stringWithFormat:@"Corrupt lesson entry: %@", entry]);
        return nil;
    }
    return data;
}

- (void)dealloc
{
    if (_file) unzClose(_file);
}

@end

@interface NCELessonResourceStore ()
@property (nonatomic, copy) NSString *resourceDirectory;
@property (nonatomic, strong) NSMutableDictionary<NSNumber *, NCELessonArchive *> *archives;
@property (nonatomic, strong) NSCache<NSString *, NSData *> *cache;
@end

@implementation NCELessonResourceStore

+ (instancetype)sharedStore
{
    static NCELessonResourceStore *store;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSString *directory = [NSBundle.mainBundle.resourcePath stringByAppendingPathComponent:@"data/lesson-packs"];
        store = [[self alloc] initWithResourceDirectory:directory];
    });
    return store;
}

- (instancetype)initWithResourceDirectory:(NSString *)directory
{
    self = [super init];
    if (self) {
        _resourceDirectory = directory.copy;
        _archives = [NSMutableDictionary dictionary];
        _cache = [[NSCache alloc] init];
        _cache.totalCostLimit = 8 * 1024 * 1024;
        _cache.countLimit = 256;
    }
    return self;
}

- (NSData *)dataForSentence:(NSString *)sentence bookID:(NSInteger)bookID extension:(NSString *)extension
               maximumSize:(NSUInteger)maximumSize error:(NSError **)error
{
    if (bookID < 1 || bookID > 4 || ![sentence hasPrefix:[NSString stringWithFormat:@"N%ld_", (long)bookID]] ||
        [sentence containsString:@"/"] || [sentence containsString:@"\\"] ||
        [sentence rangeOfCharacterFromSet:NSCharacterSet.controlCharacterSet].location != NSNotFound) {
        if (error) *error = NCEPackError(@"Invalid book ID or sentence name.");
        return nil;
    }
    NSString *entry = [NSString stringWithFormat:@"%@/%@.%@", extension, sentence, extension];
    NSString *key = [NSString stringWithFormat:@"%ld/%@", (long)bookID, entry];

    // A ZIP handle has a mutable cursor; serialize indexing and reads across callers.
    @synchronized (self) {
        NSData *cached = [self.cache objectForKey:key];
        if (cached) return cached;
        NCELessonArchive *archive = self.archives[@(bookID)];
        if (!archive) {
            NSString *path = [self.resourceDirectory stringByAppendingPathComponent:
                              [NSString stringWithFormat:@"book%ld.zip", (long)bookID]];
            archive = [[NCELessonArchive alloc] initWithPath:path error:error];
            if (!archive) return nil;
            self.archives[@(bookID)] = archive;
        }
        NSData *data = [archive dataForEntry:entry maximumSize:maximumSize error:error];
        if (data) [self.cache setObject:data forKey:key cost:data.length];
        return data;
    }
}

- (NSData *)audioDataForSentence:(NSString *)sentence bookID:(NSInteger)bookID error:(NSError **)error
{
    return [self dataForSentence:sentence bookID:bookID extension:@"mp3" maximumSize:4 * 1024 * 1024 error:error];
}

- (NSString *)textForSentence:(NSString *)sentence bookID:(NSInteger)bookID error:(NSError **)error
{
    NSData *data = [self dataForSentence:sentence bookID:bookID extension:@"lrc" maximumSize:64 * 1024 error:error];
    if (!data) return nil;
    NSString *text = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    if (!text && error) *error = NCEPackError(@"The lesson text is not valid UTF-8.");
    return text;
}

@end
