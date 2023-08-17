#import <Cocoa/Cocoa.h>
#import <Metal/Metal.h>
#import <QuartzCore/QuartzCore.h>

#define STB_IMAGE_WRITE_IMPLEMENTATION
#define STBI_ONLY_PNG
#import "stb_image_write.h"

class Plane {
    
    public:
        
        constexpr static int TEXCOORD_SIZE = 4*2;
        constexpr static float texcoord[TEXCOORD_SIZE] = {
            0.f, 0.f,
            1.f, 0.f,
            1.f, 1.f,
            0.f, 1.f
        };
        
        constexpr static int VERTICES_SIZE = 4*4;
        constexpr static float vertices[VERTICES_SIZE] = {
            -1.f,-1.f, 0.f, 1.f,
            1.f,-1.f, 0.f, 1.f,
            1.f, 1.f, 0.f, 1.f,
            -1.f, 1.f, 0.f, 1.f
        };
        
        constexpr static int INDICES_SIZE = 6;
        constexpr static unsigned short indices[INDICES_SIZE] = {
            0,1,2,
            0,2,3
        };
        
        Plane() {}
};

template <typename T>
class MetalLayer {
    
    private:
        
        bool _isInit = false;
        
        int _width;
        int _height;
        
        T *_data;
        
        CAMetalLayer *_metalLayer;
        MTLRenderPassDescriptor *_renderPassDescriptor;
        id<MTLDevice> _device;
        id<MTLCommandQueue> _commandQueue;
        
        id<CAMetalDrawable> _metalDrawable;
        id<MTLTexture> _drawabletexture;
        
        id<MTLLibrary> _library;
        id<MTLRenderPipelineState> _renderPipelineState;
        MTLRenderPipelineDescriptor *_renderPipelineDescriptor;
        
        id<MTLBuffer> _verticesBuffer;
        id<MTLBuffer> _indicesBuffer;
        id<MTLBuffer> _texcoordBuffer;
        id<MTLBuffer> _argumentEncoderBuffer;
        
        id<MTLTexture> _texture;
        id<MTLArgumentEncoder> _argumentEncoder;
        
        void setColorAttachment(MTLRenderPipelineColorAttachmentDescriptor *colorAttachment) {
            colorAttachment.blendingEnabled = YES;
            colorAttachment.rgbBlendOperation = MTLBlendOperationAdd;
            colorAttachment.alphaBlendOperation = MTLBlendOperationAdd;
            colorAttachment.sourceRGBBlendFactor = MTLBlendFactorSourceAlpha;
            colorAttachment.sourceAlphaBlendFactor = MTLBlendFactorOne;
            colorAttachment.destinationRGBBlendFactor = MTLBlendFactorOneMinusSourceAlpha;
            colorAttachment.destinationAlphaBlendFactor = MTLBlendFactorOne;
        }
        
        bool setupShader() {
            id<MTLFunction> vertexFunction = [this->_library newFunctionWithName:@"vertexShader"];
            if(!vertexFunction) return false;
            id<MTLFunction> fragmentFunction = [this->_library newFunctionWithName:@"fragmentShader"];
            if(!fragmentFunction) return false;
            this->_renderPipelineDescriptor = [MTLRenderPipelineDescriptor new];
            if(!this->_renderPipelineDescriptor) return false;
            this->_argumentEncoder = [fragmentFunction newArgumentEncoderWithBufferIndex:0];
            
            this->_renderPipelineDescriptor.depthAttachmentPixelFormat = MTLPixelFormatInvalid;
            this->_renderPipelineDescriptor.stencilAttachmentPixelFormat = MTLPixelFormatInvalid;
            this->_renderPipelineDescriptor.colorAttachments[0].pixelFormat = MTLPixelFormatBGRA8Unorm;
            this->_renderPipelineDescriptor.colorAttachments[0].blendingEnabled = NO;
            
            this->_renderPipelineDescriptor.rasterSampleCount = 1;
            this->_renderPipelineDescriptor.vertexFunction   = vertexFunction;
            this->_renderPipelineDescriptor.fragmentFunction = fragmentFunction;
            NSError *error = nil;
            this->_renderPipelineState = [this->_device newRenderPipelineStateWithDescriptor:this->_renderPipelineDescriptor error:&error];
            if(error||!this->_renderPipelineState) return true;
            return false;
        }
        
    public:
        
        id<MTLTexture> texture() {
            return this->_texture;
        }
        
        T *data() { return this->_data; }
        
        MetalLayer() {
            this->_data = new T();
        }
        
        ~MetalLayer() {
            delete this->_data;
        }
        
        bool setup() {
            
            this->_verticesBuffer = [this->_device newBufferWithBytes:_data->vertices length:_data->VERTICES_SIZE*sizeof(float) options:MTLResourceCPUCacheModeDefaultCache];
            if(!this->_verticesBuffer) return false;
            
            this->_indicesBuffer = [this->_device newBufferWithBytes:_data->indices length:_data->INDICES_SIZE*sizeof(short) options:MTLResourceCPUCacheModeDefaultCache];
            if(!this->_indicesBuffer) return false;
            
            MTLTextureDescriptor *texDesc = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatBGRA8Unorm width:this->_width height:this->_height mipmapped:NO];
            if(!texDesc) return false;
            
            this->_texture = [this->_device newTextureWithDescriptor:texDesc];
            if(!this->_texture) return false;
            
            this->_texcoordBuffer = [this->_device newBufferWithBytes:this->_data->texcoord length:this->_data->TEXCOORD_SIZE*sizeof(float) options:MTLResourceCPUCacheModeDefaultCache];
            if(!this->_texcoordBuffer) return false;
            
            this->_argumentEncoderBuffer = [this->_device newBufferWithLength:sizeof(float)*[this->_argumentEncoder encodedLength] options:MTLResourceCPUCacheModeDefaultCache];
            
            [this->_argumentEncoder setArgumentBuffer:this->_argumentEncoderBuffer offset:0];
            [this->_argumentEncoder setTexture:this->_texture atIndex:0];
            
            return true;
        }
        
        id<MTLCommandBuffer> setupCommandBuffer() {
            
            id<MTLCommandBuffer> commandBuffer = [this->_commandQueue commandBuffer];
            MTLRenderPassColorAttachmentDescriptor *colorAttachment = this->_renderPassDescriptor.colorAttachments[0];
            colorAttachment.texture = this->_metalDrawable.texture;
            colorAttachment.loadAction  = MTLLoadActionClear;
            colorAttachment.clearColor  = MTLClearColorMake(0.0f,0.0f,0.0f,0.0f);
            colorAttachment.storeAction = MTLStoreActionStore;
            
            id<MTLRenderCommandEncoder> renderEncoder = [commandBuffer renderCommandEncoderWithDescriptor:this->_renderPassDescriptor];
            [renderEncoder setFrontFacingWinding:MTLWindingCounterClockwise];
            [renderEncoder setRenderPipelineState:this->_renderPipelineState];
            [renderEncoder setVertexBuffer:this->_verticesBuffer offset:0 atIndex:0];
            [renderEncoder setVertexBuffer:this->_texcoordBuffer offset:0 atIndex:1];
            
            [renderEncoder useResource:this->_texture usage:MTLResourceUsageRead stages:MTLRenderStageFragment];
            [renderEncoder setFragmentBuffer:this->_argumentEncoderBuffer offset:0 atIndex:0];
            
            [renderEncoder drawIndexedPrimitives:MTLPrimitiveTypeTriangle indexCount:this->_data->INDICES_SIZE indexType:MTLIndexTypeUInt16 indexBuffer:this->_indicesBuffer indexBufferOffset:0];
            
            [renderEncoder endEncoding];
            [commandBuffer presentDrawable:this->_metalDrawable];
            this->_drawabletexture = this->_metalDrawable.texture;
            return commandBuffer;
        }
        
        bool init(int width, int height, NSString *shaders=@"default.metallib") {
            
            this->_width = width;
            this->_height = height;
            
            if(this->_metalLayer==nil) this->_metalLayer = [CAMetalLayer layer];
            this->_device = MTLCreateSystemDefaultDevice();
            this->_metalLayer.device = this->_device;
            this->_metalLayer.pixelFormat = MTLPixelFormatBGRA8Unorm;
            
            this->_metalLayer.colorspace = [[NSScreen mainScreen] colorSpace].CGColorSpace;
            
            this->_metalLayer.opaque = NO;
            this->_metalLayer.framebufferOnly = NO;
            this->_metalLayer.displaySyncEnabled = YES;
            
            this->_metalLayer.drawableSize = CGSizeMake(this->_width,this->_height);
            this->_commandQueue = [this->_device newCommandQueue];
            if(!this->_commandQueue) return false;
            NSError *error = nil;
            id<MTLLibrary> lib=  [this->_device newLibraryWithURL:[NSURL URLWithString:[NSString stringWithFormat:@"%@/%@",[[NSBundle mainBundle] resourcePath],shaders]] error:&error];
            if(lib) {
                this->_library = lib;
                if(error) return false;
            }
            else {
                return false;
            }
            if(this->setupShader()) return false;
            this->_isInit = this->setup();
            return this->_isInit;
        }
        
        bool isInit() {
            return this->_isInit;
        }
        
        id<MTLTexture> drawableTexture() {
            return this->_drawabletexture;
        }
        
        void cleanup() {
            this->_metalDrawable = nil;
        }
        
        id<MTLCommandBuffer> prepareCommandBuffer() {
            if(!this->_metalDrawable) {
                this->_metalDrawable = [this->_metalLayer nextDrawable];
            }
            if(!this->_metalDrawable) {
                this->_renderPassDescriptor = nil;
            }
            else {
                if(this->_renderPassDescriptor==nil) this->_renderPassDescriptor = [MTLRenderPassDescriptor renderPassDescriptor];
            }
            if(this->_metalDrawable&&this->_renderPassDescriptor) {
                return this->setupCommandBuffer();
            }
            return nil;
        }
        
        void update(void (^onComplete)(id<MTLCommandBuffer>)) {
            if(this->_isInit==false) return;
            if(this->_renderPipelineState) {
                id<MTLCommandBuffer> commandBuffer = this->prepareCommandBuffer();
                if(commandBuffer) {
                    [commandBuffer addCompletedHandler:onComplete];
                    [commandBuffer commit];
                    [commandBuffer waitUntilCompleted];
                }
            }
        }
        
        CAMetalLayer *layer() {
            return this->_metalLayer;
        }
};

class App {
    
    private:
        
        unsigned int *_texture = nullptr;
        MetalLayer<Plane> *_layer = nullptr;
        
    public:
    
        App() {
            
            int w = 1920*2;
            int h = 1080*2;
                            
            this->_texture = new unsigned int[w*h];
            for(int n=0; n<w*h; n++) this->_texture[n] = 0xFFFF0000;
            
            this->_layer = new MetalLayer<Plane>();
            if(this->_layer->init(w,h)) {
                
                [this->_layer->texture() replaceRegion:MTLRegionMake2D(0,0,w,h) mipmapLevel:0 withBytes:this->_texture bytesPerRow:w<<2];

                this->_layer->update(^(id<MTLCommandBuffer> commandBuffer){
                    
                    [this->_layer->drawableTexture() getBytes:this->_texture bytesPerRow:w*4 fromRegion:MTLRegionMake2D(0,0,w,h) mipmapLevel:0];

                    stbi_write_png("test.png",w,h,4,(void const*)this->_texture,w<<2);
                    
                    this->_layer->cleanup();
                    
                    dispatch_async(dispatch_get_main_queue(),^{
                        [NSApp terminate:nil];
                    });
                });
            }
        }
        
        ~App() {
            delete[] this->_texture;
        }
};

#pragma mark AppDelegate

@interface AppDelegate:NSObject <NSApplicationDelegate> {
    App *app;
}
@end

@implementation AppDelegate
-(void)applicationDidFinishLaunching:(NSNotification*)aNotification {
    app = new App();
}
-(void)applicationWillTerminate:(NSNotification *)aNotification {
    delete app;
}
@end

int main(int argc, char *argv[]) {
    @autoreleasepool {
        id app = [NSApplication sharedApplication];
        id delegat = [AppDelegate alloc];
        [app setDelegate:delegat];
        [app run];
    }
}
