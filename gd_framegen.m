#import "gd_framegen.h"

#include <stdio.h>
static NSString * const motionSource = @"#include <metal_stdlib>\nusing namespace metal;\n"
"kernel void motion(texture2d<float,access::read> prev[[texture(0)]], texture2d<float,access::read> curr[[texture(1)]], texture2d<float,access::write> mv[[texture(2)]], texture2d<float,access::write> depth[[texture(3)]], uint2 block[[thread_position_in_grid]]) {\n"
" int2 size=int2(curr.get_width(),curr.get_height()); int2 center=min(int2(block)*8+4,size-1); float best=1e20; int2 offset=0;\n"
" for(int dy=-24;dy<=24;dy+=3)for(int dx=-24;dx<=24;dx+=3){ float error=0.00001f*(dx*dx+dy*dy);\n"
"  for(int py=-2;py<=2;py+=2)for(int px=-2;px<=2;px+=2){int2 p=clamp(center+int2(px,py),int2(0),size-1);float3 a=curr.read(uint2(p)).rgb;float3 b=prev.read(uint2(clamp(p+int2(dx,dy),int2(0),size-1))).rgb;error+=dot(abs(a-b),float3(0.299,0.587,0.114));}\n"
"  if(error<best){best=error;offset=int2(dx,dy);}}\n"
" int2 coarse=offset; for(int dy=-2;dy<=2;dy++)for(int dx=-2;dx<=2;dx++){int2 d=coarse+int2(dx,dy);float error=0.00001f*dot(float2(d),float2(d));\n"
"  for(int py=-2;py<=2;py+=2)for(int px=-2;px<=2;px+=2){int2 p=clamp(center+int2(px,py),int2(0),size-1);float3 a=curr.read(uint2(p)).rgb;float3 b=prev.read(uint2(clamp(p+d,int2(0),size-1))).rgb;error+=dot(abs(a-b),float3(0.299,0.587,0.114));} if(error<best){best=error;offset=d;}}\n"
" for(uint y=0;y<8;y++)for(uint x=0;x<8;x++){uint2 p=block*8+uint2(x,y);if(p.x<uint(size.x)&&p.y<uint(size.y)){mv.write(float4(float2(offset),0,0),p);depth.write(float4(0.5),p);}}\n"
"}\n"
"kernel void interpolate(texture2d<float,access::sample> prev[[texture(0)]],texture2d<float,access::sample> curr[[texture(1)]],texture2d<float,access::sample> motion[[texture(2)]],texture2d<float,access::write> output[[texture(3)]],constant float &t[[buffer(0)]],uint2 p[[thread_position_in_grid]]){\n"
" if(p.x>=output.get_width()||p.y>=output.get_height())return;constexpr sampler smp(coord::normalized,address::clamp_to_edge,filter::linear);float2 size=float2(output.get_width(),output.get_height());float2 uv=(float2(p)+0.5)/size;float2 v=motion.sample(smp,uv).xy;float2 curUV=uv-(1-t)*v/size;v=motion.sample(smp,curUV).xy;float4 a=prev.sample(smp,uv+t*v/size);float4 b=curr.sample(smp,uv-(1-t)*v/size);output.write(mix(a,b,t),p);\n"
"}\n";
@implementation GDFrameGenerator {
 id<MTLDevice> _device;
 id<MTLComputePipelineState> _motionPipeline,_interpolatePipeline;
 id<MTLTexture> _history,_current,_motion,_depth;
 NSArray<id<MTLTexture>> *_outputs;
 NSUInteger _width,_height;
 BOOL _hasHistory,_reported;
}
- (instancetype)initWithDevice:(id<MTLDevice>)device {
 if((self=[super init])){_device=device;NSError *error=nil;id<MTLLibrary> lib=[device newLibraryWithSource:motionSource options:nil error:&error];
 if(!lib){fprintf(stderr,"gd-framegen: shader failure %s\n",error.localizedDescription.UTF8String);return nil;}
 _motionPipeline=[device newComputePipelineStateWithFunction:[lib newFunctionWithName:@"motion"] error:&error];
 _interpolatePipeline=[device newComputePipelineStateWithFunction:[lib newFunctionWithName:@"interpolate"] error:&error];
 if(!_motionPipeline||!_interpolatePipeline)return nil;
 }return self;
}
- (id<MTLTexture>)texture:(MTLPixelFormat)format {
 MTLTextureDescriptor *d=[MTLTextureDescriptor texture2DDescriptorWithPixelFormat:format width:_width height:_height mipmapped:NO];d.storageMode=MTLStorageModePrivate;d.usage=MTLTextureUsageShaderRead|MTLTextureUsageShaderWrite;return [_device newTextureWithDescriptor:d];
}
- (void)copy:(id<MTLTexture>)src to:(id<MTLTexture>)dst commands:(id<MTLCommandBuffer>)commands {
 id<MTLBlitCommandEncoder> e=[commands blitCommandEncoder];[e copyFromTexture:src sourceSlice:0 sourceLevel:0 sourceOrigin:MTLOriginMake(0,0,0) sourceSize:MTLSizeMake(src.width,src.height,1) toTexture:dst destinationSlice:0 destinationLevel:0 destinationOrigin:MTLOriginMake(0,0,0)];[e endEncoding];
}
- (NSArray<id<MTLTexture>> *)framesForTexture:(id<MTLTexture>)texture commandBuffer:(id<MTLCommandBuffer>)commands factor:(int)factor {
 if(factor!=2&&factor!=4)return @[texture];
 if(_width!=texture.width||_height!=texture.height||_history.pixelFormat!=texture.pixelFormat){
 _width=texture.width;_height=texture.height;_history=[self texture:texture.pixelFormat];_current=[self texture:texture.pixelFormat];_motion=[self texture:MTLPixelFormatRG16Float];_depth=[self texture:MTLPixelFormatR32Float];
 NSMutableArray *outputs=[NSMutableArray new];for(int i=0;i<3;i++){id<MTLTexture> t=[self texture:texture.pixelFormat];if(!t)return @[texture];[outputs addObject:t];}_outputs=outputs;_hasHistory=NO;_reported=NO;
 }
 if(!_history||!_current||!_motion||!_depth)return @[texture];
 if(!_hasHistory){[self copy:texture to:_history commands:commands];_hasHistory=YES;return @[texture];}
 [self copy:texture to:_current commands:commands];
 id<MTLComputeCommandEncoder> e=[commands computeCommandEncoder];[e setComputePipelineState:_motionPipeline];[e setTexture:_history atIndex:0];[e setTexture:_current atIndex:1];[e setTexture:_motion atIndex:2];[e setTexture:_depth atIndex:3];
 [e dispatchThreads:MTLSizeMake((_width+7)/8,(_height+7)/8,1) threadsPerThreadgroup:MTLSizeMake(8,8,1)];[e endEncoding];
 NSMutableArray *frames=[NSMutableArray new];
 for(int i=1;i<factor;i++){
 float time=(float)i/factor;e=[commands computeCommandEncoder];[e setComputePipelineState:_interpolatePipeline];[e setTexture:_history atIndex:0];[e setTexture:_current atIndex:1];[e setTexture:_motion atIndex:2];[e setTexture:_outputs[i-1] atIndex:3];[e setBytes:&time length:sizeof(time) atIndex:0];
 [e dispatchThreads:MTLSizeMake(_width,_height,1) threadsPerThreadgroup:MTLSizeMake(8,8,1)];[e endEncoding];[frames addObject:_outputs[i-1]];
 }
 [frames addObject:texture];[self copy:texture to:_history commands:commands];
 if(!_reported){_reported=YES;NSUInteger width=_width,height=_height;[commands addCompletedHandler:^(id<MTLCommandBuffer> done){fprintf(stderr,"gd-framegen: Custom motion interpolation %dx, %lux%lu GPU %s%s\n",factor,(unsigned long)width,(unsigned long)height,done.status==MTLCommandBufferStatusCompleted?"completed":"FAILED ",done.error?done.error.localizedDescription.UTF8String:"");}];}
 return frames;
}
@end
