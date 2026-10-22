#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#import "gd_framegen.h"
#include <stdio.h>
int main(int argc,char**argv){@autoreleasepool{
 id<MTLDevice>d=MTLCreateSystemDefaultDevice();id<MTLCommandQueue>q=[d newCommandQueue];GDFrameGenerator *g=[[GDFrameGenerator alloc]initWithDevice:d];if(!g)return 2;
 int width=128,height=96;MTLTextureDescriptor *td=[MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA8Unorm width:width height:height mipmapped:NO];td.usage=MTLTextureUsageShaderRead;td.storageMode=MTLStorageModeShared;
 id<MTLTexture> previous=[d newTextureWithDescriptor:td],current=[d newTextureWithDescriptor:td];unsigned char a[128*96*4],b[128*96*4];memset(a,0,sizeof(a));memset(b,0,sizeof(b));for(int y=0;y<height;y++)for(int x=0;x<width;x++){int i=(y*width+x)*4;a[i+3]=b[i+3]=255;if(y>=32&&y<64){if(x>=24&&x<48)a[i]=a[i+1]=a[i+2]=255;if(x>=28&&x<52)b[i]=b[i+1]=b[i+2]=255;}}
 [previous replaceRegion:MTLRegionMake2D(0,0,width,height) mipmapLevel:0 withBytes:a bytesPerRow:width*4];[current replaceRegion:MTLRegionMake2D(0,0,width,height) mipmapLevel:0 withBytes:b bytesPerRow:width*4];
 id<MTLCommandBuffer>cmd=[q commandBuffer];[g framesForTexture:previous commandBuffer:cmd factor:2];[cmd commit];[cmd waitUntilCompleted];
 cmd=[q commandBuffer];int factor=argc>1?atoi(argv[1]):2;NSArray<id<MTLTexture>>*frames=[g framesForTexture:current commandBuffer:cmd factor:factor];NSMutableArray *buffers=[NSMutableArray new];
 for(id<MTLTexture>texture in frames){id<MTLBuffer>out=[d newBufferWithLength:width*height*4 options:MTLResourceStorageModeShared];id<MTLBlitCommandEncoder>e=[cmd blitCommandEncoder];[e copyFromTexture:texture sourceSlice:0 sourceLevel:0 sourceOrigin:MTLOriginMake(0,0,0) sourceSize:MTLSizeMake(width,height,1) toBuffer:out destinationOffset:0 destinationBytesPerRow:width*4 destinationBytesPerImage:width*height*4];[e endEncoding];[buffers addObject:out];}
 [cmd commit];[cmd waitUntilCompleted];if(cmd.error){fprintf(stderr,"%s\n",cmd.error.localizedDescription.UTF8String);return 3;}
 int index=0;BOOL generated=NO;BOOL positions=YES;for(id<MTLBuffer>out in buffers){unsigned char*p=out.contents;double weight=0,moment=0;for(int y=0;y<height;y++)for(int x=0;x<width;x++){double w=p[(y*width+x)*4];weight+=w;moment+=w*x;}BOOL samePrev=memcmp(p,a,sizeof(a))==0,sameCurrent=memcmp(p,b,sizeof(b))==0;printf("frame%d centroid=%.2f input_previous=%d input_current=%d\n",index,moment/fmax(1,weight),samePrev,sameCurrent);if(index<buffers.count-1&&!samePrev&&!sameCurrent)generated=YES;double expected=35.5+4.0*(index+1)/factor;if(fabs(moment/fmax(1,weight)-expected)>0.6)positions=NO;char file[128];snprintf(file,sizeof(file),"work/framegen-%d-%d.ppm",factor,index);FILE*f=fopen(file,"wb");fprintf(f,"P6\n%d %d\n255\n",width,height);for(int i=0;i<width*height;i++)fwrite(p+i*4,1,3,f);fclose(f);index++;}
 return frames.count==factor&&generated&&positions?0:4;
}}
