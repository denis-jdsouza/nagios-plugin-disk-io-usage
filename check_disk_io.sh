#!/bin/bash

# ========================================================================================
# Custom Nagios plugin to check disk IO utilization
#
# Description   : Nagios plugin to check Disk IO utilization for all disks.
#                 (this plugin will take averave of 3 'iostat' runs)
#                 This script has been designed for Linux platform only.
#
# Usage         : ./check_diskio.sh [-W <WARNING>]
# ========================================================================================

# Paths to iostat binary, this may have to be modified based on your system.
IOSTAT=/usr/bin/iostat
 
# Nagios return codes
STATE_OK=0
STATE_WARNING=1
STATE_UNKNOWN=3
 
# Help menu
print_usage() {
    echo ""
    echo "Nagios plugin to check Disk IO utilization for all disks (will take avg or 3 iostat runs)"
    echo "Usage: ./check_diskio.sh [flags]"
    echo ""
    echo "Flags:"
    echo "  -W <WARNING> : Nagios Warning level"
    echo "  -h Help menu"
    echo ""
}
 
# Parse parameters
while [ $# -gt 0 ]; do
    case "$1" in
        -h | --help)
            print_usage
            exit $STATE_OK
            ;;
        -W)
            shift
            NAGIOS_WARNING=$1
            ;;
        *)  echo "Unknown argument: $1"
            print_usage
            exit $STATE_UNKNOWN
            ;;
        esac
    shift
done
 
Check_parameters ()
{
    if [ ! -x $IOSTAT ]; then
        echo "UNKNOWN: iostat not found or is not executable by the nagios user."
        exit $STATE_UNKNOWN
    fi
    if [[ -z $NAGIOS_WARNING ]]; then
        echo "UNKNOWN: Please provide warning threshold."
        exit $STATE_UNKNOWN
    fi
}
 
Get_disks ()
{
    for VOL in `iostat -dx 1 1 |grep -v Device: |awk 'NF' |awk {'print $1'} | grep -v 'Linux\|Device\|loop'`; do
        DEVICES+=("$VOL")
    done
    #echo "Disks: ${DEVICES[@]}"
}
 
Get_metrics ()
{
    if [ ${#DEVICES[@]} -gt 1 ]; then
        TOTAL=0
        SUM=0
        #iostat run number: 1
        for DEVUTIL in `iostat -dx 1 4 | awk 'NF' | tail -n${#DEVICES[@]}| awk '{print $NF}'`; do
            DEVUTIL_INT=${DEVUTIL%.*}
            DEVICE_UTIL_REPORT1+=("$DEVUTIL_INT")
        done
        #iostat run number: 2
        for DEVUTIL in `iostat -dx 1 4 | awk 'NF' | tail -n${#DEVICES[@]}| awk '{print $NF}'`; do
            DEVUTIL_INT=${DEVUTIL%.*}
            DEVICE_UTIL_REPORT2+=("$DEVUTIL_INT")
        done
        #iostat run number: 3
        for DEVUTIL in `iostat -dx 1 4 | awk 'NF' | tail -n${#DEVICES[@]}| awk '{print $NF}'`; do
            DEVUTIL_INT=${DEVUTIL%.*}
            DEVICE_UTIL_REPORT3+=("$DEVUTIL_INT")
        done
 
        for i in $(seq 1 ${#DEVICES[@]}); do
        j=$((i-1))
            SUM=`expr ${DEVICE_UTIL_REPORT1[$j]} + ${DEVICE_UTIL_REPORT2[$j]} + ${DEVICE_UTIL_REPORT3[$j]}`
            TOTAL=`expr $SUM / 3`
            DEVICE_UTIL_REPORT+=("$TOTAL")
        done
 
        for i in $(seq 1 ${#DEVICES[@]}); do
        j=$((i-1))
            UTIL_INT=${DEVICE_UTIL_REPORT[$j]}
            DEVICE_UTIL+=("${DEVICES[$j]}:$UTIL_INT%")
        DEVICE_UTIL2+=("$UTIL_INT")
        done
 
    else
        #iostat run number: 1
        UTIL1=`iostat -dx 1 4 | awk 'NF' | tail -n1 | awk '{print $NF}'`
        UTIL1_INT=${UTIL1%.*}
 
        #iostat run number: 2
        UTIL2=`iostat -dx 1 4 | awk 'NF' | tail -n1 | awk '{print $NF}'`
        UTIL2_INT=${UTIL2%.*}
 
        #iostat run number: 3
        UTIL3=`iostat -dx 1 4 | awk 'NF' | tail -n1 | awk '{print $NF}'`
        UTIL3_INT=${UTIL3%.*}
 
        SUM=`expr $UTIL1_INT + $UTIL2_INT + $UTIL3_INT`
        UTIL_INT=`expr $SUM / 3`
        DEVICE_UTIL=$DEVICES:$UTIL_INT%
        DEVICE_UTIL2=$UTIL_INT
    fi
}
 
Process_metrics ()
{
    OUTPUTW=0
    if [ ${#DEVICES[@]} -gt 1 ]; then
        for i in $(seq 1 ${#DEVICES[@]}); do
            j=$((i-1))
            if [ ${DEVICE_UTIL2[$j]} -ge $NAGIOS_WARNING ]; then
                OUTPUTW=1
                DEVICE_UTIL_WARN+=("${DEVICE_UTIL[$j]}")
            fi
        done
    else
        if [ $DEVICE_UTIL2 -ge $NAGIOS_WARNING ]; then
            OUTPUTW=1
            DEVICE_UTIL_WARN=$DEVICE_UTIL
        fi
     fi
 
    if [ $OUTPUTW == 1 ]; then
        echo "WARNING: Disk-IO Utilization for Disks: ${DEVICE_UTIL_WARN[@]};  Warning:$NAGIOS_WARNING%"
        exit $STATE_WARNING
    else
        echo "OK: Disk-IO Utilization for Disks: ${DEVICE_UTIL[@]}, Warning:$NAGIOS_WARNING%"
        exit $STATE_OK
    fi
}
 
Check_parameters
Get_disks
Get_metrics
Process_metrics