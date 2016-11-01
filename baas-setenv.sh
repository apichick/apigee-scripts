#!/bin/bash

while getopts u:p:o:r:a: opt; do
	case $opt in
		u)
			CLIENT_ID=${OPTARG}
     	 	;;
		p)
			CLIENT_SECRET=${OPTARG}
   		   	;;
		o)
			ORGANIZATION=${OPTARG}
      		;;
        r)
            RESOURCE=${OPTARG}
            ;;
        a)
            ACTION=${OPTARG}
            ;;
  		\?)
      		echo "Invalid option: -$OPTARG" >&2
      		exit 1
      		;;
		:)
      		echo "Option -$OPTARG requires an argument." >&2
      		exit 1
      		;;
	esac
done

if [ -z ${CLIENT_ID} -o -z ${CLIENT_SECRET} ]; then
	source ~/.apigeerc
fi

if [ -z ${CLIENT_ID} ]; then
	echo "Missing mandatory option -u <client_id>" >&2
    exit 1
fi

if [ -z ${CLIENT_SECRET} ]; then
	echo "Missing mandatory option -p <client_secret>" >&2
    exit 1
fi

if [ -z ${ORGANIZATION} ]; then
    ORGANIZATION=$(echo ${USERNAME} | cut -d '@' -f 1)
fi

HOSTURL=https://api.usergrid.com
APIVERSION=v1
