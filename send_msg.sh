#!/usr/bin/env bash

#Send Msg (LOCAL SOCKET)
SndAlarmLocal() {
    msgfile="${AGT_PATH}/alarm/sendmsg_local.pl"
    chk_ok=0
    #Get message content
    i=0
    while read list; do
        msg_text[$i]="${list}"
        i=`expr $i + 1`
    done < ${ALARM_PATH}

    #Alarm User Null Check
    if [ -z "`cat ${USER_PATH} | grep -wE '(070|02|031|033|061|010|011|016)[-\s]*[0-9]{3,4}[-\s]*[0-9]{4}'`" ]; then
        phn[0]=01000000000
        callback[0]=01000000000
    else
        #Get Alarm User
        i=0
        while read list; do
            phn[$i]=`echo ${list} | awk '{print $1}'`
            callback[$i]=`echo ${list} | awk '{print $2}'`
            i=`expr $i + 1`
        done < ${USER_PATH}
    fi

    #Alarm Sent
    for (( i = 0; i < ${#phn[@]}; i ++ )); do
        for (( k = 0; k < ${#msg_text[@]}; k ++ )); do
            ${msgfile} ${phn[i]} ${callback[i]} "${msg_text[k]}"
            if [ $? -ne 0 ]; then
                chk_ok=`expr ${chk_ok} + 1`
            fi
        done
    done
}

#Send Msg (WEB)
SndAlarmWeb() {
    msgfile="${AGT_PATH}/alarm/sendmsg_http.sh"
    chk_ok=0
    ####Get message content
    while read msg_text; do
        send_status=`${msgfile} "${msg_text}"`
        if [ $? -ne 0 ] || [ -n "${send_status}" ]; then
            chk_ok=`expr ${chk_ok} + 1`
        fi
    done < ${ALARM_PATH}
}