#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <time.h>
#include <wayland-client.h>
#include "vp-client.h"
static struct wl_seat *seat; static struct zwlr_virtual_pointer_manager_v1 *mgr; static struct zwlr_virtual_pointer_v1 *vp;
static void g(void*d,struct wl_registry*r,uint32_t n,const char*i,uint32_t v){(void)d;(void)v;
 if(!strcmp(i,"wl_seat")) seat=wl_registry_bind(r,n,&wl_seat_interface,1);
 else if(!strcmp(i,"zwlr_virtual_pointer_manager_v1")) mgr=wl_registry_bind(r,n,&zwlr_virtual_pointer_manager_v1_interface,1);}
static void rm(void*d,struct wl_registry*r,uint32_t n){(void)d;(void)r;(void)n;}
static const struct wl_registry_listener L={g,rm};
int main(int argc,char**argv){
 if(argc<3){puts("usage: vp <x> <y> [extentx extenty]");return 1;}
 uint32_t x=atoi(argv[1]), y=atoi(argv[2]);
 uint32_t ex=argc>3?atoi(argv[3]):1904, ey=argc>4?atoi(argv[4]):3040;
 struct wl_display*d=wl_display_connect(NULL); if(!d){puts("no wl");return 1;}
 struct wl_registry*r=wl_display_get_registry(d); wl_registry_add_listener(r,&L,NULL); wl_display_roundtrip(d);
 if(!seat||!mgr){puts("no seat/mgr");return 1;}
 vp=zwlr_virtual_pointer_manager_v1_create_virtual_pointer(mgr,seat);
 wl_display_roundtrip(d);
 uint32_t t=(uint32_t)(clock()/1000);
 zwlr_virtual_pointer_v1_motion_absolute(vp,t,x,y,ex,ey);
 zwlr_virtual_pointer_v1_frame(vp);
 wl_display_flush(d); usleep(300000);
 t=(uint32_t)(clock()/1000);
 zwlr_virtual_pointer_v1_button(vp,t,0x110,1);
 zwlr_virtual_pointer_v1_frame(vp);
 wl_display_flush(d); usleep(120000);
 t=(uint32_t)(clock()/1000);
 zwlr_virtual_pointer_v1_button(vp,t,0x110,0);
 zwlr_virtual_pointer_v1_frame(vp);
 wl_display_flush(d); usleep(200000);
 puts("clicked"); return 0; }
