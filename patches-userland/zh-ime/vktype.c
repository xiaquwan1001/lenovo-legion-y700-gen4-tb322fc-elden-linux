#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/mman.h>
#include <time.h>
#include <wayland-client.h>
#include <xkbcommon/xkbcommon.h>
#include "vk-client.h"
static struct wl_seat *seat; static struct zwp_virtual_keyboard_manager_v1 *mgr; static struct zwp_virtual_keyboard_v1 *vk;
static void g(void*d,struct wl_registry*r,uint32_t n,const char*i,uint32_t v){(void)d;(void)v;
 if(!strcmp(i,"wl_seat")) seat=wl_registry_bind(r,n,&wl_seat_interface,1);
 else if(!strcmp(i,"zwp_virtual_keyboard_manager_v1")) mgr=wl_registry_bind(r,n,&zwp_virtual_keyboard_manager_v1_interface,1);}
static void rm(void*d,struct wl_registry*r,uint32_t n){(void)d;(void)r;(void)n;}
static const struct wl_registry_listener L={g,rm};
int main(int argc,char**argv){
 if(argc<2){puts("usage: vktype <ascii>");return 1;}
 struct wl_display*d=wl_display_connect(NULL); if(!d){puts("no wl");return 1;}
 struct wl_registry*r=wl_display_get_registry(d); wl_registry_add_listener(r,&L,NULL); wl_display_roundtrip(d);
 if(!seat||!mgr){puts("no seat/mgr");return 1;}
 vk=zwp_virtual_keyboard_manager_v1_create_virtual_keyboard(mgr,seat);
 struct xkb_context*ctx=xkb_context_new(XKB_CONTEXT_NO_FLAGS);
 struct xkb_keymap*km=xkb_keymap_new_from_names(ctx,NULL,XKB_KEYMAP_COMPILE_NO_FLAGS);
 char*str=xkb_keymap_get_as_string(km,XKB_KEYMAP_FORMAT_TEXT_V1); size_t len=strlen(str)+1;
 int fd=memfd_create("km",MFD_CLOEXEC); if(ftruncate(fd,len)<0){perror("ftruncate");return 1;}
 void*p=mmap(NULL,len,PROT_READ|PROT_WRITE,MAP_SHARED,fd,0); memcpy(p,str,len); munmap(p,len);
 zwp_virtual_keyboard_v1_keymap(vk,WL_KEYBOARD_KEYMAP_FORMAT_XKB_V1,fd,(uint32_t)len);
 wl_display_roundtrip(d);
 struct xkb_state*st=xkb_state_new(km);
 uint32_t t=(uint32_t)(clock()/1000);
 for(const char*s=argv[1]; *s; s++){
   xkb_keysym_t ks = (*s==' ')?XKB_KEY_space:(xkb_keysym_t)*s;
   xkb_keycode_t code = 0;
   /* 遍历 keymap：找发出该 keysym 的 keycode 与该 keycode 需要 shift 的状态 */
   xkb_mod_index_t shift = xkb_keymap_mod_get_index(km,"Shift");
   for(xkb_keycode_t k=8;k<255;k++){
     const xkb_keysym_t*ss=NULL; int num=xkb_keymap_key_get_syms_by_level(km,k,0,0,&ss);
     if(num==1 && ss[0]==ks){code=k;break;}
     num=xkb_keymap_key_get_syms_by_level(km,k,0,1,&ss);
     if(num==1 && ss[0]==ks){code=k; if(shift!=XKB_MOD_INVALID) xkb_state_update_mask(st,0,0,1u<<shift,0,0,0); break;}
   }
   if(!code){fprintf(stderr,"no keycode for %c\n",*s); continue;}
   uint32_t dep=xkb_state_serialize_mods(st,XKB_STATE_MODS_DEPRESSED);
   uint32_t lat=xkb_state_serialize_mods(st,XKB_STATE_MODS_LATCHED);
   uint32_t lock=xkb_state_serialize_mods(st,XKB_STATE_MODS_LOCKED);
   uint32_t lyt=xkb_state_serialize_layout(st,0);
   zwp_virtual_keyboard_v1_modifiers(vk,dep,lat,lock,lyt);
   uint32_t off = getenv("VK_OFF") ? (uint32_t)atoi(getenv("VK_OFF")) : 0; zwp_virtual_keyboard_v1_key(vk,t,code+off,1); zwp_virtual_keyboard_v1_key(vk,t+4,code+off,0);
   wl_display_flush(d); usleep(80000); t+=100;
 }
 usleep(300000); puts("typed"); return 0;
}
