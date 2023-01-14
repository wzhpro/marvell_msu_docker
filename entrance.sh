#!/bin/dash
if [ -z "$token" ] 
then
	exit 0
fi
if [ -z "$MSU_ROOT_PASSWD" ]
then
	exit 0
fi
echo "root:$MSU_ROOT_PASSWD" | chpasswd

# create config folders
if [ ! -d /etc/marvell/cli ]
then
	mkdir /etc/marvell/cli
	touch /etc/marvell/cli/mvcli.ini
fi

# create db.xml
if [ ! -f /etc/marvell/db.xml ]
then
	cp /opt/marvell/storage/db/db.xml.orig /etc/marvell/db.xml
fi

if [ "$1" = "cli" ]
then
	shift
	exec /opt/marvell/storage/cli/mvcli "$@"
fi


# start storage agent in background
/opt/marvell/storage/svc/MarvellStorageAgent start

# start web server
echo "start web server"
export LD_LIBRARY_PATH=/opt/marvell/storage/apache2/lib64:/opt/marvell/storage/expat/lib64:/opt/marvell/storage/libxml2/lib64:/opt/marvell/storage/openssl/lib64:/opt/marvell/storage/php/lib64
exec /opt/marvell/storage/apache2/bin/apachectl &

# start monitor
echo "start monitor"
checkinterval="1" #hour
reportinterval="7" #day
next_report_time=0
while :
do
	raid_status=1
	now=`date +%s`
	/opt/marvell/storage/cli/mvcli info -o vd > /tmp/marvell_vdinfo
	/opt/marvell/storage/cli/mvcli info -o pd > /tmp/marvell_pdinfo
	echo "==thewus Raid Report==" > /tmp/marvell_report
	date "+%Y-%m-%d %H:%M:%S" >> /tmp/marvell_report
	raidinfo_name=`cat /tmp/marvell_vdinfo | grep "name:" | head -n 1 | awk -F: '{gsub(/^[ ]+/, "", $2); print $2}'`
	raidinfo_status=`cat /tmp/marvell_vdinfo | grep "status:" | head -n 1 | awk -F: '{gsub(/^[ ]+/,"", $2); print $2}'`
	[ "$raidinfo_status" != "functional"  ] && raid_status=0

	echo "$raidinfo_name:$raidinfo_status" >> /tmp/marvell_report
	echo "--Disk Info--" >> /tmp/marvell_report
	raidinfo_pds=`cat /tmp/marvell_vdinfo | grep "PD RAID setup:" | head -n 1 | awk -F: '{gsub(/^[ ]+/,"", $2); print $2}'`

	for pdid in $raidinfo_pds
	do
		/opt/marvell/storage/cli/mvcli smart -p $pdid > /tmp/marvell_smart_$pdid
	done

	#SMART STATUS
	echo -n "STATUS:"  >> /tmp/marvell_report
	for pdid in $raidinfo_pds
	do
		echo -n "[$pdid]" >> /tmp/marvell_report
		raidinfo_smart=`cat /tmp/marvell_smart_$pdid|grep "SMART STATUS RETURN:"|awk -F: '{gsub(/^[ ]+/,"", $2); print $2}'`
		echo -n $raidinfo_smart >> /tmp/marvell_report
		[ "$raidinfo_smart" != "OK."  ] && raid_status=0
		echo -n " " >> /tmp/marvell_report
	done
	echo "" >> /tmp/marvell_report

	#Read Error Rate
	echo -n "Read Error Rate:"  >> /tmp/marvell_report
	for pdid in $raidinfo_pds
	do
		echo -n "[$pdid]" >> /tmp/marvell_report
		raidinfo_rdr=`cat /tmp/marvell_smart_$pdid|grep "Read Error Rate"|awk -F'\t' '{print $3}'`
		[ "$raidinfo_rdr" != "000000000000" ] && raid_status=0
		echo -n `printf %d 0x$raidinfo_rdr` >> /tmp/marvell_report
		echo -n " " >> /tmp/marvell_report
	done
	echo "" >> /tmp/marvell_report

	#Seek Error Rate
	echo -n "Seek Error Rate:"  >> /tmp/marvell_report
	for pdid in $raidinfo_pds
	do
		echo -n "[$pdid]" >> /tmp/marvell_report
		raidinfo_ser=`cat /tmp/marvell_smart_$pdid|grep "Seek Error Rate"|awk -F'\t' '{print $3}'`
		[ "$raidinfo_ser" != "000000000000" ] && raid_status=0
		echo -n `printf %d 0x$raidinfo_ser` >> /tmp/marvell_report
		echo -n " " >> /tmp/marvell_report
	done
	echo "" >> /tmp/marvell_report

	#Spin Retry Count
	echo -n "Spin Retry:"  >> /tmp/marvell_report
	for pdid in $raidinfo_pds
	do
		echo -n "[$pdid]" >> /tmp/marvell_report
		raidinfo_prc=`cat /tmp/marvell_smart_$pdid|grep "Spin Retry Count"|awk -F'\t' '{print $3}'`
		[ "$raidinfo_prc" != "000000000000" ] && raid_status=0
		echo -n `printf %d 0x$raidinfo_prc` >> /tmp/marvell_report
		echo -n " " >> /tmp/marvell_report
	done
	echo "" >> /tmp/marvell_report

	#Calibration retry
	echo -n "Calibration retry:"  >> /tmp/marvell_report
	for pdid in $raidinfo_pds
	do
		echo -n "[$pdid]" >> /tmp/marvell_report
		raidinfo_cr=`cat /tmp/marvell_smart_$pdid|grep "Calibration retry"|awk -F'\t' '{print $3}'`
		[ "$raidinfo_cr" != "000000000000" ] && raid_status=0
		echo -n `printf %d 0x$raidinfo_cr` >> /tmp/marvell_report
		echo -n " " >> /tmp/marvell_report
	done
	echo "" >> /tmp/marvell_report

	#Current Pending Sector Count
	echo -n "Pending Sector:"  >> /tmp/marvell_report
	for pdid in $raidinfo_pds
	do
		echo -n "[$pdid]" >> /tmp/marvell_report
		raidinfo_cpsc=`cat /tmp/marvell_smart_$pdid|grep "Current Pending Sector Count"|awk -F'\t' '{print $3}'`
		[ "$raidinfo_cpsc" != "000000000000" ] && raid_status=0
		echo -n `printf %d 0x$raidinfo_cpsc` >> /tmp/marvell_report
		echo -n " " >> /tmp/marvell_report
	done
	echo "" >> /tmp/marvell_report

	#Uncorrectable Sector
	echo -n "Uncorrectable Sector:"  >> /tmp/marvell_report
	for pdid in $raidinfo_pds
	do
		echo -n "[$pdid]" >> /tmp/marvell_report
		raidinfo_usc=`cat /tmp/marvell_smart_$pdid|grep "Uncorrectable Sector Count"|awk -F'\t' '{print $3}'`
		[ "$raidinfo_usc" != "000000000000" ] && raid_status=0
		echo -n `printf %d 0x$raidinfo_usc` >> /tmp/marvell_report
		echo -n " " >> /tmp/marvell_report
	done
	echo "" >> /tmp/marvell_report

	#CRC Error Count
	echo -n "CRC Error:"  >> /tmp/marvell_report
	for pdid in $raidinfo_pds
	do
		echo -n "[$pdid]" >> /tmp/marvell_report
		raidinfo_crc=`cat /tmp/marvell_smart_$pdid|grep "CRC Error Count"|awk -F'\t' '{print $3}'`
		[ "$raidinfo_crc" != "000000000000" ] && raid_status=0
		echo -n `printf %d 0x$raidinfo_crc` >> /tmp/marvell_report
		echo -n " " >> /tmp/marvell_report
	done
	echo "" >> /tmp/marvell_report
	cat /tmp/marvell_report

	#send Dingtalk msg
	last_report_interval=`expr $now - $next_report_time`
	if [ $raid_status -eq 0 ] || [ `expr $now - $next_report_time` -ge 0 ]; then
		echo -n '{"msgtype": "text","text": {"content":"' > /tmp/marvell_dingtalk
		cat /tmp/marvell_report |sed ":a;N;s/\n/\\\n/g;ta" >> /tmp/marvell_dingtalk
		echo '"}}' >> /tmp/marvell_dingtalk
		curl 'https://oapi.dingtalk.com/robot/send?access_token='$token  -H 'Content-Type: application/json'  -d @/tmp/marvell_dingtalk > /dev/null
		next_report_time=`date +%s -d "+$reportinterval days"`
	fi

	rm -rf /tmp/marvell_*

	sleep "$checkinterval"h
done

