#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/mman.h>
#include <poll.h>
#include <wayland-client.h>
#include "layer-shell-client.h"
static struct wl_compositor *comp; static struct wl_shm *shm; static struct zwlr_layer_shell_v1 *ls;
static struct wl_surface *surf; static struct zwlr_layer_surface_v1 *lsurf; static int W=300,H=60;
static void g(void*d,struct wl_registry*r,uint32_t n,const char*i,uint32_t v){(void)d;
 if(!strcmp(i,"wl_compositor")) comp=wl_registry_bind(r,n,&wl_compositor_interface,4);
 else if(!strcmp(i,"wl_shm")) shm=wl_registry_bind(r,n,&wl_shm_interface,1);
 else if(!strcmp(i,"zwlr_layer_shell_v1")) ls=wl_registry_bind(r,n,&zwlr_layer_shell_v1_interface,1);}
static void rm(void*d,struct wl_registry*r,uint32_t n){(void)d;(void)r;(void)n;}
static const struct wl_registry_listener RL={g,rm};
static void cfg(void*d,struct zwlr_layer_surface_v1*s,uint32_t ser,uint32_t w,uint32_t h){(void)d;
 printf("configure %u %u\n",w,h); fflush(stdout);
 zwlr_layer_surface_v1_ack_configure(s,ser);
 int size=W*H*4; int fd=memfd_create("b",MFD_CLOEXEC); if(ftruncate(fd,size)<0){perror("ftruncate");exit(1);}
 unsigned char*p=mmap(NULL,size,PROT_READ|PROT_WRITE,MAP_SHARED,fd,0);
 for(int i=0;i<size;i+=4){p[i]=0x40;p[i+1]=0x80;p[i+2]=0xff;p[i+3]=0xff;}
 struct wl_shm_pool*pool=wl_shm_create_pool(shm,fd,size);
 struct wl_buffer*b=wl_shm_pool_create_buffer(pool,0,W,H,W*4,WL_SHM_FORMAT_ARGB8888);
 wl_shm_pool_destroy(pool); close(fd);
 wl_surface_attach(surf,b,0,0); wl_surface_damage_buffer(surf,0,0,W,H); wl_surface_commit(surf);
 printf("committed, flush=%d\n", 0); }
static void cl(void*d,struct zwlr_layer_surface_v1*s){(void)d;(void)s;printf("closed\n");}
static const struct zwlr_layer_surface_v1_listener LL={cfg,cl};
int main(void){
 struct wl_display*d=wl_display_connect(NULL); if(!d){puts("no wl");return 1;}
 struct wl_registry*r=wl_display_get_registry(d); wl_registry_add_listener(r,&RL,NULL); wl_display_roundtrip(d);
 printf("comp=%p shm=%p ls=%p\n",(void*)comp,(void*)shm,(void*)ls);
 if(!comp||!shm||!ls) return 1;
 surf=wl_compositor_create_surface(comp);
 lsurf=zwlr_layer_shell_v1_get_layer_surface(ls,surf,NULL,2,"tmin");
 zwlr_layer_surface_v1_add_listener(lsurf,&LL,NULL);
 zwlr_layer_surface_v1_set_size(lsurf,W,H);
 zwlr_layer_surface_v1_set_anchor(lsurf,2|4|8);
 zwlr_layer_surface_v1_set_margin(lsurf,0,0,200,0);
 zwlr_layer_surface_v1_set_exclusive_zone(lsurf,-1);
 zwlr_layer_surface_v1_set_keyboard_interactivity(lsurf,0);
 wl_surface_commit(surf);
 wl_display_flush(d);
 for(int i=0;i<200;i++){
   struct pollfd p={.fd=wl_display_get_fd(d),.events=POLLIN};
   if(poll(&p,1,50)>0){ if(wl_display_dispatch(d)<0){printf("dispatch err %d\n",wl_display_get_error(d)); break;} }
   wl_display_flush(d);
 }
 printf("done\n"); return 0; }
