#import <Cocoa/Cocoa.h>
#import <QuartzCore/CAMetalLayer.h>
#import <CoreVideo/CoreVideo.h>
#import <objc/runtime.h>
#include <mach/mach_time.h>
#include <pthread.h>
#include <stdatomic.h>
#include <stdlib.h>
#include <stdio.h>
#include <math.h>

/* Per-process, opt-in pacing of GD's existing display callback. No game-code
   offsets or physics functions are modified. Inactive without GD_TARGET_FPS. */
struct Link { CVDisplayLinkRef ref; CVDisplayLinkOutputCallback callback; void *user;
 pthread_t thread; bool joinable; atomic_bool running,stop; struct Link *next; };
static struct Link *links;static pthread_mutex_t lock=PTHREAD_MUTEX_INITIALIZER;
static double target;static mach_timebase_info_data_t timebase;
static NSString *timingPath;
static struct Link *find(CVDisplayLinkRef ref) { for(struct Link *s=links;s;s=s->next)if(s->ref==ref)return s;return NULL; }
static int64_t nanos(uint64_t ticks){return (int64_t)((long double)ticks*timebase.numer/timebase.denom);}
static void *worker(void *opaque){struct Link *s=opaque;pthread_setname_np("GD frame pacer");
 double fps=target;uint64_t step=(uint64_t)(1e9/fps*timebase.denom/timebase.numer),next=mach_absolute_time(),checked=0;
 fprintf(stderr,"gd-frame-pacer: running at %.0f FPS\n",target);
 while(!atomic_load(&s->stop)){
  mach_wait_until(next);if(atomic_load(&s->stop))break;
  uint64_t now=mach_absolute_time();CVTimeStamp input={0},output={0};input.version=0;input.videoTimeScale=1000000000;input.videoTime=nanos(now);input.hostTime=now;input.rateScalar=1;input.videoRefreshPeriod=(int64_t)(1e9/target);input.flags=kCVTimeStampVideoTimeValid|kCVTimeStampHostTimeValid|kCVTimeStampVideoRefreshPeriodValid|kCVTimeStampRateScalarValid;
  if(timingPath&&nanos(now-checked)>250000000){checked=now;@autoreleasepool{
   NSData *data=[NSData dataWithContentsOfFile:timingPath];NSDictionary *settings=data?[NSJSONSerialization JSONObjectWithData:data options:0 error:nil]:nil;
   if([settings isKindOfClass:NSDictionary.class]&&[settings[@"vsync"] isEqual:@NO]){
    id number=settings[@"maxFPS"];double requested=[number isKindOfClass:NSNumber.class]?[number doubleValue]:0;
    if(isfinite(requested)&&requested>=1&&requested<=10000&&requested==floor(requested)&&requested!=fps){fps=requested;step=(uint64_t)(1e9/fps*timebase.denom/timebase.numer);fprintf(stderr,"gd-frame-pacer: live target=%.0f FPS\n",fps);}
   }
  }}
  input.videoRefreshPeriod=(int64_t)(1e9/fps);
  output=input;output.hostTime=now+step;output.videoTime=nanos(now+step);CVOptionFlags flags=0;
  @autoreleasepool{s->callback(s->ref,&input,&output,0,&flags,s->user);}
  next+=step;uint64_t finished=mach_absolute_time();if(next<finished)next=finished;
 }
 atomic_store(&s->running,false);return NULL;
}
static CVReturn set_callback(CVDisplayLinkRef ref,CVDisplayLinkOutputCallback callback,void *user){
 if(!target)return CVDisplayLinkSetOutputCallback(ref,callback,user);
 if(!ref||!callback)return kCVReturnInvalidArgument;
 pthread_mutex_lock(&lock);struct Link *s=find(ref);
 if(!s){s=calloc(1,sizeof(*s));s->ref=ref;s->next=links;links=s;}
 if(atomic_load(&s->running)){pthread_mutex_unlock(&lock);return kCVReturnError;}
 s->callback=callback;s->user=user;pthread_mutex_unlock(&lock);return kCVReturnSuccess;
}
static CVReturn start_link(CVDisplayLinkRef ref){
 pthread_mutex_lock(&lock);struct Link *s=target?find(ref):NULL;
 if(!s){pthread_mutex_unlock(&lock);return CVDisplayLinkStart(ref);}
 if(atomic_load(&s->running)){pthread_mutex_unlock(&lock);return kCVReturnSuccess;}
 if(s->joinable){pthread_join(s->thread,NULL);s->joinable=false;}
 atomic_store(&s->stop,false);atomic_store(&s->running,true);
 int error=pthread_create(&s->thread,NULL,worker,s);s->joinable=!error;if(error)atomic_store(&s->running,false);pthread_mutex_unlock(&lock);return error?kCVReturnError:kCVReturnSuccess;
}
static CVReturn stop_link(CVDisplayLinkRef ref){
 pthread_mutex_lock(&lock);struct Link *s=target?find(ref):NULL;
 if(!s){pthread_mutex_unlock(&lock);return CVDisplayLinkStop(ref);}
 atomic_store(&s->stop,true);bool join=s->joinable&&!pthread_equal(pthread_self(),s->thread);pthread_t thread=s->thread;if(join)s->joinable=false;pthread_mutex_unlock(&lock);
 if(join)pthread_join(thread,NULL);return kCVReturnSuccess;
}
static Boolean is_running(CVDisplayLinkRef ref){pthread_mutex_lock(&lock);struct Link*s=target?find(ref):NULL;Boolean running=s?atomic_load(&s->running):false;pthread_mutex_unlock(&lock);return s?running:CVDisplayLinkIsRunning(ref);}
static void release_link(CVDisplayLinkRef ref){if(target){stop_link(ref);pthread_mutex_lock(&lock);struct Link*s=find(ref);if(s)s->ref=NULL;pthread_mutex_unlock(&lock);}CVDisplayLinkRelease(ref);}
static IMP original_sync;
static void no_sync(id self,SEL selector,BOOL enabled){((void(*)(id,SEL,BOOL))original_sync)(self,selector,NO);fprintf(stderr,"gd-frame-pacer: layer sync requested=%d actual=%d\n",enabled,[(CAMetalLayer*)self displaySyncEnabled]);}
static IMP original_drawable;
static double presentationInterval;
static const char nextPresentationKey;
/* WindowServer may hold all drawables until the next display refresh even
   with displaySyncEnabled=NO. Keep GD's simulation/render loop independent:
   GLMetal already handles a nil drawable by submitting its offscreen work.
   Only acquire a screen image when the display can show another frame. */
static id paced_drawable(CAMetalLayer *self,SEL selector){
 double now=CACurrentMediaTime();NSNumber *due=objc_getAssociatedObject(self,&nextPresentationKey);
 if(due&&now<due.doubleValue)return nil;
 id drawable=((id(*)(id,SEL))original_drawable)(self,selector);
 if(drawable){double next=due?due.doubleValue+presentationInterval:now+presentationInterval;double finished=CACurrentMediaTime();if(next<finished)next=finished+presentationInterval;objc_setAssociatedObject(self,&nextPresentationKey,@(next),OBJC_ASSOCIATION_RETAIN_NONATOMIC);}
 return drawable;
}
__attribute__((constructor))static void initialize(void){
 const char *setting=getenv("GD_TARGET_FPS");if(!setting)return;char *end;double value=strtod(setting,&end);if(*end||!isfinite(value)||value<1||value>10000)return;target=value;mach_timebase_info(&timebase);
 const char *live=getenv("GD_TIMING_PATH");if(live)timingPath=[[NSString alloc]initWithUTF8String:live];
 Class cls=CAMetalLayer.class;SEL sel=@selector(setDisplaySyncEnabled:);Method method=class_getInstanceMethod(cls,sel);original_sync=method_getImplementation(method);
 if(!class_addMethod(cls,sel,(IMP)no_sync,method_getTypeEncoding(method)))method_setImplementation(method,(IMP)no_sync);
 @autoreleasepool{NSInteger refresh=NSScreen.mainScreen.maximumFramesPerSecond;presentationInterval=1.0/(refresh>=30&&refresh<=1000?refresh:120);}
 sel=@selector(nextDrawable);method=class_getInstanceMethod(cls,sel);original_drawable=method_getImplementation(method);
 if(!class_addMethod(cls,sel,(IMP)paced_drawable,method_getTypeEncoding(method)))method_setImplementation(method,(IMP)paced_drawable);
 fprintf(stderr,"gd-frame-pacer: target=%.0f, Metal display sync disabled\n",target);
}
__attribute__((used,section("__DATA,__interpose")))static struct {const void *replacement,*original;} interposers[]={
 {set_callback,CVDisplayLinkSetOutputCallback},{start_link,CVDisplayLinkStart},{stop_link,CVDisplayLinkStop},{is_running,CVDisplayLinkIsRunning},{release_link,CVDisplayLinkRelease}};
