#import <Cocoa/Cocoa.h>
#import <objc/runtime.h>
#include <stdlib.h>
static BOOL retinaMode;
static void(*originalSetter)(id,SEL,BOOL);
static BOOL bestResolution(id self,SEL cmd){return retinaMode;}
static void setBestResolution(id self,SEL cmd,BOOL enabled){originalSetter(self,cmd,retinaMode);}
__attribute__((constructor))static void initializeRetina(void){@autoreleasepool{
 const char*value=getenv("GD_RETINA");if(!value)return;retinaMode=atoi(value)!=0;
 Class cls=NSView.class;Method get=class_getInstanceMethod(cls,@selector(wantsBestResolutionOpenGLSurface));Method set=class_getInstanceMethod(cls,@selector(setWantsBestResolutionOpenGLSurface:));
 if(get&&set){unsigned int count=0;Class *classes=objc_copyClassList(&count);for(int i=0;i<count;i++){Class candidate=classes[i],parent=candidate;while(parent&&parent!=NSView.class)parent=class_getSuperclass(parent);if(!parent)continue;Method own=class_getInstanceMethod(candidate,@selector(wantsBestResolutionOpenGLSurface));if(own&&method_getImplementation(own)!=(IMP)bestResolution){class_replaceMethod(candidate,@selector(wantsBestResolutionOpenGLSurface),(IMP)bestResolution,method_getTypeEncoding(own));fprintf(stderr,"gd-retina: configured %s\n",class_getName(candidate));}}free(classes);originalSetter=(void*)method_getImplementation(set);method_setImplementation(get,(IMP)bestResolution);method_setImplementation(set,(IMP)setBestResolution);fprintf(stderr,"gd-retina: requested high-resolution surface %s\n",retinaMode?"on":"off");}
}}
