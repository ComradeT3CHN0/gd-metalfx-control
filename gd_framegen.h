#import <Metal/Metal.h>
@interface GDFrameGenerator : NSObject
- (instancetype)initWithDevice:(id<MTLDevice>)device;
- (NSArray<id<MTLTexture>> *)framesForTexture:(id<MTLTexture>)texture commandBuffer:(id<MTLCommandBuffer>)commands factor:(int)factor;
@end
