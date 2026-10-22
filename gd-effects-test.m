#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#import "gd_effects.h"
#include <stdio.h>
#include <unistd.h>
int main(){@autoreleasepool{
 NSString*path=[NSFileManager.defaultManager.currentDirectoryPath stringByAppendingPathComponent:@"work/effects-test-config.json"];setenv("GD_EFFECTS_CONFIG",path.UTF8String,1);
 id<MTLDevice>d=MTLCreateSystemDefaultDevice();id<MTLCommandQueue>q=[d newCommandQueue];int w=128,h=96;unsigned char input[128*96*4];for(int y=0;y<h;y++)for(int x=0;x<w;x++){int i=(y*w+x)*4;input[i]=10;input[i+1]=20;input[i+2]=40;input[i+3]=255;if(x>=24&&x<40&&y>=20&&y<32){input[i]=200;input[i+1]=70;input[i+2]=30;}if(x>=56&&x<72&&y>=40&&y<56)input[i]=input[i+1]=input[i+2]=255;}
 MTLTextureDescriptor*td=[MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA8Unorm width:w height:h mipmapped:NO];td.usage=MTLTextureUsageShaderRead;td.storageMode=MTLStorageModeShared;id<MTLTexture>src=[d newTextureWithDescriptor:td];[src replaceRegion:MTLRegionMake2D(0,0,w,h) mipmapLevel:0 withBytes:input bytesPerRow:w*4];
 NSArray*configs=@[@{},@{@"colorEnabled":@YES,@"grayscale":@YES},@{@"bloomEnabled":@YES,@"bloomStrength":@1,@"bloomRadius":@8},@{@"crtEnabled":@YES,@"curvature":@0.2},@{@"colorEnabled":@YES,@"saturation":@2,@"contrast":@1.2,@"sharpen":@0.6},@{@"bloomEnabled":@YES,@"crtEnabled":@YES,@"colorEnabled":@YES,@"grayscale":@YES}];
 int n=0;for(NSDictionary*config in configs){[[NSJSONSerialization dataWithJSONObject:config options:0 error:nil]writeToFile:path atomically:YES];GDEffects*fx=[[GDEffects alloc]initWithDevice:d];id<MTLCommandBuffer>cmd=[q commandBuffer];id<MTLTexture>out=[fx processTexture:src commandBuffer:cmd];id<MTLBuffer>buffer=[d newBufferWithLength:sizeof(input) options:MTLResourceStorageModeShared];id<MTLBlitCommandEncoder>blit=[cmd blitCommandEncoder];[blit copyFromTexture:out sourceSlice:0 sourceLevel:0 sourceOrigin:MTLOriginMake(0,0,0) sourceSize:MTLSizeMake(w,h,1) toBuffer:buffer destinationOffset:0 destinationBytesPerRow:w*4 destinationBytesPerImage:w*h*4];[blit endEncoding];[cmd commit];[cmd waitUntilCompleted];if(cmd.error)return 2;unsigned char*p=buffer.contents;BOOL ok=YES;
 if(n==0)ok=out==src&&memcmp(input,p,sizeof(input))==0;
 if(n==1||n==5)for(int i=0;i<w*h;i++)if(abs(p[i*4]-p[i*4+1])>1||abs(p[i*4+1]-p[i*4+2])>1)ok=NO;
 if(n==2)ok=p[(48*w+75)*4]>input[(48*w+75)*4]+3;
 if(n==3)ok=p[0]==0&&p[1]==0&&p[2]==0&&p[(48*w+48)*4]>0;
 if(n==4)ok=memcmp(input,p,sizeof(input))!=0;
 printf("effect case %d: %s\n",n,ok?"PASS":"FAIL");if(!ok)return 3;
 char filename[128];snprintf(filename,sizeof(filename),"work/gd-effects-case-%d.ppm",n);FILE*f=fopen(filename,"wb");fprintf(f,"P6\n%d %d\n255\n",w,h);for(int i=0;i<w*h;i++)fwrite(p+i*4,1,3,f);fclose(f);
 // Verify live disable on the same renderer without restarting it.
 if(n==2){[@"{}" writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:nil];usleep(200000);cmd=[q commandBuffer];if([fx processTexture:src commandBuffer:cmd]!=src)return 4;[cmd commit];[cmd waitUntilCompleted];puts("live disable: PASS");}
 n++;}
 return 0;
}}
