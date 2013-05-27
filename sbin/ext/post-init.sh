#!/sbin/busybox sh

BB=/sbin/busybox

# first mod the partitions then boot
$BB sh /sbin/ext/system_tune_on_init.sh;

# oom and mem perm fix, we have auto adj code, do not allow changes in adj
$BB chmod 777 /sys/module/lowmemorykiller/parameters/cost;
$BB chmod 444 /sys/module/lowmemorykiller/parameters/adj;
$BB chmod 777 /proc/sys/vm/mmap_min_addr;

# set default JB mmap_min_addr value
echo "32768" > /proc/sys/vm/mmap_min_addr;

# protect init from oom
echo "-1000" > /proc/1/oom_score_adj; # -1000 = -17

PIDOFINIT=`pgrep -f "/sbin/ext/post-init.sh"`;
for i in $PIDOFINIT; do
	echo "-600" > /proc/${i}/oom_score_adj;
done;

if [ ! -d /data/.siyah ]; then
	$BB mkdir -p /data/.siyah;
fi;

# reset config-backup-restore
if [ -f /data/.siyah/restore_running ]; then
	rm -f /data/.siyah/restore_running;
fi;

ccxmlsum=`md5sum /res/customconfig/customconfig.xml | awk '{print $1}'`
if [ "a$ccxmlsum" != "a`cat /data/.siyah/.ccxmlsum`" ]; then
	rm -f /data/.siyah/*.profile;
	echo "$ccxmlsum" > /data/.siyah/.ccxmlsum;
fi;

[ ! -f /data/.siyah/default.profile ] && cp -a /res/customconfig/default.profile /data/.siyah/default.profile;
[ ! -f /data/.siyah/battery.profile ] && cp -a /res/customconfig/battery.profile /data/.siyah/battery.profile;
[ ! -f /data/.siyah/performance.profile ] && cp -a /res/customconfig/performance.profile /data/.siyah/performance.profile;
[ ! -f /data/.siyah/extreme_performance.profile ] && cp -a /res/customconfig/extreme_performance.profile /data/.siyah/extreme_performance.profile;
[ ! -f /data/.siyah/extreme_battery.profile ] && cp -a /res/customconfig/extreme_battery.profile /data/.siyah/extreme_battery.profile;

$BB chmod -R 0777 /data/.siyah/;

. /res/customconfig/customconfig-helper;
read_defaults;
read_config;

# HACK: we have problem on boot with stuck service GoogleBackupTransport if many apps installed
# here i will rename the GoogleBackupTransport.apk to boot without it and then restore to prevent
# system not responding popup on after boot.
if [ -e /data/dalvik-cache/not_first_boot ]; then
	mount -o remount,rw /system;
	mv /system/app/GoogleBackupTransport.apk /system/app/GoogleBackupTransport.apk.off
fi;

# custom boot booster stage 1
echo "$boot_boost" > /sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq;

# mdnie sharpness tweak
if [ "$mdniemod" == "on" ]; then
	$BB sh /sbin/ext/mdnie-sharpness-tweak.sh;
fi;

# STweaks check su only at /system/xbin/su make it so
if [ -e /system/xbin/su ]; then
	echo "root for STweaks found";
elif [ -e /system/bin/su ]; then
	cp /system/bin/su /system/xbin/su;
	chmod 6755 /system/xbin/su;
else
	echo "ROM without ROOT";
fi;

######################################
# Loading Modules
######################################
$BB chmod -R 755 /lib;

(
	sleep 50;
	# order of modules load is important
#	$BB insmod /lib/modules/j4fs.ko;
#	$BB mount -t j4fs /dev/block/mmcblk0p4 /mnt/.lfs
	$BB insmod /lib/modules/Si4709_driver.ko;

	if [ "$usbserial_module" == "on" ]; then
		$BB insmod /lib/modules/usbserial.ko;
		$BB insmod /lib/modules/ftdi_sio.ko;
		$BB insmod /lib/modules/pl2303.ko;
	fi;
	if [ "$usbnet_module" == "on" ]; then
		$BB insmod /lib/modules/usbnet.ko;
		$BB insmod /lib/modules/asix.ko;
	fi;
	if [ "$cifs_module" == "on" ]; then
		$BB insmod /lib/modules/cifs.ko;
	fi;
	if [ "$eds_module" == "on" ]; then
		$BB insmod /lib/modules/eds.ko;
	fi;
)&

# some nice thing for dev
$BB ln -s /sys/devices/system/cpu/cpu0/cpufreq /cpufreq;
$BB ln -s /sys/devices/system/cpu/cpufreq/ /cpugov;

# enable kmem interface for everyone by GM
echo "0" > /proc/sys/kernel/kptr_restrict;

# Cortex parent should be ROOT/INIT and not STweaks
nohup /sbin/ext/cortexbrain-tune.sh;

# enable screen color mode
echo "1" > /sys/devices/platform/samsung-pd.2/mdnie/mdnie/mdnie/user_mode;

# create init.d folder if missing
if [ ! -d /system/etc/init.d ]; then
	mkdir -p /system/etc/init.d/
	$BB chmod 755 /system/etc/init.d/;
fi;

(
	MIUI_JB=0;
	[ "`$BB grep -i cMIUI /system/build.prop`" ] && MIUI_JB=1;

	if [ $init_d == on ] || [ "$MIUI_JB" == 1 ]; then
		$BB sh /sbin/ext/run-init-scripts.sh;
	fi;
)&

# disable debugging on some modules
if [ "$logger" == "off" ]; then
	echo "0" > /sys/module/ump/parameters/ump_debug_level;
	echo "0" > /sys/module/mali/parameters/mali_debug_level;
	echo "0" > /sys/module/kernel/parameters/initcall_debug;
#	echo "0" > /sys/module/lowmemorykiller/parameters/debug_level;
	echo "0" > /sys/module/cpuidle_exynos4/parameters/log_en;
	echo "0" > /sys/module/earlysuspend/parameters/debug_mask;
	echo "0" > /sys/module/alarm/parameters/debug_mask;
	echo "0" > /sys/module/alarm_dev/parameters/debug_mask;
	echo "0" > /sys/module/binder/parameters/debug_mask;
	echo "0" > /sys/module/xt_qtaguid/parameters/debug_mask;
fi;

# for ntfs automounting
mount -t tmpfs -o mode=0777,gid=1000 tmpfs /mnt/ntfs

$BB sh /sbin/ext/properties.sh;

(
	# Apps Install
	$BB sh /sbin/ext/install.sh;

	# EFS Backup
	$BB sh /sbin/ext/efs-backup.sh;
)&

echo "0" > /tmp/uci_done;
chmod 666 /tmp/uci_done;

(
	# custom boot booster
	COUNTER=0;
	while [ "`cat /tmp/uci_done`" != "1" ]; do
		if [ "$COUNTER" -ge "10" ]; then
			break;
		fi;
		echo "$boot_boost" > /sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq;
		echo "800000" > /sys/devices/system/cpu/cpu0/cpufreq/scaling_min_freq;
		pkill -f "com.gokhanmoral.stweaks.app";
		echo "Waiting For UCI to finish";
		sleep 10;
		COUNTER=$(($COUNTER+1));
	done;

	# give home launcher, oom protection
	ACORE_APPS=`pgrep acore`;
	if [ "a$ACORE_APPS" != "a" ]; then
		for c in `pgrep acore`; do
			echo "-900" > /proc/${c}/oom_score_adj;
		done;
	fi;

	# Mount Sec/Pri ROM DATA on Boot, we need to wait till sdcard is mounted.
	if [ `cat /tmp/pri_rom_boot` == "1" ]; then
		if [ -e /sdcard/.secondrom/data.img ] || [ -e /storage/sdcard0/.secondrom/data.img ]; then
			mount -o remount,rw /
			mkdir /data_sec_rom;
			chmod 777 /data_sec_rom;
			FREE_LOOP=`losetup -f`;
			if [ -e /sdcard/.secondrom/data.img ]; then
				DATA_IMG=/sdcard/.secondrom/data.img
			elif [ -e /storage/sdcard0/.secondrom/data.img ]; then
				DATA_IMG=/storage/sdcard0/.secondrom/data.img
			fi;
			if [ "a$FREE_LOOP" == "a" ]; then
				mknod /dev/block/loop99 b 7 99
				FREE_LOOP=/dev/block/loop99
			fi;
			losetup $FREE_LOOP $DATA_IMG;
			mount -t ext4 $FREE_LOOP /data_sec_rom;
		else
			echo "no sec data image found! abort."
		fi;
	elif [ `cat /tmp/sec_rom_boot` == "1" ]; then
		mount -o remount,rw /
		mkdir /data_pri_rom;
		chmod 777 /data_pri_rom;
		mount -t ext4 /dev/block/mmcblk0p10 /data_pri_rom;
	fi;

	# restore normal freq
	echo "$scaling_min_freq" > /sys/devices/system/cpu/cpu0/cpufreq/scaling_min_freq;
	if [ "$scaling_max_freq" == "1000000" ] && [ "$scaling_max_freq_oc" -gt "1000000" ]; then
		echo "$scaling_max_freq_oc" > /sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq;
	else
		echo "$scaling_max_freq" > /sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq;
	fi;

	# HACK: restore GoogleBackupTransport.apk after boot.
	if [ -e /data/dalvik-cache/not_first_boot ]; then
		mv /system/app/GoogleBackupTransport.apk.off /system/app/GoogleBackupTransport.apk
	else
		touch /data/dalvik-cache/not_first_boot;
		chmod 777 /data/dalvik-cache/not_first_boot;
	fi;
)&

(
	# stop uci.sh from running all the PUSH Buttons in stweaks on boot
	$BB mount -o remount,rw rootfs;
	$BB chown -R root:system /res/customconfig/actions/;
	$BB chmod -R 6755 /res/customconfig/actions/;
	$BB mv /res/customconfig/actions/push-actions/* /res/no-push-on-boot/;
	$BB chmod 6755 /res/no-push-on-boot/*;

	# apply STweaks settings
	echo "booting" > /data/.siyah/booting;
	chmod 777 /data/.siyah/booting;
	pkill -f "com.gokhanmoral.stweaks.app";
	nohup $BB sh /res/uci.sh restore;
	echo "1" > /tmp/uci_done;

	# restore all the PUSH Button Actions back to there location
	$BB mount -o remount,rw rootfs;
	$BB mv /res/no-push-on-boot/* /res/customconfig/actions/push-actions/;
	pkill -f "com.gokhanmoral.stweaks.app";

	# change USB mode MTP or Mass Storage
	$BB sh /res/uci.sh usb-mode ${usb_mode};

	# update cpu tunig after profiles load
	$BB sh /sbin/ext/cortexbrain-tune.sh apply_cpu update > /dev/null;
	$BB rm -f /data/.siyah/booting;

	# ###############################################################
	# JB Low Sound Fix.
	# ###############################################################

	# JB Sound Bug fix, 3 push VOL DOWN, 4 push VOL UP. and sound is fixed.

	MIUI_JB=0;
	JELLY=0;
	[ "`$BB grep -i cMIUI /system/build.prop`" ] && MIUI_JB=1;
	[ -f /system/lib/ssl/engines/libkeystore.so ] && JELLY=1;
	if [ "$JELLY" == "1" ] || [ "$MIUI_JB" == "1" ]; then
		if [ "$jb_sound_fix" == "on" ]; then
			input keyevent 25
			input keyevent 25
			input keyevent 25
			input keyevent 24
			input keyevent 24
			input keyevent 24
			input keyevent 24
		fi;
	fi;

	# ###############################################################
	# I/O related tweaks
	# ###############################################################

	DM=`ls -d /sys/block/dm*`;
	for i in ${DM}; do
		if [ -e $i/queue/rotational ]; then
			echo "0" > ${i}/queue/rotational;
		fi;

		if [ -e $i/queue/iostats ]; then
			echo "0" > ${i}/queue/iostats;
		fi;
	done;

	mount -o remount,rw /system;
	mount -o remount,rw /;

	# correct touch keys light, if rom mess user configuration
	$BB sh /res/uci.sh generic /sys/class/misc/notification/led_timeout_ms $led_timeout_ms;

	# correct oom tuning, if changed by apps/rom
	$BB sh /res/uci.sh oom_config_screen_on $oom_config_screen_on;
	$BB sh /res/uci.sh oom_config_screen_off $oom_config_screen_off;

	echo "Done Booting" > /data/dm-boot-check;
	date >> /data/dm-boot-check;
)&

