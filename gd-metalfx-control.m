#import <Cocoa/Cocoa.h>
@interface FXController : NSObject <NSApplicationDelegate>
@property BOOL pendingLaunch;
@property(strong) NSWindow *window;
@property(strong) NSPopUpButton *mode,*framegen,*backend;
@property(strong) NSButton *retina;
@property(strong) NSTextField *status;
@property(strong) NSMutableDictionary<NSString*,NSControl*> *effects;
@property(strong) NSMutableDictionary<NSString*,NSTextField*> *values;
@property(strong) NSTimer *writeTimer;
@end
static NSTextField *label(NSString *text,NSRect frame,CGFloat size){NSTextField*v=[NSTextField wrappingLabelWithString:text];v.frame=frame;v.font=[NSFont systemFontOfSize:size];return v;}
static NSString *effectsPath(void){return [NSHomeDirectory() stringByAppendingPathComponent:@"Library/Application Support/GD MetalFX Control/effects.json"];}
@implementation FXController
- (NSView*)pane:(NSString*)title tabs:(NSTabView*)tabs {
 NSTabViewItem*item=[[NSTabViewItem alloc]initWithIdentifier:title];item.label=title;NSView*v=[[NSView alloc]initWithFrame:NSMakeRect(0,0,510,360)];item.view=v;[tabs addTabViewItem:item];return v;
}
- (void)check:(NSString*)title key:(NSString*)key view:(NSView*)v y:(CGFloat)y {
 NSButton*b=[NSButton checkboxWithTitle:title target:self action:@selector(effectsChanged:)];b.frame=NSMakeRect(20,y,465,26);b.state=[NSUserDefaults.standardUserDefaults boolForKey:key]?NSControlStateValueOn:NSControlStateValueOff;self.effects[key]=b;[v addSubview:b];
}
- (void)slider:(NSString*)title key:(NSString*)key low:(double)low high:(double)high view:(NSView*)v y:(CGFloat)y {
 [v addSubview:label(title,NSMakeRect(20,y+25,390,22),14)];NSTextField*value=label(@"",NSMakeRect(435,y+25,55,22),13);value.alignment=NSTextAlignmentRight;self.values[key]=value;[v addSubview:value];
 NSSlider*s=[NSSlider sliderWithValue:[NSUserDefaults.standardUserDefaults doubleForKey:key] minValue:low maxValue:high target:self action:@selector(effectsChanged:)];s.frame=NSMakeRect(20,y,470,25);s.continuous=YES;self.effects[key]=s;[v addSubview:s];
}
- (void)applicationDidFinishLaunching:(NSNotification*)n {
 NSUserDefaults*p=NSUserDefaults.standardUserDefaults;[p registerDefaults:@{@"backendMode":@0,@"retinaEnabled":@NO,@"scaleMode":@2,@"bloomEnabled":@NO,@"bloomStrength":@0.5,@"bloomThreshold":@0.7,@"bloomRadius":@5,@"crtEnabled":@NO,@"scanlines":@0.2,@"curvature":@0.08,@"rgbMask":@0.12,@"colorEnabled":@NO,@"saturation":@1,@"contrast":@1,@"sharpen":@0,@"grayscale":@NO}];
 self.effects=[NSMutableDictionary new];self.values=[NSMutableDictionary new];
 NSMenu*menu=[NSMenu new];NSMenuItem*item=[NSMenuItem new];[menu addItem:item];NSMenu*sub=[NSMenu new];[sub addItemWithTitle:@"Quit GD MetalFX Control" action:@selector(terminate:) keyEquivalent:@"q"];item.submenu=sub;NSApp.mainMenu=menu;
 self.window=[[NSWindow alloc]initWithContentRect:NSMakeRect(0,0,580,650) styleMask:NSWindowStyleMaskTitled|NSWindowStyleMaskClosable|NSWindowStyleMaskMiniaturizable backing:NSBackingStoreBuffered defer:NO];self.window.title=@"GD MetalFX Control";[self.window center];NSView*root=self.window.contentView;
 [root addSubview:label(@"Geometry Dash + MetalFX",NSMakeRect(26,595,528,32),24)];[root addSubview:label(@"Rendering and live visual effects",NSMakeRect(26,564,528,24),14)];
 NSTabView*tabs=[[NSTabView alloc]initWithFrame:NSMakeRect(24,171,532,384)];[root addSubview:tabs];
 NSView*v=[self pane:@"Display" tabs:tabs];
 [v addSubview:label(@"Graphics renderer",NSMakeRect(20,304,155,24),14)];self.backend=[[NSPopUpButton alloc]initWithFrame:NSMakeRect(180,300,310,30) pullsDown:NO];[self.backend addItemsWithTitles:@[@"Metal via GLMetal",@"Apple OpenGL"]];[self.backend selectItemAtIndex:MAX(0,MIN(1,[p integerForKey:@"backendMode"]))];self.backend.target=self;self.backend.action=@selector(save:);[v addSubview:self.backend];
 [v addSubview:label(@"GLMetal translates GD’s OpenGL graphics to Metal. Apple OpenGL uses the original renderer. MetalFX, frame generation, and these visual effects require GLMetal.",NSMakeRect(20,207,470,77),13)];
 self.retina=[NSButton checkboxWithTitle:@"Enable Retina rendering" target:self action:@selector(save:)];self.retina.frame=NSMakeRect(20,154,470,28);self.retina.state=[p boolForKey:@"retinaEnabled"]?NSControlStateValueOn:NSControlStateValueOff;[v addSubview:self.retina];
 [v addSubview:label(@"Retina renders at the display’s full pixel density. It can substantially increase GPU work. Both display settings apply on the next game launch.",NSMakeRect(20,63,470,77),13)];
 v=[self pane:@"Rendering" tabs:tabs];
 [v addSubview:label(@"Output scaling",NSMakeRect(20,306,150,24),14)];self.mode=[[NSPopUpButton alloc]initWithFrame:NSMakeRect(180,301,310,30) pullsDown:NO];[self.mode addItemsWithTitles:@[@"Off",@"MetalFX · 1.5×",@"MetalFX · 2×",@"Extreme · 10× requested",@"Extreme · 20× requested"]];[self.mode selectItemAtIndex:MAX(0,MIN(4,[p integerForKey:@"scaleMode"]))];self.mode.target=self;self.mode.action=@selector(save:);[v addSubview:self.mode];
 [v addSubview:label(@"Extreme scaling can be very slow. Output is limited to 16,384 pixels per side.",NSMakeRect(20,236,470,50),13)];
 [v addSubview:label(@"Frame generation",NSMakeRect(20,185,155,24),14)];self.framegen=[[NSPopUpButton alloc]initWithFrame:NSMakeRect(180,180,310,30) pullsDown:NO];[self.framegen addItemsWithTitles:@[@"Off",@"2× · Motion interpolation",@"Extreme · 4× interpolation"]];[self.framegen selectItemAtIndex:MAX(0,MIN(2,[p integerForKey:@"framegenMode"]))];self.framegen.target=self;self.framegen.action=@selector(save:);[v addSubview:self.framegen];
 [v addSubview:label(@"Custom interpolation, separate from MetalFX. At 120 Hz: 2× aims for 60 rendered + 60 generated frames; 4× for 30 + 90. Can add ghosting and input lag.",NSMakeRect(20,77,470,83),13)];
 [v addSubview:label(@"Rendering changes apply on the next game launch.",NSMakeRect(20,20,470,35),12)];
 v=[self pane:@"Glow" tabs:tabs];[self check:@"Enable neon bloom" key:@"bloomEnabled" view:v y:310];[v addSubview:label(@"Soft glow around bright objects. These controls apply live.",NSMakeRect(20,266,470,35),13)];
 [self slider:@"Glow strength" key:@"bloomStrength" low:0 high:2.5 view:v y:212];[self slider:@"Brightness threshold" key:@"bloomThreshold" low:0.3 high:1 view:v y:140];[self slider:@"Glow radius" key:@"bloomRadius" low:1 high:16 view:v y:68];
 v=[self pane:@"CRT" tabs:tabs];[self check:@"Enable CRT screen" key:@"crtEnabled" view:v y:310];[v addSubview:label(@"Retro scanlines, curved screen edges, and an RGB mask.",NSMakeRect(20,266,470,35),13)];
 [self slider:@"Scanline strength" key:@"scanlines" low:0 high:0.8 view:v y:212];[self slider:@"Screen curvature" key:@"curvature" low:0 high:0.25 view:v y:140];[self slider:@"RGB mask strength" key:@"rgbMask" low:0 high:0.6 view:v y:68];
 v=[self pane:@"Color" tabs:tabs];[self check:@"Enable color controls" key:@"colorEnabled" view:v y:310];
 [self slider:@"Saturation" key:@"saturation" low:0 high:2 view:v y:242];[self slider:@"Contrast" key:@"contrast" low:0.5 high:1.5 view:v y:170];[self slider:@"Sharpening" key:@"sharpen" low:0 high:1 view:v y:98];[self check:@"Grayscale" key:@"grayscale" view:v y:38];
 NSButton*launch=[NSButton buttonWithTitle:@"Launch Geometry Dash" target:self action:@selector(launch:)];launch.frame=NSMakeRect(26,115,310,34);launch.bezelStyle=NSBezelStyleRounded;[root addSubview:launch];NSButton*logs=[NSButton buttonWithTitle:@"Show logs" target:self action:@selector(logs:)];logs.frame=NSMakeRect(350,115,205,34);logs.bezelStyle=NSBezelStyleRounded;[root addSubview:logs];
 self.status=label(@"Ready. Visual effects apply live; rendering changes need a restart.",NSMakeRect(26,20,528,80),12);self.status.textColor=NSColor.secondaryLabelColor;[root addSubview:self.status];
 [self updateAvailability];[self updateValues];[self writeEffects:nil];[self.window makeKeyAndOrderFront:nil];[NSApp activateIgnoringOtherApps:YES];[NSTimer scheduledTimerWithTimeInterval:3 target:self selector:@selector(refresh:) userInfo:nil repeats:YES];if(self.pendingLaunch)[self launch:nil];
}
- (void)updateValues {for(NSString*key in self.values)self.values[key].stringValue=[NSString stringWithFormat:[key isEqualToString:@"bloomRadius"]?@"%.0f":@"%.2f",self.effects[key].doubleValue];}
- (void)effectsChanged:(id)sender {
 for(NSString*key in self.effects){NSControl*c=self.effects[key];[NSUserDefaults.standardUserDefaults setObject:[c isKindOfClass:NSButton.class]?@(((NSButton*)c).state==NSControlStateValueOn):@(c.doubleValue) forKey:key];}
 [self updateValues];[self.writeTimer invalidate];self.writeTimer=[NSTimer scheduledTimerWithTimeInterval:0.08 target:self selector:@selector(writeEffects:) userInfo:nil repeats:NO];self.status.stringValue=@"Effects saved. They apply live to GD started with this version.";
}
- (void)writeEffects:(id)sender {
 NSMutableDictionary*d=[NSMutableDictionary new];for(NSString*key in self.effects){NSControl*c=self.effects[key];d[key]=[c isKindOfClass:NSButton.class]?@(((NSButton*)c).state==NSControlStateValueOn):@(c.doubleValue);}
 NSString*path=effectsPath();NSError*error=nil;[NSFileManager.defaultManager createDirectoryAtPath:path.stringByDeletingLastPathComponent withIntermediateDirectories:YES attributes:nil error:&error];NSData*data=[NSJSONSerialization dataWithJSONObject:d options:NSJSONWritingPrettyPrinted error:&error];if(!data||![data writeToFile:path options:NSDataWritingAtomic error:&error])self.status.stringValue=[@"Could not save effects: " stringByAppendingString:error.localizedDescription?:@"Unknown error"];
}
- (void)application:(NSApplication*)app openURLs:(NSArray<NSURL*>*)urls {for(NSURL*url in urls)if([url.scheme isEqualToString:@"gdmetalfx"]&&[url.host isEqualToString:@"launch"]){[self.window makeKeyAndOrderFront:nil];[NSApp activateIgnoringOtherApps:YES];if(self.mode)[self launch:nil];else self.pendingLaunch=YES;}}
- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication*)app{return YES;}
- (void)applicationWillTerminate:(NSNotification*)n{[self writeEffects:nil];}
- (void)updateAvailability {
 BOOL metal=self.backend.indexOfSelectedItem==0;self.mode.enabled=metal;self.framegen.enabled=metal;
 for(NSControl *control in self.effects.allValues)control.enabled=metal;
}
- (void)save:(id)sender {
 NSUserDefaults *p=NSUserDefaults.standardUserDefaults;
 [p setInteger:self.mode.indexOfSelectedItem forKey:@"scaleMode"];[p setInteger:self.framegen.indexOfSelectedItem forKey:@"framegenMode"];
 [p setInteger:self.backend.indexOfSelectedItem forKey:@"backendMode"];[p setBool:self.retina.state==NSControlStateValueOn forKey:@"retinaEnabled"];
 [self updateAvailability];self.status.stringValue=@"Saved. Quit GD normally and launch here to apply display or rendering changes.";
}
- (void)launch:(id)sender {
 [self save:nil];[self writeEffects:nil];if([NSRunningApplication runningApplicationsWithBundleIdentifier:@"com.robtop.geometrydashmac"].count){self.status.stringValue=@"GD is running. Effects update live; restart GD to change rendering modes.";return;}
 NSArray*scales=@[@"1",@"1.5",@"2",@"10",@"20"];NSTask*task=[NSTask new];task.executableURL=[NSBundle.mainBundle URLForResource:@"launch-game" withExtension:nil];task.arguments=@[scales[self.mode.indexOfSelectedItem],@[@"1",@"2",@"4"][self.framegen.indexOfSelectedItem],self.backend.indexOfSelectedItem==0?@"metal":@"opengl",self.retina.state==NSControlStateValueOn?@"1":@"0"];NSError*error=nil;if(![task launchAndReturnError:&error])self.status.stringValue=error.localizedDescription;else self.status.stringValue=@"Starting Geometry Dash. Steam will open if needed…";
}
- (void)logs:(id)sender{NSString*path=[NSHomeDirectory() stringByAppendingPathComponent:@"Library/Logs/Geometry Dash MetalFX"];[NSFileManager.defaultManager createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:nil];[NSWorkspace.sharedWorkspace openURL:[NSURL fileURLWithPath:path]];}
- (void)refresh:(id)sender {
 if(![NSRunningApplication runningApplicationsWithBundleIdentifier:@"com.robtop.geometrydashmac"].count)return;NSString*folder=[NSHomeDirectory() stringByAppendingPathComponent:@"Library/Logs/Geometry Dash MetalFX"];NSArray*files=[[NSFileManager.defaultManager contentsOfDirectoryAtPath:folder error:nil]sortedArrayUsingSelector:@selector(compare:)];
 for(NSString*name in files.reverseObjectEnumerator){if(![name hasSuffix:@".log"])continue;NSString *statePath=[[folder stringByAppendingPathComponent:name] stringByAppendingString:@".launch.json"];NSData *stateData=[NSData dataWithContentsOfFile:statePath];NSDictionary *state=stateData?[NSJSONSerialization JSONObjectWithData:stateData options:0 error:nil]:nil;
 if([state[@"renderer"] isEqualToString:@"Apple OpenGL"]){self.status.stringValue=[NSString stringWithFormat:@"GD is running with Apple OpenGL. Retina is %@. MetalFX and added effects are inactive.",[state[@"retina"] boolValue]?@"on":@"off"];break;}
NSFileHandle*file=[NSFileHandle fileHandleForReadingAtPath:[folder stringByAppendingPathComponent:name]];unsigned long long length=[file seekToEndOfFile];[file seekToFileOffset:length>16384?length-16384:0];NSString*text=[[NSString alloc]initWithData:[file readDataToEndOfFile] encoding:NSUTF8StringEncoding];[file closeFile];if(!text.length)break;NSMutableArray*messages=[NSMutableArray new];for(NSString*prefix in @[@"gd-metalfx:",@"gd-framegen:",@"gd-effects:"]){NSRange r=[text rangeOfString:prefix options:NSBackwardsSearch];if(r.location!=NSNotFound)[messages addObject:[[[text substringFromIndex:r.location]componentsSeparatedByString:@"\n"]firstObject]];}if(messages.count)self.status.stringValue=[messages componentsJoinedByString:@"\n"];break;}
}
@end
int main(void){@autoreleasepool{NSApplication*app=NSApplication.sharedApplication;app.activationPolicy=NSApplicationActivationPolicyRegular;FXController*controller=[FXController new];app.delegate=controller;[app run];}}
