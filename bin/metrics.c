#include <mach/mach.h>
#include <mach/host_info.h>
#include <mach/vm_statistics.h>
#include <sys/sysctl.h>
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
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
 printf("%.0f %.1f\n",usage,(double)used/1073741824.0);return 0;
}
