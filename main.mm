#import <Cocoa/Cocoa.h>

#define STB_IMAGE_WRITE_IMPLEMENTATION
#define STBI_ONLY_PNG
#import "stb_image_write.h"

class App {
    
    private:
        
        unsigned int *texure = nullptr;
    
    public:
      
        App() {
            
            int w = 1920*2;
            int h = 1080*2;
                            
            this->texure = new unsigned int[w*h];
            for(int n=0; n<w*h; n++) this->texure[n] = 0xFFFF0000;
                        
            stbi_write_png("test.png",w,h,4,(void const*)this->texure,w<<2);

            dispatch_async(dispatch_get_main_queue(),^{
                [NSApp terminate:nil];
            });
        }
        
        ~App() {
            delete[] this->texure;
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
