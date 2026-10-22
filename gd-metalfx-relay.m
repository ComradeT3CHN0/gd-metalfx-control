#import <Cocoa/Cocoa.h>
int main(void){@autoreleasepool{
 NSString *controller=[NSHomeDirectory() stringByAppendingPathComponent:@"Applications/GD MetalFX Control.app"];
 NSTask *task=[NSTask new];task.executableURL=[NSURL fileURLWithPath:@"/usr/bin/open"];task.arguments=@[@"-a",controller,@"gdmetalfx://launch"];
 NSError *error=nil;if(![task launchAndReturnError:&error]){[NSApplication sharedApplication];NSAlert *alert=[NSAlert new];alert.messageText=@"Could not open GD MetalFX Control";alert.informativeText=error.localizedDescription;[alert runModal];return 1;}[task waitUntilExit];return task.terminationStatus;
}}
