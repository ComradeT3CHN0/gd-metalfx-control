#import "gd-fps-settings.h"
static void require(BOOL pass, NSString *message){if(!pass){NSLog(@"FAIL: %@",message);exit(1);}}
int main(void){@autoreleasepool{
 NSString *plain=@"<?xml version=\"1.0\"?><plist version=\"1.0\"><dict><k>customFPSTarget</k><r>120</r><k>valueKeeper</k><d><k>gv_0030</k><s>1</s><k>gv_0116</k><s>1</s><k>gv_0023</k><s>0</s></d><k>sentinel</k><s>\u00ab unchanged</s></dict></plist>";
 NSString *root=[NSTemporaryDirectory() stringByAppendingPathComponent:NSUUID.UUID.UUIDString];NSFileManager *fm=NSFileManager.defaultManager;[fm createDirectoryAtPath:root withIntermediateDirectories:YES attributes:nil error:NULL];
 NSString *path=[root stringByAppendingPathComponent:@"settings.dat"],*backups=[root stringByAppendingPathComponent:@"backups"];
 NSData *original=GDFPSCrypt([plain dataUsingEncoding:NSISOLatin1StringEncoding],kCCEncrypt);[original writeToFile:path atomically:YES];
 GDFPSApply(path,backups,NO,480);NSDictionary *settings=GDFPSRead(path);
 require([settings[@"maxFPS"] integerValue]==480 && ![settings[@"vsync"] boolValue],@"480 FPS / VSync off round trip");
 NSString *expected=[plain stringByReplacingOccurrencesOfString:@"<r>120</r>" withString:@"<r>480</r>"];expected=[expected stringByReplacingOccurrencesOfString:@"<k>gv_0030</k><s>1</s>" withString:@"<k>gv_0030</k><s>0</s>"];
 require([GDFPSPlain([NSData dataWithContentsOfFile:path]) isEqualToString:expected],@"all unrelated settings preserved exactly");
 NSArray *entries=[fm contentsOfDirectoryAtPath:backups error:NULL];require(entries.count==1,@"one backup");require([[NSData dataWithContentsOfFile:[[backups stringByAppendingPathComponent:entries[0]] stringByAppendingPathComponent:@"CCGameManager.dat"]] isEqual:original],@"original ciphertext backed up");
 GDFPSApply(path,backups,NO,480);require([fm contentsOfDirectoryAtPath:backups error:NULL].count==1,@"unchanged launch skips backup");
 GDFPSApply(path,backups,YES,120);require([GDFPSPlain([NSData dataWithContentsOfFile:path]) isEqualToString:plain],@"120 FPS / VSync on restored exactly");
 for(NSNumber *fps in @[@0,@10001]){BOOL rejected=NO;@try{GDFPSApply(path,backups,YES,fps.integerValue);}@catch(NSException *e){rejected=YES;}require(rejected,@"out of range rejected");require([[NSData dataWithContentsOfFile:path] isEqual:original],@"invalid input leaves settings unchanged");}
 BOOL rejected=NO;@try{GDFPSUpdated(@"<plist></plist>",NO,120);}@catch(NSException *e){rejected=YES;}require(rejected,@"unknown format rejected");
 NSString *missing=[plain stringByReplacingOccurrencesOfString:@"<k>gv_0030</k><s>1</s><k>gv_0116</k><s>1</s>" withString:@""];NSString *added=GDFPSUpdated(missing,YES,240);require([added containsString:@"<k>gv_0030</k><s>1</s>"]&&[added containsString:@"<k>gv_0116</k><s>1</s>"],@"missing keys inserted");
 [fm removeItemAtPath:root error:NULL];NSLog(@"PASS: FPS settings, preservation, backups, no-op, validation, missing keys");
}}
