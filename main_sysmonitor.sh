#!/usr/bin/env bash

######################################
#Production: 2018-01-24 (Choi Jin hyuk)
#Last Update: 2018-07-02 (Choi Jin hyuk)
#Refactoring: 2019-04-10 (Choi Jin hyuk)
######################################

version="v1.8"
s_run_time=`date '+%s%N'`
loging_time=`date '+%Y%m%d%H%M%S'`

#Global Variable
export AGT_PATH="HOME 경로"
export THRESHOLD_PATH="${AGT_PATH}/log/threshold.log"
export USER_PATH="${AGT_PATH}/log/alarm_user.log"
export ALARM_PATH="${AGT_PATH}/log/send_msg.log"
export LOG_PATH="${AGT_PATH}/log/system_result.log"
export SERVER_IP=`/sbin/ifconfig | awk '/inet / {split($2,arr,":"); print arr[2]}' | head -1`
export MSG_TYPE=`cat ${THRESHOLD_PATH} | grep "ALARM_TYPE" | awk -F: '{print $2}'`

touch ${LOG_PATH}

#Function Import
source ${AGT_PATH}/http_function.sh
source ${AGT_PATH}/send_msg.sh

#Create Default Directory
if [[ ! -d ${AGT_PATH}/log ]]; then
    mkdir ${AGT_PATH}/log
fi

if [[ ! -d ${AGT_PATH}/alarm ]]; then
    mkdir ${AGT_PATH}/alarm
fi

#Get Threshold Data
GetThreshold
GetAlarmUser

#Start System Check
${AGT_PATH}/check_system.sh
script_ok=$?

#Start Alarm Send
if [[ -s ${ALARM_PATH} ]]; then
    case ${MSG_TYPE} in
        "L" | "l")
            SndAlarmLocal ;;
        "W" | "w")
            SndAlarmWeb ;;
        *)
            SndAlarmLocal ;;
    esac
    alarm_ok="`cat ${ALARM_PATH} |wc -l`/${MSG_TYPE}"
    #Re Send Logic
    if [[ ${chk_ok} -gt 0 ]]; then
        case ${MSG_TYPE} in
            "L" | "l")
                SndAlarmWeb ;;
            "W" | "w")
                SndAlarmLocal ;;
            *)
                SndAlarmWeb ;;
        esac
        alarm_ok="`cat ${ALARM_PATH} |wc -l`/${MSG_TYPE}/R"
    fi
fi

#Action Ok Check
ActionCheck

#Initialize Log Files Larger Than 15MB
result_size=`du -m ${LOG_PATH} | awk '{print $1}'`
if [[ ${result_size} -ge 15 ]]; then
    cp /dev/null ${LOG_PATH}
else
    e_run_time=`date '+%s%N'`
    elapsed=`echo "(${e_run_time} - ${s_run_time}) / 1000000" | bc`
    run_time=`echo "scale=6;${elapsed} / 1000" | bc | awk '{printf "%.3f", $1}'`
    echo -e "${loging_time}\tValue OK=${value_ok}\tUser OK=${user_ok}\tScrtp OK=${script_ok}\tAlarm OK=${alarm_ok}\tAction OK=${action_ok}\tRun Time=${run_time} sec" >> ${LOG_PATH}
fi