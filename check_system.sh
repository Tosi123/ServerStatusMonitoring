#!/usr/bin/env bash

#Pulbic Function Variable
HOSTNAME=`uname -n`
DATE=`date +%H:%M`
ALARM_ADD_MSG=`cat ${THRESHOLD_PATH} | grep ALARM_ADD_MSG | awk -F: '{print $2}'`
NUMBER_CHECK="^[0-9]+$"

if [[ -n "${ALARM_ADD_MSG}" ]]; then
    ALARM_ADD_MSG=_${ALARM_ADD_MSG}
fi

#Disk usage files [FX: Disk()]
volume="${AGT_PATH}/log/volume.log"
first_volume="${AGT_PATH}/log/first_volume.log"
#Inode Disk usage files [FX: Disk()]
inode="${AGT_PATH}/log/inode.log"
first_inode="${AGT_PATH}/log/first_inode.log"
#Check Capacity Growth [FX: Diskflood()]
volume_old="${AGT_PATH}/log/volume_old.log"
volume_now="${AGT_PATH}/log/volume_now.log"
#IPMI Status File [FX: Power()]
ipmiout_file="${AGT_PATH}/log/ipmival.out"

#Initialize Message Data
cp /dev/null ${ALARM_PATH}

#Load Average Check
Load() {
    RESULT=""
    #Load Average Get Threshold
    WARNING_LOAD_5min=`cat ${THRESHOLD_PATH} | grep LOAD_AVERAG | awk -F: '{print $2}' | tr -d ' ' | awk -F, '{print $1}'`
    WARNING_LOAD_15min=`cat ${THRESHOLD_PATH} | grep LOAD_AVERAG | awk -F: '{print $2}' | tr -d ' ' | awk -F, '{print $2}'`
    DANGER_LOAD_5min=`cat ${THRESHOLD_PATH} | grep LOAD_AVERAG | awk -F: '{print $2}' | tr -d ' ' | awk -F, '{print $3}'`
    DANGER_LOAD_15min=`cat ${THRESHOLD_PATH} | grep LOAD_AVERAG | awk -F: '{print $2}' | tr -d ' ' | awk -F, '{print $4}'`

    #Locad Average Current Value
    UPTIME=`uptime | awk -F"load average:" '{print $2}'`
    CPU_ACT_5minA=`echo ${UPTIME} | awk '{print $1}' | tr -d ","`
    CPU_ACT_15minA=`echo ${UPTIME} | awk '{print $2}' | tr -d ","`
    CPU_ACT_5min=`echo ${UPTIME} | awk '{print $1}' | awk -F. '{print $1}'`
    CPU_ACT_15min=`echo ${UPTIME} | awk '{print $2}' | awk -F. '{print $1}'`

    #Threshold Value Check
    if [[ ! ${WARNING_LOAD_5min} =~ ${NUMBER_CHECK} ]] || [[ ! ${WARNING_LOAD_15min} =~ ${NUMBER_CHECK} ]] || [[ ! ${DANGER_LOAD_5min} =~ ${NUMBER_CHECK} ]] || [[ ! ${DANGER_LOAD_15min} =~ ${NUMBER_CHECK} ]]; then
        WARNING_LOAD_5min=20
        WARNING_LOAD_15min=20
        DANGER_LOAD_5min=30
        DANGER_LOAD_15min=30
    fi

    if [[ ${CPU_ACT_5min} -ge ${DANGER_LOAD_5min} ]]; then
        RESULT="${RESULT} 5mLoad_DANGER"
    else
        if [[ ${CPU_ACT_5min} -ge ${WARNING_LOAD_5min} ]]; then
            RESULT="${RESULT} 5mLoad_WARN"
        fi
    fi

    if [[ ${CPU_ACT_15min} -ge ${DANGER_LOAD_15min} ]]; then
        RESULT="${RESULT} 15mLoad_DANGER"
    else
        if [[ ${CPU_ACT_15min} -ge ${WARNING_LOAD_15min} ]]; then
            RESULT="${RESULT} 15mLoad_WARN"
        fi
    fi

    if [[ -n "${RESULT}" ]]; then
        RESULT="${SERVER_IP}_${HOSTNAME}_${DATE}_${RESULT}_${CPU_ACT_5minA},${CPU_ACT_15minA}${ALARM_ADD_MSG}"
        echo ${RESULT} >> ${ALARM_PATH}
    fi
}

Process() {
    RESULT=""
    #Process Get Thresholds
    WARNING_PROCESSES=`cat ${THRESHOLD_PATH} | grep PROCESS | awk -F: '{print $2}' | tr -d ' ' | awk -F, '{print $1}'` # SYSTEM PROCESS NUMBER + 20
    DANGER_PROCESSES=`cat ${THRESHOLD_PATH} | grep PROCESS | awk -F: '{print $2}' | tr -d ' ' | awk -F, '{print $2}'` # WARNING_PROCESSES + 20

    #Threshold Value Check
    if [[ ! ${WARNING_PROCESSES} =~ ${NUMBER_CHECK} ]] || [[ ! ${DANGER_PROCESSES} =~ ${NUMBER_CHECK} ]]; then
        WARNING_PROCESSES=700
        DANGER_PROCESSES=800
    fi

    PROCESS_CNT=`ps -ef | wc -l`

    if [[ ${PROCESS_CNT} -ge ${DANGER_PROCESSES} ]]; then
        RESULT="${RESULT}#ofProcess DANGER"
    else
        if [[ ${PROCESS_CNT} -ge ${WARNING_PROCESSES} ]]; then
            RESULT="${RESULT}#ofProcess WARNING"
        fi
    fi

    if [[ -n "${RESULT}" ]]; then
        RESULT="${SERVER_IP}_${HOSTNAME}_${DATE}_${RESULT}_${PROCESS_CNT}${ALARM_ADD_MSG}"
        echo ${RESULT} >> ${ALARM_PATH}
    fi
}

Volume() {
    RESULT=""
    #Volume Get Thresholds
    /bin/df -hPl | grep % | tail -n +2 | sed 's/%//' | awk '{print $6,$5,$4}' > ${volume}
    /bin/df -ihPl | grep % | tail -n +2 | sed 's/%//' | awk '{print $6,$5,$4}' > ${inode}
    DISK_DEFAULT_LIMIT=`cat ${THRESHOLD_PATH} | grep DEFAULT_VOLUME | tr -d ' ' | awk -F: '{print $2}'`
    #Threshold Null Check
    if [[ ! ${DISK_DEFAULT_LIMIT} =~ ${NUMBER_CHECK} ]]; then
        DISK_DEFAULT_LIMIT=80
    fi
    DISK_DEFAULT_LIMIT_FIRST=`expr ${DISK_DEFAULT_LIMIT} - 5`

    DISK_PART_CNT=`cat ${THRESHOLD_PATH} | grep CUSTOM_VOLUME | tr -cd "=" | wc -m`
    EXPSTR=`cat ${THRESHOLD_PATH} | grep EXCEPT_VOLUME | awk -F: '{print $2}' | wc -c`

    #Exclude comparison partitions
    if [[ ${EXPSTR} -gt 1 ]]; then
        EXP_CNT=`cat ${THRESHOLD_PATH} | grep EXCEPT_VOLUME | awk -F: '{print $2}' | tr -cd "," | wc -m`
        k=1
        for (( i = 0; i <= ${EXP_CNT}; i ++ )); do
            EXP_PARTITION=`cat ${THRESHOLD_PATH} | grep EXCEPT_VOLUME | awk -F: '{print $2}' | awk -F, "{print $"${k}"}"`
            cat ${volume} | awk '{ if ($1=="'"${EXP_PARTITION}"'") {q=1} else {print $0} }' > ${volume}_tmp
            mv ${volume}"_tmp" ${volume}
            cat ${inode} | awk '{ if ($1=="'"${EXP_PARTITION}"'") {q=1} else {print $0} }' > ${inode}_tmp # Inode
            mv ${inode}_tmp ${inode}
            k=`expr ${k} + 1`
        done
    fi

    #General Volume
    while read list; do
        part=`echo ${list} | awk '{print $1}'`
        per=`echo ${list} | awk '{print $2}'`
        freed=`echo ${list} | awk '{print $3}'`
        KKK="${part} ${per}%,free: ${freed}"
        a=0

        #A Preliminary Alarm Value Check
        first_status=`grep -n "part:${part} $*" ${first_volume} | awk -F":" '{print $4}'`
        if [[ -z "${first_status}" ]]; then
            echo "part:${part} status:0" >> ${first_volume}
            first_status=`grep -n "part:${part} $*" ${first_volume} | awk -F":" '{print $4}'`
        fi
        first_line=`grep -n "part:${part} $*" ${first_volume} | awk -F":" '{print $1}'`

        #Custom Partition Limit
        for (( i = 1; i <= ${DISK_PART_CNT}; i ++ )); do
            DISK_PART=`cat ${THRESHOLD_PATH} | grep CUSTOM_VOLUME | tr -d ' ' | awk -F: '{print $2}' | awk -F, "{print $"${i}"}" | awk -F= '{print $1}'`
            DISK_PART_LIMIT=`cat ${THRESHOLD_PATH} | grep CUSTOM_VOLUME | tr -d ' ' | awk -F: '{print $2}' | awk -F, "{print $"${i}"}" | awk -F= '{print $2}'`
            DISK_PART_LIMIT_FIRST=`expr ${DISK_PART_LIMIT} - 5`
            if [[ "${part}" == " ${DISK_PART} " ]]; then
                if [[ ${per} -ge ${DISK_PART_LIMIT} ]]; then
                    a=1
                    RESULT="${SERVER_IP}_${HOSTNAME}_${DATE}_${KKK}${ALARM_ADD_MSG}"
                    echo ${RESULT} >> ${ALARM_PATH}
                    break
                elif [[ ${per} -ge ${DISK_PART_LIMIT_FIRST} ]]; then
                    if [[ ${first_status} -eq 0 ]]; then
                        RESULT="${SERVER_IP}_${HOSTNAME}_${DATE}_${KKK}"_A Preliminary Alarm"${ALARM_ADD_MSG}"
                        echo ${RESULT} >> ${ALARM_PATH}
                        sed -i "${first_line}s|.*|part:${part} status:1|" ${first_volume}
                    fi
                    a=1
                    break
                else
                    if [[ ${first_status} -eq 1 ]]; then
                        sed -i "${first_line}s|.*|part:${part} status:0|" ${first_volume}
                    fi
                    a=1
                    break
                fi
            fi
        done

        ###Default Partition Limit
        if [[ ${a} -eq 0 ]]; then
            if [[ ${per} -ge ${DISK_DEFAULT_LIMIT} ]]; then
                RESULT="${SERVER_IP}_${HOSTNAME}_${DATE}_${KKK}${ALARM_ADD_MSG}"
                echo ${RESULT} >> ${ALARM_PATH}
            elif [[ $per -ge $DISK_DEFAULT_LIMIT_FIRST ]]; then
                if [[ $first_status -eq 0 ]]; then
                    RESULT="${SERVER_IP}_${HOSTNAME}_${DATE}_${KKK}"_A Preliminary Alarm"${ALARM_ADD_MSG}"
                    echo ${RESULT} >> ${ALARM_PATH}
                    sed -i "${first_line}s|.*|part:${part} status:1|" ${first_volume}
                fi
            else
                if [[ ${first_status} -eq 1 ]]; then
                    sed -i "${first_line}s|.*|part:${part} status:0|" ${first_volume}
                fi
                echo DEFAUL PASS
            fi
        fi
    done < ${volume}

    ###INODE Volume
    while read list; do
        part=`echo ${list} | awk '{print $1}'`
        per=`echo ${list} | awk '{print $2}'`
        freed=`echo ${list} | awk '{print $3}'`
        KKK="${part} ${per} %,free:  ${freed}"
        a=0

        ###A Preliminary Alarm Value Check
        first_status=`grep -n "part:${part} $*" ${first_inode} | awk -F":" '{print $4}'`
        if [[ -z "${first_status}" ]]; then
            echo "part:${part} status:0" >> ${first_inode}
            first_status=`grep -n "part:${part} $*" ${first_inode} | awk -F":" '{print $4}'`
        fi
        first_line=`grep -n "part:${part} $*" ${first_inode} | awk -F":" '{print $1}'`

        ###Custom Inode Partition Limit
        for (( i = 1; i <= ${DISK_PART_CNT}; i ++ )); do
            DISK_PART=`cat ${THRESHOLD_PATH} | grep CUSTOM_VOLUME | tr -d ' ' | awk -F: '{print $2}' | awk -F, "{print $"${i}"}" | awk -F= '{print $1}'`
            DISK_PART_LIMIT=`cat ${THRESHOLD_PATH} | grep CUSTOM_VOLUME | tr -d ' ' | awk -F: '{print $2}' | awk -F, "{print $"${i}"}" | awk -F= '{print $2}'`
            DISK_PART_LIMIT_FIRST=`expr ${DISK_PART_LIMIT} - 5`
            if [[ "${part}" == "${DISK_PART}" ]]; then
                if [[ ${per} -ge ${DISK_PART_LIMIT} ]]; then
                    a=1
                    RESULT="${SERVER_IP}_${HOSTNAME}_${DATE}_inode_${KKK}_${ALARM_ADD_MSG}"
                    echo ${RESULT} >> ${ALARM_PATH}
                    break
                elif [[ ${per} -ge ${DISK_PART_LIMIT_FIRST} ]]; then
                    if [[ ${first_status} -eq 0 ]]; then
                        RESULT="${SERVER_IP}_${HOSTNAME}_${DATE}_inode_${KKK}"_A Preliminary Alarm"${ALARM_ADD_MSG}"
                        echo ${RESULT} >> ${ALARM_PATH}
                        sed -i "${first_line}s|.*|part:${part} status:1|" ${first_inode}
                    fi
                else
                    if [[ ${first_status} -eq 1 ]]; then
                        sed -i "${first_line}s|.*|part:${part} status:0|" ${first_inode}
                    fi
                    a=1
                    break
                fi
            fi
        done

        ###Default Inode Partition Limit
        if [[ ${a} -eq 0 ]]; then
            if [[ ${per} -ge ${DISK_DEFAULT_LIMIT} ]]; then
                RESULT="${SERVER_IP}_${HOSTNAME}_${DATE}_inode_${KKK}${ALARM_ADD_MSG}"
                echo ${RESULT} >> ${ALARM_PATH}
            elif [[ ${per} -ge ${DISK_DEFAULT_LIMIT_FIRST} ]]; then
                if [[ ${first_status} -eq 0 ]]; then
                    RESULT="${SERVER_IP}_${HOSTNAME}_${DATE}_inode_${KKK}"_A Preliminary Alarm"${ALARM_ADD_MSG}"
                    echo ${RESULT} >> ${ALARM_PATH}
                    sed -i "${first_line}s|.*|part:${part} status:1|" ${first_inode}
                fi
            else
                if [[ ${first_status} -eq 1 ]]; then
                    sed -i "${first_line}s|.*|part:${part} status:0|" ${first_inode}
                fi
            fi
        fi
    done < ${inode}
}

Power() {
    RESULT=""
    ipmitool sdr type "Power Supply" | grep -E "Power Supply|Status" | awk -F'|' '{print "=module="$1,"=status="$5"="}' | tr -d ' '> ${ipmiout_file}

    #STAUTS CODE
    code[0]="Presencedetected" # normal
    code[1]="Presencedetected,PowerSupplyAClost" # Over power line

    while read list; do
        module=`echo ${list} | awk -F= '{print $3}'`
        status=`echo ${list} | awk -F= '{print $5}'`
        if [[ "${status}" == "${code[0]}" ]]; then
            echo CODE PASS
        elif [[ "${status}" == "${code[1]}" ]]; then
            RESULT="${SERVER_IP}_${HOSTNAME}_${DATE}_POWER=${status},NAME=${module}${ALARM_ADD_MSG}"
            echo ${RESULT} >> ${ALARM_PATH}
        elif [[ -z "${status}" ]]; then
            RESULT="${SERVER_IP}_${HOSTNAME}_${DATE}_POWER=${status},NULL,NAME=${module}${ALARM_ADD_MSG}"
            echo ${RESULT} >> ${ALARM_PATH}
        else
            RESULT="${SERVER_IP}_${HOSTNAME}_${DATE}_POWER=${status},??,NAME=${module}${ALARM_ADD_MSG}"
            echo ${RESULT} >> ${ALARM_PATH}
        fi
    done < ${ipmiout_file}

    if [[ ! -s ${ipmiout_file} ]]; then
        RESULT="${SERVER_IP}_${HOSTNAME}_${DATE}_POWER=${status},IPMI No Operation,NAME=${module}${ALARM_ADD_MSG}"
        echo ${RESULT} >> ${ALARM_PATH}
    fi
}

ReadOnly() {
    RESULT=""
    READ_PART=`cat /proc/mounts | awk '{print $2,$4}' | awk -F, '{print $1}' | awk '{if($2 == "ro") print $1}'`
    READ_BYTE=`echo ${READ_PART} | wc -c`

    if [[ ${READ_BYTE} -gt 1 ]]; then
        RESULT="${SERVER_IP}_${HOSTNAME}_${DATE}_Partition_ReadOnly_:${READ_PART}${ALARM_ADD_MSG}"
        echo ${RESULT} >> ${ALARM_PATH}
    fi
}

VolumeFlood() {
    RESULT=""
    /bin/df -kPl | tail -n +2 | awk '{printf "%d,%s\n" ,$4/1024,$6}' > ${volume_now}
    DISK_FLOOD_VAL=`cat ${THRESHOLD_PATH} | grep INCREASE_VOLUME | awk -F: '{print $2}'`

    #Threshold Null Check
    if [[ ! ${DISK_FLOOD_VAL} =~ ${NUMBER_CHECK} ]]; then
        DISK_FLOOD_VAL=128
    fi

    for catval in $(cat ${volume_now}); do
        mb_byte=`echo ${catval} | awk -F, '{print $1}'`
        flood_part=`echo ${catval} | awk -F, '{print $2}'`
        old_mb_byte=`grep "${flood_part}\$" ${volume_old} | awk -F, '{print $1}'`

        if [[ -n ${old_mb_byte} ]]; then
            diff_mb_byte=`expr ${old_mb_byte} - ${mb_byte}`
            if [[ ${diff_mb_byte} -ge ${DISK_FLOOD_VAL} ]]; then
                diff_gb_byte=`echo ${diff_mb_byte} | awk '{printf "%0.2f" ,$1/1024}'`
                RESULT="${SERVER_IP}_${HOSTNAME}_${DATE}_${flood_part}_${diff_gb_byte}"GB_Increase_Disk_Usage"${ALARM_ADD_MSG}"
                echo ${RESULT} >> ${ALARM_PATH}
            fi
        fi
    done

    cp -f ${volume_now} ${volume_old}
}

# MAIN
# EXCEL EXCEPT LIST excludes execution of executable functions.
EXP_LSTR=`cat ${THRESHOLD_PATH} | grep EXCEPT_LIST | tr -d ' ' | awk -F: '{print $2}' | wc -c`
EXP_LCNT=`cat ${THRESHOLD_PATH} | grep EXCEPT_LIST | tr -d ' ' | awk -F: '{print $2}' | tr -cd "," | wc -m`
# Registration of start function
START_LIST[0]="LD" #Load_Average
START_LIST[1]="PS" #Porcess
START_LIST[2]="DS" #Disk Volume
START_LIST[3]="PW" #Power Status
START_LIST[4]="RO" #Partition ReadOnly
START_LIST[5]="DF" #Disk Volume Flood

if [[ ${EXP_LSTR} -gt 1 ]]; then
    for (( i = 1; i <= ${EXP_LCNT} + 1; i ++ )); do
        EXP_LIST[${i}] = `cat ${THRESHOLD_PATH} | grep EXCEPT_LIST | tr -d ' ' | awk -F: '{print $2}' | awk -F, "{print $"${i}"}"`
    done
    for (( i = 0; i < ${#START_LIST[@]}; i ++ )); do
        for (( k = 1; k <= ${#EXP_LIST[@]}; k ++ )); do
            if [[ "${START_LIST[i]}" == "${EXP_LIST[k]}" ]]; then
                unset -v START_LIST[${i}]
                break
            fi
        done
    done
fi

####Run the function in the START array.
for sta in ${START_LIST[@]}
do
    case "${sta}" in
        "LD" | "ld")
            Load ;;
        "PS" | "ps")
            Process ;;
        "DS" | "ds")
            Volume ;;
        "PW" | "pw")
            Power ;;
        "RO" | "ro")
            ReadOnly ;;
        "DF" | "df")
            VolumeFlood ;;
    esac
done
