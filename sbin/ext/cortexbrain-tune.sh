#!/sbin/busybox sh

#Credits:
# Zacharias.maladroit
# Voku1987
# Collin_ph@xda
# Dorimanx@xda
# Gokhanmoral@xda
# Johnbeetee

# TAKE NOTE THAT LINES PRECEDED BY A "#" IS COMMENTED OUT.
# This script must be activated after init start =< 25sec or parameters from /sys/* will not be loaded.

# read setting from profile

# Get values from profile. since we dont have the recovery source code i cant change the .siyah dir, so just leave it there for history.
PROFILE=`cat /data/.siyah/.active.profile`;
. /data/.siyah/$PROFILE.profile;

FILE_NAME=$0;
PIDOFCORTEX=$$;

# default settings (1000 = 10 seconds)
dirty_expire_centisecs_default=1000;
dirty_writeback_centisecs_default=1000;

# battery settings
dirty_expire_centisecs_battery=0;
dirty_writeback_centisecs_battery=0;

# =========
# Renice - kernel thread responsible for managing the swap memory and logs
# =========
renice 15 -p `pidof kswapd0`;
renice 15 -p `pgrep logcat`;

# replace kernel version info for repacked kernels
cat /proc/version | grep infra && (kmemhelper -t string -n linux_proc_banner -o 15 `cat /res/version`);

# ==============================================================
# I/O-TWEAKS 
# ==============================================================
IO_TWEAKS()
{
	if [ "$cortexbrain_io" == on ]; then
		MMC=`ls -d /sys/block/mmc*`;
		ZRM=`ls -d /sys/block/zram*`;

		for z in $ZRM; do
	
			if [ -e $i/queue/rotational ]; then
				echo "0" > $i/queue/rotational;
			fi;

			if [ -e $i/queue/iostats ]; then
				echo "0" > $i/queue/iostats;
			fi;

			if [ -e $i/queue/rq_affinity ]; then
				echo "1" > $i/queue/rq_affinity;
			fi;

			if [ -e $i/queue/read_ahead_kb ]; then
				echo "512" >  $i/queue/read_ahead_kb;
			fi;

			if [ -e $i/queue/max_sectors_kb ]; then
				echo "512" >  $i/queue/max_sectors_kb; # default: 127
			fi;

		done;

		for i in $MMC; do

			if [ -e $i/queue/scheduler ]; then
				echo $scheduler > $i/queue/scheduler;
			fi;

			if [ -e $i/queue/rotational ]; then
				echo "0" > $i/queue/rotational;
			fi;

			if [ -e $i/queue/iostats ]; then
				echo "0" > $i/queue/iostats;
			fi;

			if [ -e $i/queue/read_ahead_kb ]; then
				echo "1024" >  $i/queue/read_ahead_kb; # default: 128
			fi;

			if [ -e $i/queue/nr_requests ]; then
				echo "128" > $i/queue/nr_requests; # default: 128
			fi;

			if [ -e $i/queue/iosched/back_seek_penalty ]; then
				echo "1" > $i/queue/iosched/back_seek_penalty; # default: 2
			fi;

			if [ -e $i/queue/iosched/slice_idle ]; then
				echo "2" > $i/queue/iosched/slice_idle; # default: 8
			fi;

			if [ -e $i/queue/iosched/fifo_batch ]; then
				echo "1" > $i/queue/iosched/fifo_batch;
			fi;

		done;

		if [ -e /sys/devices/virtual/bdi/default/read_ahead_kb ]; then
			echo "1024" > /sys/devices/virtual/bdi/default/read_ahead_kb;
		fi;

		SDCARDREADAHEAD=`ls -d /sys/devices/virtual/bdi/179*`;
		for i in $SDCARDREADAHEAD; do
			echo "1024" > $i/read_ahead_kb;
		done;

		echo "10" > /proc/sys/fs/lease-break-time;

		log -p i -t $FILE_NAME "*** IO_TWEAKS ***: enabled";
	fi;
}
IO_TWEAKS;

# ==============================================================
# KERNEL-TWEAKS
# ==============================================================
KERNEL_TWEAKS()
{
	if [ "$cortexbrain_kernel_tweaks" == on ]; then
		echo "1" > /proc/sys/vm/oom_kill_allocating_task;
		sysctl -w vm.panic_on_oom=0;
	
		log -p i -t $FILE_NAME "*** KERNEL_TWEAKS ***: enabled";
	fi;
}
KERNEL_TWEAKS;

# ==============================================================
# SYSTEM-TWEAKS
# ==============================================================
SYSTEM_TWEAKS()
{
	if [ "$cortexbrain_system" == on ]; then
		# render UI with GPU
		setprop hwui.render_dirty_regions false;
		setprop windowsmgr.max_events_per_sec 240;
		setprop profiler.force_disable_err_rpt 1;
		setprop profiler.force_disable_ulog 1;

		log -p i -t $FILE_NAME "*** SYSTEM_TWEAKS ***: enabled";
	fi;
}
SYSTEM_TWEAKS;

# ==============================================================
# BATTERY-TWEAKS
# ==============================================================
BATTERY_TWEAKS()
{
	if [ "$cortexbrain_battery" == on ]; then
		# battery-calibration if battery is full
		LEVEL=`cat /sys/class/power_supply/battery/capacity`;
		CURR_ADC=`cat /sys/class/power_supply/battery/batt_current_adc`;
		BATTFULL=`cat /sys/class/power_supply/battery/batt_full_check`;
		log -p i -t $FILE_NAME "*** BATTERY - LEVEL: $LEVEL - CUR: $CURR_ADC ***";
		if [ "$LEVEL" == 100 ] && [ "$BATTFULL" == 1 ]; then
			rm -f /data/system/batterystats.bin;
			log -p i -t $FILE_NAME "battery-calibration done ...";
		fi;

		if [ "$power_reduce" == on ]; then
			# LCD Power-Reduce
			if [ -e /sys/class/lcd/panel/power_reduce ]; then
				echo "1" > /sys/class/lcd/panel/power_reduce;
			fi;
		else
			if [ -e /sys/class/lcd/panel/power_reduce ]; then
				echo "0" > /sys/class/lcd/panel/power_reduce;
			fi;
		fi;

		# USB power support
		for i in `ls /sys/bus/usb/devices/*/power/level`; do
			chmod 777 $i;
			echo "auto" > $i;
		done;
		for i in `ls /sys/bus/usb/devices/*/power/autosuspend`; do
			chmod 777 $i;
			echo "1" > $i;
		done;

		# BUS power support
		buslist="spi i2c sdio";
		for bus in $buslist; do
			for i in `ls /sys/bus/$bus/devices/*/power/control`; do
				chmod 777 $i;
				echo "auto" > $i;
			done;
		done;

		log -p i -t $FILE_NAME "*** BATTERY_TWEAKS ***: enabled";
	fi;
}
BATTERY_TWEAKS;

# ==============================================================
# CPU-TWEAKS
# ==============================================================

MEGA_BOOST_CPU_TWEAKS()
{
	if [ "$cortexbrain_cpu" == on ]; then
		SYSTEM_GOVERNOR=`cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor`;
	
		# boost CPU power for fast and no lag wakeup.
		echo "20000" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/sampling_rate;
		if [ -e /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/cpu_up_rate ]; then
			echo "10" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/cpu_up_rate;
			echo "10" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/cpu_down_rate;
		fi;
		if [ -e /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/down_threshold ]; then
			echo "10" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/down_threshold;
		fi;
		echo "40" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/up_threshold;
		if [ -e /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/up_threshold_min_freq ]; then
			echo "20" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/up_threshold_min_freq;
		fi;
		if [ -e /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/freq_step ]; then
			echo "100" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/freq_step;
		fi;
		if [ -e /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/freq_responsiveness ]; then
			echo "800000" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/freq_responsiveness;
		fi;

		# bus freq to 400MHZ in low load
		echo "20" > /sys/devices/system/cpu/cpufreq/busfreq_up_threshold;

		# GPU utilization to min delay
		echo "100" > /sys/module/mali/parameters/mali_gpu_utilization_timeout;

		# cpu-settings for second core online at booster time
		echo "15" > /sys/module/stand_hotplug/parameters/load_h0;
		echo "15" > /sys/module/stand_hotplug/parameters/load_l1;

		# boost wakeup
		if [ "$scaling_max_freq" \> 1000000 ]; then
			# powering MAX FREQ
			echo "$scaling_max_freq" > /sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq;
		else
			# powering MAX FREQ
			echo "1000000" > /sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq;
		fi;
		# powering MIN FREQ
		echo "1000000" > /sys/devices/system/cpu/cpu0/cpufreq/scaling_min_freq;

		log -p i -t $FILE_NAME "*** MEGA_BOOST_CPU_TWEAKS Mode ***";
	fi;
}

CPU_GOV_TWEAKS()
{
	if [ "$cortexbrain_cpu" == on ]; then
		SYSTEM_GOVERNOR=`cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor`;

		# extra battery-settings
		if [ "$PROFILE" == extreme_battery ] || ([ "$PROFILE" == extreme_battery ] && [ "$sleep_power_save" == 1 ]); then

			echo "100000" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/sampling_rate;
			if [ -e /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/cpu_up_rate ]; then
				echo "$load_h0" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/cpu_up_rate;
				echo "$load_l1" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/cpu_down_rate;
			fi;
			echo "90" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/up_threshold;
			if [ -e /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/up_threshold_min_freq ]; then
				echo "90" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/up_threshold_min_freq;
			fi;
			if [ -e /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/down_threshold	]; then
				echo "60" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/down_threshold;
			fi;
			echo "1" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/sampling_down_factor;
			if [ -e /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/down_differential ]; then
				echo "5" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/down_differential;
			fi;
			if [ -e /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/freq_step ]; then
				echo "20" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/freq_step;
			fi;
			if [ -e /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/freq_responsiveness ]; then
				echo "200000" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/freq_responsiveness;
			fi;

			if [ "$SYSTEM_GOVERNOR" == pegasusq ]; then
				echo "300000" > /sys/devices/system/cpu/cpufreq/pegasusq/hotplug_freq_1_1;
				echo "200000" > /sys/devices/system/cpu/cpufreq/pegasusq/hotplug_freq_2_0;
				echo "250" > /sys/devices/system/cpu/cpufreq/pegasusq/hotplug_rq_1_1;
				echo "240" > /sys/devices/system/cpu/cpufreq/pegasusq/hotplug_rq_2_0;
				echo "$max_cpu_lock" > /sys/devices/system/cpu/cpufreq/pegasusq/max_cpu_lock;
				echo "0" > /sys/devices/system/cpu/cpufreq/pegasusq/dvfs debug;
				echo "0" > /sys/devices/system/cpu/cpufreq/pegasusq/hotplug_lock;
			fi;

		# battery-settings
		elif [ "$PROFILE" == battery ] || [ "$sleep_power_save" == 1 ]; then

			echo "80000" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/sampling_rate;
			if [ -e /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/cpu_up_rate ]; then
				echo "$load_h0" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/cpu_up_rate;
				echo "$load_l1" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/cpu_down_rate;
			fi;
			echo "85" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/up_threshold;
			if [ -e /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/up_threshold_min_freq ]; then
				echo "85" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/up_threshold_min_freq;
			fi;
			if [ -e /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/down_threshold ]; then
				echo "60" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/down_threshold;
			fi;
			echo "1" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/sampling_down_factor;
			if [ -e /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/down_differential ]; then
				echo "5" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/down_differential;
			fi;
			if [ -e /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/freq_step ]; then
				echo "20" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/freq_step;
			fi;
			if [ -e /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/freq_responsiveness ]; then
				echo "200000" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/freq_responsiveness;
			fi;

			if [ "$SYSTEM_GOVERNOR" == pegasusq ]; then
				echo "400000" > /sys/devices/system/cpu/cpufreq/pegasusq/hotplug_freq_1_1;
				echo "200000" > /sys/devices/system/cpu/cpufreq/pegasusq/hotplug_freq_2_0;
				echo "250" > /sys/devices/system/cpu/cpufreq/pegasusq/hotplug_rq_1_1;
				echo "240" > /sys/devices/system/cpu/cpufreq/pegasusq/hotplug_rq_2_0;
				echo "$max_cpu_lock" > /sys/devices/system/cpu/cpufreq/pegasusq/max_cpu_lock;
				echo "0" > /sys/devices/system/cpu/cpufreq/pegasusq/dvfs debug;
				echo "0" > /sys/devices/system/cpu/cpufreq/pegasusq/hotplug_lock;
			fi;

		# default-settings
		elif [ "$PROFILE" == default ]; then

			echo "70000" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/sampling_rate;
			if [ -e /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/cpu_up_rate ]; then
				echo "$load_h0" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/cpu_up_rate;
				echo "$load_l1" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/cpu_down_rate;
			fi;
			echo "80" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/up_threshold;
			if [ -e /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/up_threshold_min_freq ]; then
				echo "70" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/up_threshold_min_freq;
			fi;
			if [ -e /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/down_threshold ]; then
				echo "40" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/down_threshold;
			fi;
			echo "1" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/sampling_down_factor;
			if [ -e /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/down_differential ]; then
				echo "5" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/down_differential;
			fi;
			if [ -e /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/freq_step ]; then
				echo "30" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/freq_step;
			fi;
			if [ -e /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/freq_responsiveness ]; then
				echo "200000" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/freq_responsiveness;
			fi;

			if [ "$SYSTEM_GOVERNOR" == pegasusq ]; then
				echo "500000" > /sys/devices/system/cpu/cpufreq/pegasusq/hotplug_freq_1_1;
				echo "200000" > /sys/devices/system/cpu/cpufreq/pegasusq/hotplug_freq_2_0;
				echo "250" > /sys/devices/system/cpu/cpufreq/pegasusq/hotplug_rq_1_1;
				echo "240" > /sys/devices/system/cpu/cpufreq/pegasusq/hotplug_rq_2_0;
				echo "$max_cpu_lock" > /sys/devices/system/cpu/cpufreq/pegasusq/max_cpu_lock;
				echo "0" > /sys/devices/system/cpu/cpufreq/pegasusq/dvfs debug;
				echo "0" > /sys/devices/system/cpu/cpufreq/pegasusq/hotplug_lock;
			fi;

		# performance-settings		
		elif [ "$PROFILE" == performance ] || [ "$PROFILE" == extreme_performance ]; then

			echo "50000" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/sampling_rate;
			if [ -e /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/cpu_up_rate ]; then
				echo "$load_h0" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/cpu_up_rate;
				echo "$load_l1" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/cpu_down_rate;
			fi;
			echo "60" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/up_threshold;
			if [ -e /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/up_threshold_min_freq ]; then
				echo "60" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/up_threshold_min_freq;
			fi;
			if [ -e /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/down_threshold ]; then
				echo "20" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/down_threshold;
			fi;
			echo "1" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/sampling_down_factor;
			if [ -e /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/down_differential ]; then
				echo "5" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/down_differential;
			fi;
			if [ -e /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/freq_step ]; then
				echo "40" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/freq_step;
			fi;
			if [ -e /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/freq_responsiveness ]; then
				echo "200000" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/freq_responsiveness;
			fi;

			if [ "$SYSTEM_GOVERNOR" == conservative ]; then
				echo "50" > /sys/devices/system/cpu/cpufreq/conservative/freq_step;
			fi;

			if [ "$SYSTEM_GOVERNOR" == pegasusq ]; then
				echo "600000" > /sys/devices/system/cpu/cpufreq/pegasusq/hotplug_freq_1_1;
				echo "200000" > /sys/devices/system/cpu/cpufreq/pegasusq/hotplug_freq_2_0;
				echo "250" > /sys/devices/system/cpu/cpufreq/pegasusq/hotplug_rq_1_1;
				echo "240" > /sys/devices/system/cpu/cpufreq/pegasusq/hotplug_rq_2_0;
				echo "$max_cpu_lock" > /sys/devices/system/cpu/cpufreq/pegasusq/max_cpu_lock;
				echo "0" > /sys/devices/system/cpu/cpufreq/pegasusq/dvfs debug;
				echo "0" > /sys/devices/system/cpu/cpufreq/pegasusq/hotplug_lock;
			fi;
		fi;

		log -p i -t $FILE_NAME "*** CPU_GOV_TWEAKS ***: enabled";
	fi;
}
sleep_power_save=0;
CPU_GOV_TWEAKS;

# ==============================================================
# MEMORY-TWEAKS
# ==============================================================
MEMORY_TWEAKS()
{
	if [ "$cortexbrain_memory" == on ]; then
		echo "$dirty_expire_centisecs_default" > /proc/sys/vm/dirty_expire_centisecs;
		echo "$dirty_writeback_centisecs_default" > /proc/sys/vm/dirty_writeback_centisecs;
		echo "15" > /proc/sys/vm/dirty_background_ratio; # default: 10
		echo "15" > /proc/sys/vm/dirty_ratio; # default: 20
		echo "4" > /proc/sys/vm/min_free_order_shift; # default: 4
		echo "0" > /proc/sys/vm/overcommit_memory; # default: 0
		echo "1000" > /proc/sys/vm/overcommit_ratio; # default: 50
		echo "128 128" > /proc/sys/vm/lowmem_reserve_ratio;
		echo "3" > /proc/sys/vm/page-cluster; # default: 3
		echo "8192" > /proc/sys/vm/min_free_kbytes;

		log -p i -t $FILE_NAME "*** MEMORY_TWEAKS ***: enabled";
	fi;
}
MEMORY_TWEAKS;

# ==============================================================
# TCP-TWEAKS
# ==============================================================
TCP_TWEAKS()
{
	if [ "$cortexbrain_tcp" == on ]; then
		echo "0" > /proc/sys/net/ipv4/tcp_timestamps;
		echo "1" > /proc/sys/net/ipv4/tcp_tw_reuse;
		echo "1" > /proc/sys/net/ipv4/tcp_sack;
		echo "1" > /proc/sys/net/ipv4/tcp_tw_recycle;
		echo "1" > /proc/sys/net/ipv4/tcp_window_scaling;
		echo "1" > /proc/sys/net/ipv4/tcp_moderate_rcvbuf;
		echo "1" > /proc/sys/net/ipv4/route/flush;
		echo "2" > /proc/sys/net/ipv4/tcp_syn_retries;
		echo "2" > /proc/sys/net/ipv4/tcp_synack_retries;
		echo "10" > /proc/sys/net/ipv4/tcp_fin_timeout;
		echo "0" > /proc/sys/net/ipv4/tcp_ecn;
		echo "262144" > /proc/sys/net/core/wmem_max;
		echo "524288" > /proc/sys/net/core/rmem_max;
		echo "262144" > /proc/sys/net/core/rmem_default;
		echo "262144" > /proc/sys/net/core/wmem_default;
		echo "20480" > /proc/sys/net/core/optmem_max;
		echo "4096 16384 262144" > /proc/sys/net/ipv4/tcp_wmem;
		echo "4096 87380 524288" > /proc/sys/net/ipv4/tcp_rmem;
		echo "4096" > /proc/sys/net/ipv4/udp_rmem_min;
		echo "4096" > /proc/sys/net/ipv4/udp_wmem_min;

		log -p i -t $FILE_NAME "*** TCP_TWEAKS ***: enabled";
	fi;
}
TCP_TWEAKS;

# ==============================================================
# FIREWALL-TWEAKS
# ==============================================================
FIREWALL_TWEAKS()
{
	if [ "$cortexbrain_firewall" == on ]; then
		# ping/icmp protection
		echo "1" > /proc/sys/net/ipv4/icmp_echo_ignore_broadcasts;
		echo "1" > /proc/sys/net/ipv4/icmp_echo_ignore_all;
		echo "1" > /proc/sys/net/ipv4/icmp_ignore_bogus_error_responses;

		# drop spoof, redirects, etc
		#echo "1" > /proc/sys/net/ipv4/conf/all/rp_filter;
		#echo "1" > /proc/sys/net/ipv4/conf/default/rp_filter;
		#echo "0" > /proc/sys/net/ipv4/conf/all/send_redirects;
		#echo "0" > /proc/sys/net/ipv4/conf/default/send_redirects;
		#echo "0" > /proc/sys/net/ipv4/conf/default/accept_redirects;
		#echo "0" > /proc/sys/net/ipv4/conf/all/accept_source_route;
		#echo "0" > /proc/sys/net/ipv4/conf/default/accept_source_route;

		log -p i -t $FILE_NAME "*** FIREWALL_TWEAKS ***: enabled";
	fi;
}
FIREWALL_TWEAKS;

DISABLE_WIFI()
{
	# disable WIFI-driver if screen is off
	if [ -e /sys/module/dhd/initstate ]; then
		if [ "$cortexbrain_auto_tweak_wifi" == on ]; then
			svc wifi disable;
			WIFI_STATE=1;
		fi;
		log -p i -t $FILE_NAME "*** DISABLE_WIFI Mode ***";
	else
		WIFI_STATE=0;
	fi;
}

ENABLE_WIFI()
{
	# enable WIFI-driver if screen is on
	if [ "$WIFI_STATE" == 1 ]; then
		if [ "$cortexbrain_auto_tweak_wifi" == on ]; then
			svc wifi enable;
		fi;
		log -p i -t $FILE_NAME "*** ENABLE_WIFI Mode ***";
	fi;
}

ENABLE_WIFI_PM()
{
	if [ "$wifi_pwr" == on ]; then
		# WIFI PM-FAST support
		if [ -e /sys/module/dhd/parameters/wifi_pm ]; then
			echo "1" > /sys/module/dhd/parameters/wifi_pm;
		fi;
		log -p i -t $FILE_NAME "*** ENABLE_WIFI_PM Mode ***";
	fi;
}

DISABLE_WIFI_PM()
{
	# WIFI PM-MAX support
	if [ -e /sys/module/dhd/parameters/wifi_pm ]; then
		echo "0" > /sys/module/dhd/parameters/wifi_pm;
		log -p i -t $FILE_NAME "*** DISABLE_WIFI_PM Mode ***";
	fi;
}

ENABLE_LOGGER()
{
	# load logger if needed
	if [ "$android_logger" == auto ] || [ "$android_logger" == debug ]; then
		if [ -e /dev/log-sleep ] && [ ! -e /dev/log ]; then
			mv /dev/log-sleep/ /dev/log/
			log -p i -t $FILE_NAME "*** ENABLE_LOGGER Mode ***";
		fi;
	fi;
}

DISABLE_LOGGER()
{
	# android logger process control
	if [ "$android_logger" == auto ] || [ "$android_logger" == disabled ]; then
		if [ -e /dev/log ]; then
			mv /dev/log/ /dev/log-sleep/;
			log -p i -t $FILE_NAME "*** DISABLE_LOGGER Mode ***";
		fi;
	fi;
}

ENABLE_GESTURE()
{
	if [ "$gesture_tweak" == on ]; then
		# enable gestures code
		echo "1" > /sys/devices/virtual/misc/touch_gestures/gestures_enabled;
		pkill -f "/data/gesture_set.sh";
		pkill -f "/sys/devices/virtual/misc/touch_gestures/wait_for_gesture";
		/sbin/busybox sh /data/gesture_set.sh;
		log -p i -t $FILE_NAME "*** ENABLE_GESTURE Mode ***";
	fi;
}

DISABLE_GESTURE()
{
	if [ `pgrep -f "/data/gesture_set.sh" | wc -l` != "0" ] || [ `pgrep -f "/sys/devices/virtual/misc/touch_gestures/wait_for_gesture" | wc -l` != "0" ] || [ "$gesture_tweak" == off ]; then
		# shutdown gestures loop on screen off, we dont need it
		pkill -f "/data/gesture_set.sh";
		pkill -f "/sys/devices/virtual/misc/touch_gestures/wait_for_gesture";
		# disable gestures code
		echo "0" > /sys/devices/virtual/misc/touch_gestures/gestures_enabled;
	else
		echo "0" > /sys/devices/virtual/misc/touch_gestures/gestures_enabled;
	fi;

	log -p i -t $FILE_NAME "*** DISABLE_GESTURE Mode ***";
}

DONT_KILL_CORTEX()
{
	# please don't kill "cortexbrain"
	PIDOFCORTEX=`pgrep -f "/sbin/ext/cortexbrain-tune.sh"`;
	for i in $PIDOFCORTEX; do
		echo "-600" > /proc/${i}/oom_score_adj;
	done;

	log -p i -t $FILE_NAME "*** DONT_KILL_CORTEX Mode ***";
}

MOUNT_SD_CARD()
{
	# mount sdcard and emmc is usb mass storage is used.
	echo "/dev/block/vold/259:3" > /sys/devices/virtual/android_usb/android0/f_mass_storage/lun0/file;

	if [ -e /dev/block/vold/179:25 ]; then
		echo "/dev/block/vold/179:25" > /sys/devices/virtual/android_usb/android0/f_mass_storage/lun1/file;
	fi;

	log -p i -t $FILE_NAME "*** MOUNT_SD_CARD Mode ***";
}

WAKEUP_BOOST()
{
	# check if ROM booting now, if yes, dont wait. creation and deletion of /data/.siyah/booting @> /sbin/ext/post-init.sh
	if [ ! -e /data/.siyah/booting ] && [ "$wakeup_boost" != 0 ]; then
		log -p i -t $FILE_NAME "*** WAKEUP_BOOST ${wakeup_boost}sec Mode ***";
		sleep $wakeup_boost;
	fi;
}

WAKEUP_DELAY()
{
	# set wakeup booster delay to prevent mp3 music shattering when screen turned ON.
	if [ "$wakeup_delay" != 0 ] && [ ! -e /data/.siyah/booting ]; then
		log -p i -t $FILE_NAME "*** WAKEUP_DELAY ${wakeup_delay}sec Mode ***";
		sleep $wakeup_delay
	fi;
}

WAKEUP_DELAY_SLEEP()
{
	if [ "$wakeup_delay" != 0 ] && [ ! -e /data/.siyah/booting ]; then
		log -p i -t $FILE_NAME "*** WAKEUP_DELAY_SLEEP ${wakeup_delay}sec Mode ***";
		sleep $wakeup_delay;
	else
		log -p i -t $FILE_NAME "*** WAKEUP_DELAY_SLEEP 3sec Mode ***";
		sleep 3;
	fi;
}

AUTO_BRIGHTNESS()
{
	# auto set brightness
	if [ "$cortexbrain_auto_tweak_brightness" == on ]; then
		LEVEL=`cat /sys/class/power_supply/battery/capacity`;
		MAX_BRIGHTNESS=`cat /sys/class/backlight/panel/max_brightness`;
		OLD_BRIGHTNESS=`cat /sys/class/backlight/panel/brightness`;
		NEW_BRIGHTNESS=`$(( MAX_BRIGHTNESS*LEVEL/100 ))`;
		if [ "$NEW_BRIGHTNESS" -le "$OLD_BRIGHTNESS" ]; then
			echo "$NEW_BRIGHTNESS" > /sys/class/backlight/panel/brightness;
		fi;
		log -p i -t $FILE_NAME "*** AUTO_BRIGHTNESS Mode ***";
	fi;
}

SWAPPINESS()
{
	# set swappiness in case that no root installed, and zram used or disk swap used
	SWAP_CHECK=`free | grep Swap | awk '{ print $2 }'`;
	if [ "$zramtweaks" == 4 ] || [ "$SWAP_CHECK" == 0 ]; then
		echo "0" > /proc/sys/vm/swappiness;
		log -p i -t $FILE_NAME "*** SWAPPINESS Mode OFF ***";
	else
		TOTAL_MEM=$(grep MemTotal /proc/meminfo | awk '{ print $2 }');
		USED_MEM=$(grep AnonPages /proc/meminfo | awk '{ print $2 }');
		RESULT_FOR_SWAPPINESS=$(($USED_MEM*100/$TOTAL_MEM));
		echo "$RESULT_FOR_SWAPPINESS" > /proc/sys/vm/swappiness;
		log -p i -t $FILE_NAME "*** SWAPPINESS Mode ON ***";
	fi;
}

TUNE_IPV6()
{
	if [ "$cortexbrain_ipv6" == on ]; then
		echo "0" > /proc/sys/net/ipv6/conf/wlan0/disable_ipv6;
		sysctl -w net.ipv6.conf.all.disable_ipv6=0
		log -p i -t $FILE_NAME "*** TUNE_IPV6 Mode ON ***";
	else
		echo "1" > /proc/sys/net/ipv6/conf/wlan0/disable_ipv6;
		sysctl -w net.ipv6.conf.all.disable_ipv6=1
		log -p i -t $FILE_NAME "*** TUNE_IPV6 Mode OFF ***";
	fi;
}

KERNEL_SCHED_AWAKE()
{
	echo "10000000" > /proc/sys/kernel/sched_latency_ns;
	echo "2000000" > /proc/sys/kernel/sched_wakeup_granularity_ns;
	echo "1500000" > /proc/sys/kernel/sched_min_granularity_ns;

	log -p i -t $FILE_NAME "*** KERNEL_SCHED_AWAKE Mode ***";
}

KERNEL_SCHED_SLEEP()
{
	echo "20000000" > /proc/sys/kernel/sched_latency_ns;
	echo "3000000" > /proc/sys/kernel/sched_wakeup_granularity_ns;
	echo "2500000" > /proc/sys/kernel/sched_min_granularity_ns;

	log -p i -t $FILE_NAME "*** KERNEL_SCHED_SLEEP Mode ***";
}

# ==============================================================
# TWEAKS: if Screen-ON
# ==============================================================
AWAKE_MODE()
{
	# load all stweaks user settings.
	PROFILE=`cat /data/.siyah/.active.profile`;
	. /data/.siyah/$PROFILE.profile;

	WAKEUP_DELAY;

	# set default values
	echo "$dirty_expire_centisecs_default" > /proc/sys/vm/dirty_expire_centisecs;
	echo "$dirty_writeback_centisecs_default" > /proc/sys/vm/dirty_writeback_centisecs;

	# set I/O-Scheduler
	echo "$scheduler" > /sys/block/mmcblk0/queue/scheduler;
	echo "$scheduler" > /sys/block/mmcblk1/queue/scheduler;

	# set CPU-Governor
	echo "$scaling_governor" > /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor;

	echo "100" > /proc/sys/vm/vfs_cache_pressure; # default: 100

	KERNEL_SCHED_AWAKE;

	MEGA_BOOST_CPU_TWEAKS;

	MOUNT_SD_CARD;

	ENABLE_GESTURE;

	DISABLE_WIFI_PM;

	TUNE_IPV6;

	ENABLE_WIFI;

	WAKEUP_BOOST;

	# activate VPLL after wakeup booster delay
	if [ "$mali_use_vpll" == on ]; then
		echo "1" > /sys/module/mali/parameters/mali_use_vpll;
	fi;

	# bus freq back to normal
	echo "$busfreq_up_threshold" > /sys/devices/system/cpu/cpufreq/busfreq_up_threshold;

	# set CPU-Tweak
	sleep_power_save=0;
	CPU_GOV_TWEAKS;

	# cpu-settings for second core
	echo "$load_h0" > /sys/module/stand_hotplug/parameters/load_h0;
	echo "$load_l1" > /sys/module/stand_hotplug/parameters/load_l1;

	# set CPU speed
	echo "$scaling_min_freq" > /sys/devices/system/cpu/cpu0/cpufreq/scaling_min_freq;
	echo "$scaling_max_freq" > /sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq;
	echo "$mali_gpu_utilization_timeout" > /sys/module/mali/parameters/mali_gpu_utilization_timeout;

	DONT_KILL_CORTEX;

	# set wifi.supplicant_scan_interval
	setprop wifi.supplicant_scan_interval $supplicant_scan_interval;

	# enable NMI Watchdog to detect hangs
	if [ -e /proc/sys/kernel/nmi_watchdog ]; then
		echo "1" > /proc/sys/kernel/nmi_watchdog;
	fi;

	# fs settings 
	echo "25" > /proc/sys/vm/vfs_cache_pressure;

	# set the vibrator - force in case it's has been reseted
	echo "$pwm_val" > /sys/vibrator/pwm_val;

	AUTO_BRIGHTNESS;

	BATTERY_TWEAKS;

	ENABLE_LOGGER;

	SWAPPINESS;

	log -p i -t $FILE_NAME "*** AWAKE Normal Mode ***";
}

# ==============================================================
# TWEAKS: if Screen-OFF
# ==============================================================
SLEEP_MODE()
{
	PROFILE=`cat /data/.siyah/.active.profile`;
	. /data/.siyah/$PROFILE.profile;

	WAKEUP_DELAY_SLEEP;

	echo "$standby_freq" > /sys/devices/system/cpu/cpu0/cpufreq/scaling_min_freq;
	echo "500" > /sys/module/mali/parameters/mali_gpu_utilization_timeout;
	echo "0" > /sys/module/mali/parameters/mali_use_vpll;

	KERNEL_SCHED_SLEEP;

	DISABLE_GESTURE;

	TUNE_IPV6;

	BATTERY_TWEAKS;

	CHARGING=`cat /sys/class/power_supply/battery/charging_source`;
	if [ $CHARGING == 0 ]; then

		ENABLE_WIFI_PM;

		# set CPU-Governor
		echo "$deep_sleep" > /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor;

		# reduce deepsleep CPU speed, SUSPEND mode
		echo "$scaling_min_suspend_freq" > /sys/devices/system/cpu/cpu0/cpufreq/scaling_min_suspend_freq;
		echo "$scaling_max_suspend_freq" > /sys/devices/system/cpu/cpu0/cpufreq/scaling_max_suspend_freq;
		echo "$scaling_max_suspend_freq" > /sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq;

		# bus freq to min 133Mhz
		echo "90" > /sys/devices/system/cpu/cpufreq/busfreq_up_threshold;

		# set CPU-Tweak
		sleep_power_save=1;
		CPU_GOV_TWEAKS;

		# set disk I/O sched to noop simple and battery saving.
		echo "$sleep_scheduler" > /sys/block/mmcblk0/queue/scheduler;
		echo "$sleep_scheduler" > /sys/block/mmcblk1/queue/scheduler;

		# cpu-settings for second core
		echo "50" > /sys/module/stand_hotplug/parameters/load_h0;
		echo "50" > /sys/module/stand_hotplug/parameters/load_l1;

		# set wifi.supplicant_scan_interval
		if [ "$supplicant_scan_interval" \< 180 ]; then
			setprop wifi.supplicant_scan_interval 360;
		fi;

		# set settings for battery -> don't wake up "pdflush daemon"
		echo "$dirty_expire_centisecs_battery" > /proc/sys/vm/dirty_expire_centisecs;
		echo "$dirty_writeback_centisecs_battery" > /proc/sys/vm/dirty_writeback_centisecs;

		# disable NMI Watchdog to detect hangs
		if [ -e /proc/sys/kernel/nmi_watchdog ]; then
			echo "0" > /proc/sys/kernel/nmi_watchdog;
		fi;

		# set battery value
		echo "10" > /proc/sys/vm/vfs_cache_pressure; # default: 100

		DISABLE_WIFI;

		SWAPPINESS;

		log -p i -t $FILE_NAME "*** SLEEP mode ***";

		DISABLE_LOGGER;
	else
		echo "USB CABLE CONNECTED! No real sleep mode!"
		log -p i -t $FILE_NAME "*** SCREEN OFF BUT POWERED mode ***";
	fi;
}

# ==============================================================
# Background process to check screen state
# ==============================================================

# Dynamic value do not change/delete
cortexbrain_background_process=1;

if [ "$cortexbrain_background_process" == 1 ] && [ `pgrep -f "cat /sys/power/wait_for_fb_sleep" | wc -l` == 0 ] && [ `pgrep -f "cat /sys/power/wait_for_fb_wake" | wc -l` == 0 ]; then
	(while [ 1 ]; do
		# AWAKE State. all system ON.
		cat /sys/power/wait_for_fb_wake > /dev/null 2>&1;
		AWAKE_MODE;
		sleep 10;

		# SLEEP state. All system to power save.
		cat /sys/power/wait_for_fb_sleep > /dev/null 2>&1;
		SLEEP_MODE;
		sleep 2
	done &);
else
	if [ "$cortexbrain_background_process" == 0 ]; then
		echo "Cortex background disabled!"
	else
		echo "Cortex background process already running!";
	fi;
fi;

# ==============================================================
# Logic Explanations
#
# This script will manipulate all the system / cpu / battery behavior
# Based on chosen STWEAKS profile+tweaks and based on SCREEN ON/OFF state.
#
# When User select battery/default profile all tuning will be toward battery save.
# But user loose performance -20% and get more stable system and more battery left.
#
# When user select performance profile, tuning will be to max performance on screen ON.
# When screen OFF all tuning switched to max power saving. as with battery profile,
# So user gets max performance and max battery save but only on screen OFF.
#
# This script change governors and tuning for them on the fly.
# Also switch on/off hotplug CPU core based on screen on/off.
# This script reset battery stats when battery is 100% charged.
# This script tune Network and System VM settings and ROM settings tuning.
# This script changing default MOUNT options and I/O tweaks for all flash disks and ZRAM.
#
# TODO: add more description, explanations & default vaules ...
#
