#include <CoreVideo/CoreVideo.h>
#include <stdatomic.h>
#include <unistd.h>
#include <stdio.h>
#include <assert.h>
#include <stdlib.h>
static void timing(const char *path,int fps){char temporary[4096];snprintf(temporary,sizeof(temporary),"%s.new",path);FILE *f=fopen(temporary,"w");assert(f);fprintf(f,"{\"vsync\":false,\"maxFPS\":%d}",fps);assert(fclose(f)==0);assert(rename(temporary,path)==0);}
static atomic_int count,errors;static uint64_t last;
static CVReturn frame(CVDisplayLinkRef d,const CVTimeStamp*n,const CVTimeStamp*out,CVOptionFlags f,CVOptionFlags*o,void*u){if(n->hostTime<=last||out->hostTime<=n->hostTime||out->videoTime<=n->videoTime||n->videoTimeScale!=1000000000)atomic_fetch_add(&errors,1);last=n->hostTime;atomic_fetch_add(&count,1);return kCVReturnSuccess;}
int main(void){CVDisplayLinkRef d;assert(CVDisplayLinkCreateWithActiveCGDisplays(&d)==kCVReturnSuccess);assert(CVDisplayLinkSetOutputCallback(d,frame,0)==kCVReturnSuccess);assert(CVDisplayLinkStart(d)==kCVReturnSuccess);assert(CVDisplayLinkIsRunning(d));usleep(600000);assert(CVDisplayLinkStop(d)==kCVReturnSuccess);assert(!CVDisplayLinkIsRunning(d));int first=count;usleep(30000);assert(count==first);assert(first>240&&first<320);assert(errors==0);assert(CVDisplayLinkStart(d)==kCVReturnSuccess);usleep(100000);assert(CVDisplayLinkStop(d)==kCVReturnSuccess);assert(count>first+35);const char *path=getenv("GD_TIMING_PATH");if(path){
 assert(CVDisplayLinkStart(d)==kCVReturnSuccess);
 timing(path,60);usleep(350000);int before=count;usleep(600000);int slow=count-before;assert(slow>=32&&slow<=40);
 timing(path,240);usleep(350000);before=count;usleep(600000);int fast=count-before;assert(fast>=130&&fast<=155);
 assert(CVDisplayLinkStop(d)==kCVReturnSuccess);assert(errors==0);printf("PASS: live caps 60 -> %d callbacks, 240 -> %d callbacks in 0.6 seconds\n",slow,fast);
 }CVDisplayLinkRelease(d);printf("PASS: %d callbacks in 0.6 seconds; monotonic timestamps; stop and restart verified\n",first);}
