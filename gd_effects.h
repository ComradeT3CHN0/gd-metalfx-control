#import <Metal/Metal.h>
@interface GDEffects : NSObject
- (instancetype)initWithDevice:(id<MTLDevice>)device;
- (id<MTLTexture>)processTexture:(id<MTLTexture>)input commandBuffer:(id<MTLCommandBuffer>)commands;
@end
