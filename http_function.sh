#!/usr/bin/env bash

#Threshold List
GetThreshold() {
    curl -m30 -X POST [주소] -d "ip=${SERVER_IP}" -o ${THRESHOLD_PATH}
    value_ok=$?
    #Remove Blank Lines
    sed -i '/^$/d' ${THRESHOLD_PATH}
}

#Alarm User List
GetAlarmUser() {
    curl -m30 -X POST [주소] -d "test=test" -o ${USER_PATH}
    user_ok=$?
    #Remove blank lines
    sed -i '/^$/d' ${USER_PATH}
}

#Verify Normal Operation
ActionCheck() {
    curl -m30 -X POST [주소] -d "ip=${SERVER_IP}&time=${loging_time}&ok1=${value_ok}&ok2=${user_ok}&ok3=${script_ok}&ok4=${alarm_ok}&version=${version}"
    action_ok=$?
}