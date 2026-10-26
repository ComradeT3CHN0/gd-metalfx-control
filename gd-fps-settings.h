#import <Foundation/Foundation.h>
#import <CommonCrypto/CommonCryptor.h>

static NSString *GDFPSPath(void) {
    return [NSHomeDirectory() stringByAppendingPathComponent:@"Library/Application Support/GeometryDash/CCGameManager.dat"];
}
static void GDFPSFail(NSString *message) {
    @throw [NSException exceptionWithName:@"FPS settings" reason:message userInfo:nil];
}
static NSData *GDFPSCrypt(NSData *input, CCOperation operation) {
    const unsigned char key[32] = {0x69,0x70,0x75,0x39,0x54,0x55,0x76,0x35,0x34,0x79,0x76,0x5d,0x69,0x73,0x46,0x4d,0x68,0x35,0x40,0x3b,0x74,0x2e,0x35,0x77,0x33,0x34,0x45,0x32,0x52,0x79,0x40,0x7b};
    NSMutableData *output=[NSMutableData dataWithLength:input.length+kCCBlockSizeAES128];
    size_t count=0;
    CCCryptorStatus result=CCCrypt(operation,kCCAlgorithmAES,kCCOptionECBMode|kCCOptionPKCS7Padding,key,sizeof(key),NULL,input.bytes,input.length,output.mutableBytes,output.length,&count);
    if(result!=kCCSuccess)GDFPSFail(@"Could not decode or encode GD's settings. No settings were changed.");
    output.length=count;return output;
}
static NSRegularExpression *GDFPSRegex(NSString *pattern) {
    return [NSRegularExpression regularExpressionWithPattern:pattern options:NSRegularExpressionDotMatchesLineSeparators error:NULL];
}
static NSTextCheckingResult *GDFPSOne(NSString *text, NSString *pattern) {
    NSArray *matches=[GDFPSRegex(pattern) matchesInString:text options:0 range:NSMakeRange(0,text.length)];
    if(matches.count!=1)GDFPSFail(@"GD's settings format was not recognized. No settings were changed.");
    return matches.firstObject;
}
static NSString *GDFPSPlain(NSData *data) {
    NSString *text=[[NSString alloc]initWithData:GDFPSCrypt(data,kCCDecrypt) encoding:NSISOLatin1StringEncoding];
    if(!text || ![text hasSuffix:@"</plist>"])GDFPSFail(@"GD's settings file is not supported. No settings were changed.");
    return text;
}
static NSDictionary *GDFPSRead(NSString *path) {
    NSData *data=[NSData dataWithContentsOfFile:path];if(!data)GDFPSFail(@"Could not read GD's settings. Open the game once to create them.");
    NSString *text=GDFPSPlain(data);
    NSTextCheckingResult *fps=GDFPSOne(text,@"<k>customFPSTarget</k><r>([0-9.]+)</r>");
    NSTextCheckingResult *keeper=GDFPSOne(text,@"<k>valueKeeper</k><d>(.*?)</d>");
    NSString *values=[text substringWithRange:[keeper rangeAtIndex:1]];
    NSArray *vsync=[GDFPSRegex(@"<k>gv_0030</k><s>([01])</s>") matchesInString:values options:0 range:NSMakeRange(0,values.length)];
    if(vsync.count>1)GDFPSFail(@"Duplicate VSync settings found. No settings were changed.");
    return @{@"maxFPS":@([[text substringWithRange:[fps rangeAtIndex:1]] integerValue]),@"vsync":@(vsync.count && [[values substringWithRange:[vsync.firstObject rangeAtIndex:1]] isEqualToString:@"1"])};
}
static NSString *GDFPSUpdated(NSString *text, BOOL vsync, NSInteger fps) {
    if(fps<1 || fps>10000)GDFPSFail(@"Max FPS must be a whole number from 1 to 10000.");
    NSTextCheckingResult *target=GDFPSOne(text,@"<k>customFPSTarget</k><r>[0-9.]+</r>");
    NSMutableString *updated=[text mutableCopy];
    [updated replaceCharactersInRange:target.range withString:[NSString stringWithFormat:@"<k>customFPSTarget</k><r>%ld</r>",(long)fps]];
    NSTextCheckingResult *keeper=GDFPSOne(updated,@"<k>valueKeeper</k><d>(.*?)</d>");
    NSMutableString *values=[[updated substringWithRange:[keeper rangeAtIndex:1]] mutableCopy];
    for(NSString *key in @[@"0030",@"0116"]){
        NSString *pattern=[NSString stringWithFormat:@"<k>gv_%@</k><s>[^<]*</s>",key];
        NSArray *matches=[GDFPSRegex(pattern) matchesInString:values options:0 range:NSMakeRange(0,values.length)];
        if(matches.count>1)GDFPSFail(@"Duplicate FPS settings found. No settings were changed.");
        NSString *replacement=[NSString stringWithFormat:@"<k>gv_%@</k><s>%d</s>",key,[key isEqualToString:@"0030"]?vsync:1];
        if(matches.count)[values replaceCharactersInRange:((NSTextCheckingResult*)matches.firstObject).range withString:replacement];
        else [values appendString:replacement];
    }
    [updated replaceCharactersInRange:[keeper rangeAtIndex:1] withString:values];return updated;
}
static void GDFPSApply(NSString *path, NSString *backupRoot, BOOL vsync, NSInteger fps) {
    NSData *original=[NSData dataWithContentsOfFile:path];if(!original)GDFPSFail(@"Could not read GD's settings. Open the game once to create them.");
    NSString *plain=GDFPSPlain(original), *updated=GDFPSUpdated(plain,vsync,fps);
    if([plain isEqualToString:updated])return;
    NSData *encrypted=GDFPSCrypt([updated dataUsingEncoding:NSISOLatin1StringEncoding],kCCEncrypt);
    if(![GDFPSPlain(encrypted) isEqualToString:updated])GDFPSFail(@"Could not verify the new FPS settings.");
    NSFileManager *fm=NSFileManager.defaultManager;NSError *error=nil;
    NSString *backup=[backupRoot stringByAppendingPathComponent:NSUUID.UUID.UUIDString];
    if(![fm createDirectoryAtPath:backup withIntermediateDirectories:YES attributes:nil error:&error] || ![fm copyItemAtPath:path toPath:[backup stringByAppendingPathComponent:@"CCGameManager.dat"] error:&error])GDFPSFail(error.localizedDescription);
    if(![[NSData dataWithContentsOfFile:path] isEqual:original])GDFPSFail(@"GD's settings changed while preparing the update. Please try again with GD closed.");
    if(![encrypted writeToFile:path options:NSDataWritingAtomic error:&error])GDFPSFail(error.localizedDescription);
    if(![[NSData dataWithContentsOfFile:path] isEqual:encrypted]){
        [original writeToFile:path options:NSDataWritingAtomic error:NULL];
        GDFPSFail(@"Could not verify saved FPS settings. The previous settings were restored.");
    }
}
