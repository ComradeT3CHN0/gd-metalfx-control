#import <Cocoa/Cocoa.h>
#include <unistd.h>
#import "gd-fps-settings.h"
static void run(NSArray<NSString *> *args) {
 NSTask *task=[NSTask new];task.executableURL=[NSURL fileURLWithPath:@"/usr/bin/open"];task.arguments=args;
 NSError *error=nil;if(![task launchAndReturnError:&error]) @throw [NSException exceptionWithName:@"Launch" reason:error.localizedDescription userInfo:nil];
 [task waitUntilExit];if(task.terminationStatus) @throw [NSException exceptionWithName:@"Launch" reason:@"macOS could not open the application." userInfo:nil];
}
static void command(NSString *path, NSArray<NSString *> *args) {
 NSTask *task=[NSTask new];task.executableURL=[NSURL fileURLWithPath:path];task.arguments=args;NSError *error=nil;
 if(![task launchAndReturnError:&error])@throw [NSException exceptionWithName:@"Setup" reason:error.localizedDescription userInfo:nil];
 [task waitUntilExit];if(task.terminationStatus)@throw [NSException exceptionWithName:@"Setup" reason:@"Could not apply the Retina setting. The previous game files will be restored." userInfo:nil];
}
static void retinaSetting(NSString *game, BOOL enabled) {
 NSString *plist=[game stringByAppendingPathComponent:@"Contents/Info.plist"];
 NSMutableDictionary *info=[[NSDictionary dictionaryWithContentsOfFile:plist] mutableCopy];if(!info)@throw [NSException exceptionWithName:@"Setup" reason:@"Could not read Geometry Dash’s display settings." userInfo:nil];
 id current=info[@"NSHighResolutionCapable"];if(current && [current boolValue]==enabled)return;
 NSFileManager *fm=NSFileManager.defaultManager;NSString *relativeExe=[@"Contents/MacOS" stringByAppendingPathComponent:info[@"CFBundleExecutable"]];NSString *exe=[game stringByAppendingPathComponent:relativeExe];NSString *signature=[game stringByAppendingPathComponent:@"Contents/_CodeSignature"];
 NSString *backup=[[NSHomeDirectory() stringByAppendingPathComponent:@"Library/Application Support/GD MetalFX Control/Game backups"] stringByAppendingPathComponent:NSUUID.UUID.UUIDString];NSError *error=nil;
 if(![fm createDirectoryAtPath:backup withIntermediateDirectories:YES attributes:nil error:&error]||![fm copyItemAtPath:plist toPath:[backup stringByAppendingPathComponent:@"Info.plist"] error:&error]||![fm copyItemAtPath:exe toPath:[backup stringByAppendingPathComponent:@"Executable"] error:&error])@throw [NSException exceptionWithName:@"Backup" reason:error.localizedDescription userInfo:nil];
 BOOL hadSignature=[fm fileExistsAtPath:signature];if(hadSignature&&![fm copyItemAtPath:signature toPath:[backup stringByAppendingPathComponent:@"_CodeSignature"] error:&error])@throw [NSException exceptionWithName:@"Backup" reason:error.localizedDescription userInfo:nil];
 @try {
  info[@"NSHighResolutionCapable"]=@(enabled);NSData *data=[NSPropertyListSerialization dataWithPropertyList:info format:NSPropertyListXMLFormat_v1_0 options:0 error:&error];
  if(!data||![data writeToFile:plist options:NSDataWritingAtomic error:&error])@throw [NSException exceptionWithName:@"Setup" reason:error.localizedDescription userInfo:nil];
  command(@"/usr/bin/codesign",@[@"--force",@"--sign",@"-",@"--timestamp=none",game]);
  command(@"/usr/bin/codesign",@[@"--verify",@"--strict",game]);
  if([[[NSDictionary dictionaryWithContentsOfFile:plist] objectForKey:@"NSHighResolutionCapable"] boolValue]!=enabled)@throw [NSException exceptionWithName:@"Setup" reason:@"The Retina setting did not save." userInfo:nil];
 } @catch(NSException *failure) {
  for(NSArray *pair in @[@[@"Info.plist",plist],@[@"Executable",exe]]){[fm removeItemAtPath:pair[1] error:nil];[fm copyItemAtPath:[backup stringByAppendingPathComponent:pair[0]] toPath:pair[1] error:nil];}
  [fm removeItemAtPath:signature error:nil];if(hadSignature)[fm copyItemAtPath:[backup stringByAppendingPathComponent:@"_CodeSignature"] toPath:signature error:nil];
  @throw failure;
 }
}
int main(int argc, const char **argv){@autoreleasepool{@try{
 NSString *game=[NSHomeDirectory() stringByAppendingPathComponent:@"Library/Application Support/Steam/steamapps/common/Geometry Dash/Geometry Dash.app"];
 if([NSRunningApplication runningApplicationsWithBundleIdentifier:@"com.robtop.geometrydashmac"].count){run(@[@"-a",game]);return 0;}
 if(![NSRunningApplication runningApplicationsWithBundleIdentifier:@"com.valvesoftware.steam"].count){
  run(@[@"-a",@"Steam"]);
  for(int attempt=0;attempt<45;attempt++){if([NSRunningApplication runningApplicationsWithBundleIdentifier:@"com.valvesoftware.steam"].count){sleep(5);break;}sleep(1);}
  if(![NSRunningApplication runningApplicationsWithBundleIdentifier:@"com.valvesoftware.steam"].count) @throw [NSException exceptionWithName:@"Steam" reason:@"Steam did not start. Open Steam and try again." userInfo:nil];
 }
 BOOL metal=argc<=3||strcmp(argv[3],"opengl")!=0;
 BOOL retina=argc>4&&strcmp(argv[4],"1")==0;
 BOOL vsync=argc>5&&strcmp(argv[5],"1")==0;
 NSInteger maxFPS=argc>6?[[NSString stringWithUTF8String:argv[6]] integerValue]:120;
 if(argc>6)GDFPSApply(GDFPSPath(),[NSHomeDirectory() stringByAppendingPathComponent:@"Library/Application Support/GD MetalFX Control/Settings backups"],vsync,maxFPS);
 retinaSetting(game,retina);
 NSString *resources=[[NSString stringWithUTF8String:argv[0]] stringByDeletingLastPathComponent];
 NSString *logs=[NSHomeDirectory() stringByAppendingPathComponent:@"Library/Logs/Geometry Dash MetalFX"];
 [NSFileManager.defaultManager createDirectoryAtPath:logs withIntermediateDirectories:YES attributes:nil error:nil];
 NSString *stamp=[NSString stringWithFormat:@"%.0f",NSDate.date.timeIntervalSince1970];NSString *log=[logs stringByAppendingPathComponent:[stamp stringByAppendingString:@".log"]];
 NSDictionary *state=@{@"renderer":metal?@"GLMetal":@"Apple OpenGL",@"retina":@(retina),@"vsync":@(vsync),@"maxFPS":@(maxFPS),@"scale":metal&&argc>1?@(atof(argv[1])):@1,@"framegen":metal&&argc>2?@(atoi(argv[2])):@1};
 NSData *stateData=[NSJSONSerialization dataWithJSONObject:state options:NSJSONWritingPrettyPrinted error:nil];[stateData writeToFile:[log stringByAppendingString:@".launch.json"] atomically:YES];
 NSMutableArray *args=[NSMutableArray arrayWithArray:@[@"-a",game,@"--stdout",[log stringByAppendingString:@".stdout"],@"--stderr",log,@"--env",@"SteamAppId=322170",@"--env",@"SteamGameId=322170",@"--env",@"CURL_SSL_BACKEND=openssl",@"--env",[NSString stringWithFormat:@"GD_RETINA=%d",retina]]];
 if(metal){[args addObjectsFromArray:@[@"--env",@"GLMETAL_DEBUG=1",@"--env",[NSString stringWithFormat:@"GD_FRAMEGEN_FACTOR=%s",argc>2?argv[2]:"1"],@"--env",[NSString stringWithFormat:@"GD_METALFX_SCALE=%s",argc>1?argv[1]:"2"],@"--env",[@"GLMETAL_PATH=" stringByAppendingString:[resources stringByAppendingPathComponent:@"libGLMetal.dylib"]],@"--env",[@"DYLD_INSERT_LIBRARIES=" stringByAppendingString:[NSString stringWithFormat:@"%@:%@",[resources stringByAppendingPathComponent:@"libGLMetalInject.dylib"],[resources stringByAppendingPathComponent:@"libGDRetinaControl.dylib"]]]]];}
 else [args addObjectsFromArray:@[@"--env",[@"DYLD_INSERT_LIBRARIES=" stringByAppendingString:[resources stringByAppendingPathComponent:@"libGDRetinaControl.dylib"]],@"--env",@"GLMETAL_PATH=",@"--env",@"GD_FRAMEGEN_FACTOR=1",@"--env",@"GD_METALFX_SCALE=1"]];
 // GD's Mac loop follows CVDisplayLink even with its saved VSync flag off.
 // Use a separate callback clock only when interpolation and VSync are off.
 if(argc>6&&!vsync&&(!metal||argc<=2||atoi(argv[2])==1)){
  NSUInteger index=[args indexOfObjectPassingTest:^BOOL(id value,NSUInteger i,BOOL *stop){return [value isKindOfClass:NSString.class]&&[value hasPrefix:@"DYLD_INSERT_LIBRARIES="]; }];
  if(index!=NSNotFound)args[index]=[args[index] stringByAppendingFormat:@":%@",[resources stringByAppendingPathComponent:@"libGDFramePacer.dylib"]];
  [args addObjectsFromArray:@[@"--env",[NSString stringWithFormat:@"GD_TARGET_FPS=%ld",(long)maxFPS]]];
  [args addObjectsFromArray:@[@"--env",[@"GD_TIMING_PATH=" stringByAppendingString:[NSHomeDirectory() stringByAppendingPathComponent:@"Library/Application Support/GD MetalFX Control/timing.json"]]]];
 }
 [args addObjectsFromArray:@[@"--args",@"-AppleMagnifiedMode",retina?@"NO":@"YES"]];
 run(args);
 return 0;
 }@catch(NSException *e){fprintf(stderr,"%s\n",(e.reason?:@"Unknown launch error").UTF8String);return 1;}}}
