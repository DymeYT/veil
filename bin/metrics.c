#include <mach/mach.h>
#include <mach/host_info.h>
#include <mach/vm_statistics.h>
#include <sys/sysctl.h>
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <CoreFoundation/CoreFoundation.h>
// Apple silicon die sensors through IOKit's HID event system (no sudo; what Stats/macmon read)
typedef struct __IOHIDEvent *IOHIDEventRef;
typedef struct __IOHIDServiceClient *IOHIDServiceClientRef;
typedef struct __IOHIDEventSystemClient *IOHIDEventSystemClientRef;
IOHIDEventSystemClientRef IOHIDEventSystemClientCreate(CFAllocatorRef);
int IOHIDEventSystemClientSetMatching(IOHIDEventSystemClientRef,CFDictionaryRef);
CFArrayRef IOHIDEventSystemClientCopyServices(IOHIDEventSystemClientRef);
IOHIDEventRef IOHIDServiceClientCopyEvent(IOHIDServiceClientRef,int64_t,int32_t,int64_t);
CFTypeRef IOHIDServiceClientCopyProperty(IOHIDServiceClientRef,CFStringRef);
double IOHIDEventGetFloatValue(IOHIDEventRef,int32_t);
static double die_temp(void){  // hottest "PMU tdie" sensor in C, 0 when none answer
 int page=0xff00,usage=5; double hot=0;
 CFNumberRef p=CFNumberCreate(0,kCFNumberIntType,&page),u=CFNumberCreate(0,kCFNumberIntType,&usage);
 const void*k[]={CFSTR("PrimaryUsagePage"),CFSTR("PrimaryUsage")},*v[]={p,u};
 CFDictionaryRef m=CFDictionaryCreate(0,k,v,2,&kCFTypeDictionaryKeyCallBacks,&kCFTypeDictionaryValueCallBacks);
 IOHIDEventSystemClientRef c=IOHIDEventSystemClientCreate(0); if(!c)return 0;
 IOHIDEventSystemClientSetMatching(c,m); CFArrayRef s=IOHIDEventSystemClientCopyServices(c);
 for(CFIndex i=0;s&&i<CFArrayGetCount(s);i++){
  IOHIDServiceClientRef sc=(IOHIDServiceClientRef)CFArrayGetValueAtIndex(s,i); char name[64]="";
  CFStringRef n=IOHIDServiceClientCopyProperty(sc,CFSTR("Product"));
  if(n){CFStringGetCString(n,name,sizeof name,kCFStringEncodingUTF8);CFRelease(n);}
  if(!strstr(name,"tdie"))continue;
  IOHIDEventRef e=IOHIDServiceClientCopyEvent(sc,15,0,0); if(!e)continue;
  double t=IOHIDEventGetFloatValue(e,15<<16); CFRelease(e);
  if(t>0&&t<150&&t>hot)hot=t;  // sensors that are off report large negatives
 }
 if(s)CFRelease(s); CFRelease(c); CFRelease(m); CFRelease(p); CFRelease(u); return hot;
}
int main(int argc,char**argv){
 host_cpu_load_info_data_t cpu; mach_msg_type_number_t n=HOST_CPU_LOAD_INFO_COUNT;
 if(host_statistics(mach_host_self(),HOST_CPU_LOAD_INFO,(host_info_t)&cpu,&n)!=KERN_SUCCESS)return 1;
 unsigned long long total=0,idle=cpu.cpu_ticks[CPU_STATE_IDLE],oldtotal=0,oldidle=0;
 for(int i=0;i<CPU_STATE_MAX;i++)total+=cpu.cpu_ticks[i];
 if(argc>1){FILE*f=fopen(argv[1],"r");if(f){fscanf(f,"%llu %llu",&oldtotal,&oldidle);fclose(f);}f=fopen(argv[1],"w");if(f){fprintf(f,"%llu %llu",total,idle);fclose(f);}}
 double usage=(total>oldtotal&&oldtotal&&idle>=oldidle)?100.0*(1.0-(double)(idle-oldidle)/(total-oldtotal)):0;
 vm_statistics64_data_t vm; n=HOST_VM_INFO64_COUNT; uint64_t memory=0;size_t len=sizeof(memory);
 if(host_statistics64(mach_host_self(),HOST_VM_INFO64,(host_info64_t)&vm,&n)!=KERN_SUCCESS)return 1;
 sysctlbyname("hw.memsize",&memory,&len,0,0); vm_size_t pagesize;host_page_size(mach_host_self(),&pagesize);
 uint64_t used=((uint64_t)vm.active_count+vm.wire_count+vm.compressor_page_count)*pagesize;
 printf("%.0f %.1f %.0f\n",usage,(double)used/1073741824.0,die_temp());return 0;
}
