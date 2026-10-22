#import "gd_effects.h"
#import <QuartzCore/QuartzCore.h>
#include <math.h>
#include <stdio.h>
typedef struct {float bloom,threshold,radius,crt,scanlines,curvature,mask,color,saturation,contrast,sharpen,grayscale;} GDEffectSettings;
static NSString *const effectsSource=@"#include <metal_stdlib>\nusing namespace metal;\n"
"struct Settings {float bloom,threshold,radius,crt,scanlines,curvature,mask,color,saturation,contrast,sharpen,grayscale;};\n"
"constexpr sampler smp(coord::normalized,address::clamp_to_edge,filter::linear);\n"
"kernel void extract(texture2d<float,access::sample> src[[texture(0)]],texture2d<float,access::write> dst[[texture(1)]],constant Settings&s[[buffer(0)]],uint2 p[[thread_position_in_grid]]){\n"
"if(p.x>=dst.get_width()||p.y>=dst.get_height())return;float2 uv=(float2(p)+0.5)/float2(dst.get_width(),dst.get_height());float3 c=src.sample(smp,uv).rgb;float peak=max(c.r,max(c.g,c.b));float gate=smoothstep(s.threshold,min(1.001f,s.threshold+0.18f),peak);dst.write(float4(c*gate,1),p);}\n"
"kernel void blur(texture2d<float,access::sample> src[[texture(0)]],texture2d<float,access::write> dst[[texture(1)]],constant Settings&s[[buffer(0)]],constant uint&axis[[buffer(1)]],uint2 p[[thread_position_in_grid]]){\n"
"if(p.x>=dst.get_width()||p.y>=dst.get_height())return;float2 size=float2(dst.get_width(),dst.get_height());float2 uv=(float2(p)+0.5)/size;int radius=max(1,int(s.radius));float sigma=max(0.6f,float(radius)*0.45f);float3 sum=0;float weights=0;for(int i=-radius;i<=radius;i++){float weight=exp(-float(i*i)/(2*sigma*sigma));float2 step=axis==0?float2(i,0):float2(0,i);sum+=src.sample(smp,uv+step/size).rgb*weight;weights+=weight;}dst.write(float4(sum/weights,1),p);}\n"
"kernel void composite(texture2d<float,access::sample> src[[texture(0)]],texture2d<float,access::sample> glow[[texture(1)]],texture2d<float,access::write> dst[[texture(2)]],constant Settings&s[[buffer(0)]],uint2 p[[thread_position_in_grid]]){\n"
"if(p.x>=dst.get_width()||p.y>=dst.get_height())return;float2 size=float2(dst.get_width(),dst.get_height());float2 uv=(float2(p)+0.5)/size;\n"
"if(s.crt>0){float2 q=uv*2-1;uv=(q*(1+s.curvature*float2(q.y*q.y,q.x*q.x))+1)*0.5;if(any(uv<0)||any(uv>1)){dst.write(float4(0,0,0,1),p);return;}}\n"
"float4 center=src.sample(smp,uv);float3 c=center.rgb;if(s.color>0&&s.sharpen>0){float3 neighbors=src.sample(smp,uv+float2(1,0)/size).rgb+src.sample(smp,uv-float2(1,0)/size).rgb+src.sample(smp,uv+float2(0,1)/size).rgb+src.sample(smp,uv-float2(0,1)/size).rgb;c+=s.sharpen*(4*c-neighbors)*0.35;}\n"
"if(s.bloom>0)c+=glow.sample(smp,uv).rgb*s.bloom;\n"
"if(s.color>0){c=(c-0.5)*s.contrast+0.5;float luma=dot(c,float3(0.2126,0.7152,0.0722));c=mix(float3(luma),c,s.grayscale>0?0.0f:s.saturation);}\n"
"if(s.crt>0){float lines=(p.y%2==0)?1-s.scanlines:1;float3 mask=float3(1-s.mask);mask[p.x%3]=1;c*=lines*mask;}if(s.color>0&&s.grayscale>0)c=float3(dot(c,float3(0.2126,0.7152,0.0722)));dst.write(float4(clamp(c,0.0f,1.0f),center.a),p);}\n";
static float setting(NSDictionary *d,NSString *key,float fallback,float low,float high){id value=d[key];if(![value isKindOfClass:NSNumber.class])return fallback;double x=[value doubleValue];return isfinite(x)?fmaxf(low,fminf(high,(float)x)):fallback;}
@implementation GDEffects {
 id<MTLDevice> _device;
 id<MTLComputePipelineState> _extract,_blur,_composite;
 id<MTLTexture> _bright,_scratch,_glow,_output;
 GDEffectSettings _settings;
 CFTimeInterval _lastPoll;
 BOOL _read,_reported;
}
- (instancetype)initWithDevice:(id<MTLDevice>)device {if((self=[super init]))_device=device;return self;}
- (void)readSettings {
 double now=CACurrentMediaTime();if(_read&&now-_lastPoll<0.15)return;_read=YES;_lastPoll=now;
 NSString *path=NSProcessInfo.processInfo.environment[@"GD_EFFECTS_CONFIG"]?:[NSHomeDirectory() stringByAppendingPathComponent:@"Library/Application Support/GD MetalFX Control/effects.json"];
 NSData *data=[NSData dataWithContentsOfFile:path];id parsed=data?[NSJSONSerialization JSONObjectWithData:data options:0 error:nil]:nil;NSDictionary *d=[parsed isKindOfClass:NSDictionary.class]?parsed:@{};
 GDEffectSettings s={0};s.bloom=setting(d,@"bloomEnabled",0,0,1)>0?setting(d,@"bloomStrength",0.5,0,2.5):0;s.threshold=setting(d,@"bloomThreshold",0.7,0.3,1);s.radius=setting(d,@"bloomRadius",5,1,16);
 s.crt=setting(d,@"crtEnabled",0,0,1);s.scanlines=setting(d,@"scanlines",0.2,0,0.8);s.curvature=setting(d,@"curvature",0.08,0,0.25);s.mask=setting(d,@"rgbMask",0.12,0,0.6);
 s.color=setting(d,@"colorEnabled",0,0,1);s.saturation=setting(d,@"saturation",1,0,2);s.contrast=setting(d,@"contrast",1,0.5,1.5);s.sharpen=setting(d,@"sharpen",0,0,1);s.grayscale=setting(d,@"grayscale",0,0,1);
 if(memcmp(&_settings,&s,sizeof(s)))_reported=NO;_settings=s;
}
- (id<MTLTexture>)texture:(MTLPixelFormat)format width:(NSUInteger)width height:(NSUInteger)height {
 MTLTextureDescriptor *d=[MTLTextureDescriptor texture2DDescriptorWithPixelFormat:format width:width height:height mipmapped:NO];d.storageMode=MTLStorageModePrivate;d.usage=MTLTextureUsageShaderRead|MTLTextureUsageShaderWrite;return [_device newTextureWithDescriptor:d];
}
- (BOOL)prepare {
 if(_composite)return YES;NSError *error=nil;id<MTLLibrary> lib=[_device newLibraryWithSource:effectsSource options:nil error:&error];
 if(!lib){fprintf(stderr,"gd-effects: shader error %s\n",error.localizedDescription.UTF8String);return NO;}
 _extract=[_device newComputePipelineStateWithFunction:[lib newFunctionWithName:@"extract"] error:&error];_blur=[_device newComputePipelineStateWithFunction:[lib newFunctionWithName:@"blur"] error:&error];_composite=[_device newComputePipelineStateWithFunction:[lib newFunctionWithName:@"composite"] error:&error];return _extract&&_blur&&_composite;
}
- (void)dispatch:(id<MTLComputeCommandEncoder>)e width:(NSUInteger)width height:(NSUInteger)height {
 [e dispatchThreads:MTLSizeMake(width,height,1) threadsPerThreadgroup:MTLSizeMake(8,8,1)];[e endEncoding];
}
- (id<MTLTexture>)processTexture:(id<MTLTexture>)input commandBuffer:(id<MTLCommandBuffer>)commands {
 [self readSettings];GDEffectSettings s=_settings;if(s.bloom<=0&&s.crt<=0&&s.color<=0){if(!_reported){_reported=YES;fprintf(stderr,"gd-effects: Off (unaltered image)\n");}return input;}if(![self prepare])return input;
 if(_output.width!=input.width||_output.height!=input.height||_output.pixelFormat!=input.pixelFormat){
  _output=[self texture:input.pixelFormat width:input.width height:input.height];NSUInteger w=MAX(1,(input.width+1)/2),h=MAX(1,(input.height+1)/2);
  _bright=[self texture:MTLPixelFormatRGBA16Float width:w height:h];_scratch=[self texture:MTLPixelFormatRGBA16Float width:w height:h];_glow=[self texture:MTLPixelFormatRGBA16Float width:w height:h];_reported=NO;
 }
 if(!_output||!_bright||!_scratch||!_glow)return input;
 if(s.bloom>0){
  id<MTLComputeCommandEncoder> e=[commands computeCommandEncoder];[e setComputePipelineState:_extract];[e setTexture:input atIndex:0];[e setTexture:_bright atIndex:1];[e setBytes:&s length:sizeof(s) atIndex:0];[self dispatch:e width:_bright.width height:_bright.height];
  for(unsigned axis=0;axis<2;axis++){e=[commands computeCommandEncoder];[e setComputePipelineState:_blur];[e setTexture:axis==0?_bright:_scratch atIndex:0];[e setTexture:axis==0?_scratch:_glow atIndex:1];[e setBytes:&s length:sizeof(s) atIndex:0];[e setBytes:&axis length:sizeof(axis) atIndex:1];[self dispatch:e width:_bright.width height:_bright.height];}
 }
 id<MTLComputeCommandEncoder> e=[commands computeCommandEncoder];[e setComputePipelineState:_composite];[e setTexture:input atIndex:0];[e setTexture:s.bloom>0?_glow:input atIndex:1];[e setTexture:_output atIndex:2];[e setBytes:&s length:sizeof(s) atIndex:0];[self dispatch:e width:input.width height:input.height];
 if(!_reported){_reported=YES;[commands addCompletedHandler:^(id<MTLCommandBuffer> done){fprintf(stderr,"gd-effects: bloom=%.2f CRT=%d color=%d GPU %s%s\n",s.bloom,s.crt>0,s.color>0,done.status==MTLCommandBufferStatusCompleted?"completed":"FAILED ",done.error?done.error.localizedDescription.UTF8String:"");}];}
 return _output;
}
@end
