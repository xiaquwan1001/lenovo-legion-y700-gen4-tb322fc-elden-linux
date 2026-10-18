// 最小复现：同一个 GL texture 依次绑定两个不同 dma-buf（EGLImage），各自渲染一次，
// 看第二个 dma-buf 是否真的被写入。用于判定 libcamera 软 ISP「只写第 0 帧」的根因。
#include <cstdio>
#include <cstring>
#include <cstdint>
#include <cerrno>
#include <fcntl.h>
#include <unistd.h>
#include <sys/ioctl.h>
#include <sys/mman.h>
#include <linux/dma-heap.h>
#define EGL_EGLEXT_PROTOTYPES 1
#define GL_GLEXT_PROTOTYPES 1
#include <EGL/egl.h>
#include <EGL/eglext.h>
#include <GLES2/gl2.h>
#include <GLES2/gl2ext.h>

#define W 256
#define H 256

static int alloc_dmabuf(const char *name, size_t size, void **map) {
    int heap = open("/dev/dma_heap/system", O_RDWR);
    if (heap < 0) { perror("open heap"); return -1; }
    struct dma_heap_allocation_data a = {};
    a.len = size; a.fd_flags = O_RDWR | O_CLOEXEC;
    if (ioctl(heap, DMA_HEAP_IOCTL_ALLOC, &a) < 0) { perror("alloc"); return -1; }
    close(heap);
    *map = mmap(nullptr, size, PROT_READ | PROT_WRITE, MAP_SHARED, a.fd, 0);
    if (*map == MAP_FAILED) { perror("mmap"); return -1; }
    memset(*map, 0, size);
    printf("  dmabuf %s fd=%d\n", name, a.fd);
    return a.fd;
}

int main() {
    size_t size = W * H * 4;
    void *m1 = nullptr, *m2 = nullptr;
    int fd1 = alloc_dmabuf("buf1", size, &m1);
    int fd2 = alloc_dmabuf("buf2", size, &m2);
    if (fd1 < 0 || fd2 < 0) return 1;

    EGLDisplay dpy = eglGetPlatformDisplay(EGL_PLATFORM_SURFACELESS_MESA, EGL_DEFAULT_DISPLAY, nullptr);
    if (!eglInitialize(dpy, nullptr, nullptr)) { printf("eglInitialize failed 0x%x\n", eglGetError()); return 1; }
    eglBindAPI(EGL_OPENGL_ES_API);
    EGLint cfga[] = { EGL_SURFACE_TYPE, EGL_PBUFFER_BIT, EGL_RENDERABLE_TYPE, EGL_OPENGL_ES2_BIT,
                      EGL_RED_SIZE,8, EGL_GREEN_SIZE,8, EGL_BLUE_SIZE,8, EGL_ALPHA_SIZE,8, EGL_NONE };
    EGLConfig cfg; EGLint n = 0;
    eglChooseConfig(dpy, cfga, &cfg, 1, &n);
    EGLint ctxa[] = { EGL_CONTEXT_CLIENT_VERSION, 2, EGL_NONE };
    EGLContext ctx = eglCreateContext(dpy, cfg, EGL_NO_CONTEXT, ctxa);
    if (!eglMakeCurrent(dpy, EGL_NO_SURFACE, EGL_NO_SURFACE, ctx)) { printf("makeCurrent failed\n"); return 1; }

    printf("  GL_RENDERER=%s GL_VENDOR=%s\n", glGetString(GL_RENDERER), glGetString(GL_VENDOR));
    GLuint tex = 0, fbo = 0;
    glGenTextures(1, &tex);
    glGenFramebuffers(1, &fbo);
    glBindTexture(GL_TEXTURE_2D, tex);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);

    auto img = [&](int fd) {
        EGLAttrib attrs[] = { EGL_WIDTH, W, EGL_HEIGHT, H,
                           EGL_LINUX_DRM_FOURCC_EXT, 0x34325241 /*ARGB8888*/,
                           EGL_DMA_BUF_PLANE0_FD_EXT, fd,
                           EGL_DMA_BUF_PLANE0_OFFSET_EXT, 0,
                           EGL_DMA_BUF_PLANE0_PITCH_EXT, W * 4,
                           EGL_DMA_BUF_PLANE0_MODIFIER_LO_EXT, 0,
                           EGL_DMA_BUF_PLANE0_MODIFIER_HI_EXT, 0, EGL_NONE };
        EGLImageKHR e = eglCreateImage(dpy, EGL_NO_CONTEXT, EGL_LINUX_DMA_BUF_EXT, nullptr, attrs);
        if (e == EGL_NO_IMAGE_KHR) { printf("  eglCreateImageKHR failed 0x%x\n", eglGetError()); return (EGLImageKHR)0; }
        return e;
    };

    auto render_and_read = [&](int fd, void *map, GLfloat r, GLfloat g, const char *tag) {
        EGLImageKHR e = img(fd);
        if (!e) return;
        glBindTexture(GL_TEXTURE_2D, tex);
        PFNGLEGLIMAGETARGETTEXTURE2DOESPROC targetFn = (PFNGLEGLIMAGETARGETTEXTURE2DOESPROC)eglGetProcAddress("glEGLImageTargetTexture2DOES");
        if (!targetFn) { printf("  no glEGLImageTargetTexture2DOES\n"); return; }
        targetFn(GL_TEXTURE_2D, e);
        glBindFramebuffer(GL_FRAMEBUFFER, fbo);
        glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, tex, 0);
        GLenum st = glCheckFramebufferStatus(GL_FRAMEBUFFER);
        glViewport(0, 0, W, H);
        glClearColor(r, g, 0.0f, 1.0f);
        glClear(GL_COLOR_BUFFER_BIT);
        glFinish();
        GLenum err = glGetError();
        eglDestroyImage(dpy, e);
        unsigned char *p = (unsigned char *)map;
        size_t i = (H / 2 * W + W / 2) * 4;
        printf("  %s: fbo=0x%x glErr=0x%x pixel B=%u G=%u R=%u A=%u\n", tag, st, err,
               p[i], p[i+1], p[i+2], p[i+3]);
    };

    printf("1) 两个 texture 的经典路径（每次都用同一个 texture 重绑 EGLImage）:\n");
    render_and_read(fd1, m1, 1.0f, 0.0f, "buf1 <- red");
    render_and_read(fd2, m2, 0.0f, 1.0f, "buf2 <- green");
    render_and_read(fd1, m1, 0.0f, 0.0f, "buf1 <- blue");
    printf("判据：若 buf2/buf1 的像素仍是 0 ⇒ 同一个 texture 重绑新 EGLImage 不生效（Mesa 行为）\n");
    return 0;
}
