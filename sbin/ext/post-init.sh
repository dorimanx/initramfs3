#!/sbin/busybox sh

BB=/sbin/busybox

# first mod the partitions then boot
$BB sh /sbin/ext/system_tune_on_init.sh;

# oom and mem perm fix, we have auto adj code, do not allow changes in adj
$BB chmod 777 /sys/module/lowmemorykiller/parameters/cost;
$BB chmod 444 /sys/module/lowmemorykiller/parameters/adj;
$BB chmod 777 /proc/sys/vm/mmap_min_addr;

# protect init from oom
echo "-1000" > /proc/1/oom_score_adj;

# set sysrq to 2 = enable control of console logging level as with CM-KERNEL
echo "2" > /proc/sys/kernel/sysrq;

PIDOFINIT=`pgrep -f "/sbin/ext/post-init.sh"`;
for i in $PIDOFINIT; do
	echo "-600" > /proc/${i}/oom_score_adj;
done;

if [ `cat /tmp/sec_rom_boot` -eq "1" ]; then
	$BB mount -o remount,rw,noauto_da_alloc,journal_async_commit,discard /data;
	$BB mount -o remount,rw,noauto_da_alloc,journal_async_commit,discard /efs;
fi;

# allow user and admin to use all free mem.
echo 0 > /proc/sys/vm/user_reserve_kbytes;
echo 0 > /proc/sys/vm/admin_reserve_kbytes;

if [ ! -d /data/.siyah ]; then
	$BB mkdir -p /data/.siyah;
fi;

# reset config-backup-restore
if [ -f /data/.siyah/restore_running ]; then
	rm -f /data/.siyah/restore_running;
fi;

#ccxmlsum=`md5sum /res/customconfig/customconfig.xml | awk '{print $1}'`
#if [ "a$ccxmlsum" != "a`cat /data/.siyah/.ccxmlsum`" ]; then
#	rm -f /data/.siyah/*.profile;
#	echo "$ccxmlsum" > /data/.siyah/.ccxmlsum;
#fi;

[ ! -f /data/.siyah/default.profile ] && cp -a /res/customconfig/default.profile /data/.siyah/default.profile;
[ ! -f /data/.siyah/battery.profile ] && cp -a /res/customconfig/battery.profile /data/.siyah/battery.profile;
[ ! -f /data/.siyah/performance.profile ] && cp -a /res/customconfig/performance.profile /data/.siyah/performance.profile;
[ ! -f /data/.siyah/extreme_performance.profile ] && cp -a /res/customconfig/extreme_performance.profile /data/.siyah/extreme_performance.profile;
[ ! -f /data/.siyah/extreme_battery.profile ] && cp -a /res/customconfig/extreme_battery.profile /data/.siyah/extreme_battery.profile;

$BB chmod -R 0777 /data/.siyah/;

. /res/customconfig/customconfig-helper;
read_defaults;
read_config;

# custom boot booster stage 1
echo "$boot_boost" > /sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq;

# mdnie sharpness tweak
if [ "$mdniemod" == "on" ]; then
	$BB sh /sbin/ext/mdnie-sharpness-tweak.sh;
fi;

# check cpu voltage group and report to tmp file, and set defaults for STweaks
dmesg | grep VDD_INT | cut -c 19-50 > /tmp/cpu-voltage_group;
chmod 777 /tmp/cpu-voltage_group;

VDD_INT=`cat /tmp/cpu-voltage_group | cut -c 24`;

if [ "$cpu_voltage_switch" == "off" ] && [ "$VDD_INT" != "3" ]; then
	if [ "$VDD_INT" -eq "1" ]; then
		$BB sh /res/uci.sh cpu-voltage 1 1475;
		$BB sh /res/uci.sh cpu-voltage 2 1450;
		$BB sh /res/uci.sh cpu-voltage 3 1400;
		$BB sh /res/uci.sh cpu-voltage 4 1375;
		$BB sh /res/uci.sh cpu-voltage 5 1350;
		$BB sh /res/uci.sh cpu-voltage 6 1300;
		$BB sh /res/uci.sh cpu-voltage 7 1250;
		$BB sh /res/uci.sh cpu-voltage 8 1175;
		$BB sh /res/uci.sh cpu-voltage 9 1150;
		$BB sh /res/uci.sh cpu-voltage 10 1100;
		$BB sh /res/uci.sh cpu-voltage 11 1075;
		$BB sh /res/uci.sh cpu-voltage 12 1050;
		$BB sh /res/uci.sh cpu-voltage 13 1250;
		$BB sh /res/uci.sh cpu-voltage 14 1250;
		$BB sh /res/uci.sh cpu-voltage 15 1000;
		$BB sh /res/uci.sh cpu-voltage 16 1000;
	elif [ "$VDD_INT" -eq "2" ]; then
		$BB sh /res/uci.sh cpu-voltage 1 1450;
		$BB sh /res/uci.sh cpu-voltage 2 1400;
		$BB sh /res/uci.sh cpu-voltage 3 1350;
		$BB sh /res/uci.sh cpu-voltage 4 1325;
		$BB sh /res/uci.sh cpu-voltage 5 1300;
		$BB sh /res/uci.sh cpu-voltage 6 1250;
		$BB sh /res/uci.sh cpu-voltage 7 1200;
		$BB sh /res/uci.sh cpu-voltage 8 1150;
		$BB sh /res/uci.sh cpu-voltage 9 1100;
		$BB sh /res/uci.sh cpu-voltage 10 1050;
		$BB sh /res/uci.sh cpu-voltage 11 1025;
		$BB sh /res/uci.sh cpu-voltage 12 1000;
		$BB sh /res/uci.sh cpu-voltage 13 1000;
		$BB sh /res/uci.sh cpu-voltage 14 1000;
		$BB sh /res/uci.sh cpu-voltage 15 975;
		$BB sh /res/uci.sh cpu-voltage 16 975;
	elif [ "$VDD_INT" -eq "4" ]; then
		$BB sh /res/uci.sh cpu-voltage 1 1400;
		$BB sh /res/uci.sh cpu-voltage 2 1350;
		$BB sh /res/uci.sh cpu-voltage 3 1300;
		$BB sh /res/uci.sh cpu-voltage 4 1275;
		$BB sh /res/uci.sh cpu-voltage 5 1250;
		$BB sh /res/uci.sh cpu-voltage 6 1200;
		$BB sh /res/uci.sh cpu-voltage 7 1150;
		$BB sh /res/uci.sh cpu-voltage 8 1100;
		$BB sh /res/uci.sh cpu-voltage 9 1050;
		$BB sh /res/uci.sh cpu-voltage 10 1000;
		$BB sh /res/uci.sh cpu-voltage 11 1000;
		$BB sh /res/uci.sh cpu-voltage 12 975;
		$BB sh /res/uci.sh cpu-voltage 13 975;
		$BB sh /res/uci.sh cpu-voltage 14 975;
		$BB sh /res/uci.sh cpu-voltage 15 950;
		$BB sh /res/uci.sh cpu-voltage 16 950;
	elif [ "$VDD_INT" -eq "5" ]; then
		$BB sh /res/uci.sh cpu-voltage 1 1375;
		$BB sh /res/uci.sh cpu-voltage 2 1325;
		$BB sh /res/uci.sh cpu-voltage 3 1275;
		$BB sh /res/uci.sh cpu-voltage 4 1250;
		$BB sh /res/uci.sh cpu-voltage 5 1225;
		$BB sh /res/uci.sh cpu-voltage 6 1175;
		$BB sh /res/uci.sh cpu-voltage 7 1125;
		$BB sh /res/uci.sh cpu-voltage 8 1075;
		$BB sh /res/uci.sh cpu-voltage 9 1025;
		$BB sh /res/uci.sh cpu-voltage 10 975;
		$BB sh /res/uci.sh cpu-voltage 11 975;
		$BB sh /res/uci.sh cpu-voltage 12 950;
		$BB sh /res/uci.sh cpu-voltage 13 950;
		$BB sh /res/uci.sh cpu-voltage 14 950;
		$BB sh /res/uci.sh cpu-voltage 15 925;
		$BB sh /res/uci.sh cpu-voltage 16 925;
	fi;
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

# busybox addons
if [ -e /system/xbin/busybox ]; then
	ln -s /system/xbin/busybox /sbin/ifconfig;
fi;

######################################
# Loading Modules
######################################
$BB chmod -R 755 /lib;

(
	sleep 40;
	# order of modules load is important
#	$BB insmod /system/lib/modules/j4fs.ko;
#	$BB mount -t j4fs /dev/block/mmcblk0p4 /mnt/.lfs

	if [ "$usbserial_module" == "on" ]; then
		$BB insmod /system/lib/modules/usbserial.ko;
		$BB insmod /system/lib/modules/ftdi_sio.ko;
		$BB insmod /system/lib/modules/pl2303.ko;
	fi;
	if [ "$cifs_module" == "on" ]; then
		$BB insmod /system/lib/modules/cifs.ko;
	fi;
	if [ "$eds_module" == "on" ]; then
		$BB insmod /system/lib/modules/eds.ko;
	fi;

	# remount external sdcard if exist
#	EXFAT_CHECK=`cat /proc/self/mounts | grep "exfat" | wc -l`;
#	if [ "$EXFAT_CHECK" -eq "1" ]; then
#		if [ `cat /tmp/sammy_rom` -eq "0" ]; then
#			umount /storage/sdcard1;
#			$BB mount -t exfat /dev/block/vold/179:9 /storage/sdcard1;
#		else
#			umount /storage/extSdCard
#			$BB mount -t exfat /dev/block/vold/179:9 /storage/extSdCard;
#		fi;
#	fi;

)&

# some nice thing for dev
$BB ln -s /sys/devices/system/cpu/cpu0/cpufreq /cpufreq;
$BB ln -s /sys/devices/system/cpu/cpufreq/ /cpugov;

# enable kmem interface for everyone by GM
echo "0" > /proc/sys/kernel/kptr_restrict;

# Cortex parent should be ROOT/INIT and not STweaks
nohup /sbin/ext/cortexbrain-tune.sh;
CORTEX=`pgrep -f "/sbin/ext/cortexbrain-tune.sh"`;
echo "-900" > /proc/$CORTEX/oom_score_adj;

# enable screen color mode
echo "1" > /sys/devices/platform/samsung-pd.2/mdnie/mdnie/mdnie/user_mode;

# create init.d folder if missing
if [ ! -d /system/etc/init.d ]; then
	mkdir -p /system/etc/init.d/
	$BB chmod 755 /system/etc/init.d/;
fi;

(
	JBMIUI=`ls /system/framework/framework-miui-res.apk | wc -l`;
	if [ "$init_d" == "on" ] || [ "$JBMIUI" -eq "1" ]; then
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

	# Mount Sec/Pri ROM DATA on Boot, we need to wait till sdcard is mounted.
	if [ `cat /tmp/pri_rom_boot` -eq "1" ]; then
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
	elif [ `cat /tmp/sec_rom_boot` -eq "1" ]; then
		mount -o remount,rw /
		mkdir /data_pri_rom;
		mkdir /system_pri_rom;
		chmod 777 /data_pri_rom;
		chmod 777 /system_pri_rom;
		mount -t ext4 /dev/block/mmcblk0p10 /data_pri_rom;
		mount -t ext4 /dev/block/mmcblk0p9 /system_pri_rom;
	fi;

	# restore normal freq
	echo "$scaling_min_freq" > /sys/devices/system/cpu/cpu0/cpufreq/scaling_min_freq;
	if [ "$scaling_max_freq" -eq "1000000" ] && [ "$scaling_max_freq_oc" -gt "1000000" ]; then
		echo "$scaling_max_freq_oc" > /sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq;
	else
		echo "$scaling_max_freq" > /sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq;
	fi;

	# ROOTBOX fix notification_wallpaper
	if [ -e /data/data/com.aokp.romcontrol/files/notification_wallpaper.jpg ]; then
		chmod 777 /data/data/com.aokp.romcontrol/files/notification_wallpaper.jpg
	fi;

	# tweaks all the dm partitions that hold moved to sdcard apps
	sleep 40;
	DM_COUNT=`ls -d /sys/block/dm* | wc -l`;
	if [ "$DM_COUNT" -gt "0" ]; then
		for d in $($BB mount | grep dm | cut -d " " -f1 | grep -v vold); do
			$BB mount -o remount,ro,noauto_da_alloc,discard $d;
		done;

		DM=`ls -d /sys/block/dm*`;
		for i in ${DM}; do
			echo "0" > ${i}/queue/rotational;
			echo "0" > ${i}/queue/iostats;
		done;
	fi;

	# script finish here, so let me know when
        echo "Done Booting" > /data/dm-boot-check;
        date >> /data/dm-boot-check;
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
	UCI_PID=`pgrep -f "/res/uci.sh"`;
	echo "-800" > /proc/$UCI_PID/oom_score_adj;
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

	CM_AOKP_10_JB=`ls /system/bin/wfd | wc -l`;
	if [ "$CM_AOKP_10_JB" -eq "1" ]; then
		if [ "$jb_sound_fix" == "on" ]; then
			input keyevent 25
			input keyevent 25
			input keyevent 25
			input keyevent 24
			input keyevent 24
			input keyevent 24
			input keyevent 24
		fi;
	else
		echo "jb_sound_fix not used";
	fi;

	# ###############################################################
	# I/O related tweaks
	# ###############################################################

	mount -o remount,rw /system;
	mount -o remount,rw /;

	# correct touch keys light, if rom mess user configuration
	$BB sh /res/uci.sh generic /sys/class/misc/notification/led_timeout_ms $led_timeout_ms;

	# correct oom tuning, if changed by apps/rom
	$BB sh /res/uci.sh oom_config_screen_on $oom_config_screen_on;
	$BB sh /res/uci.sh oom_config_screen_off $oom_config_screen_off;
)&
