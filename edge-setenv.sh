#!/bin/bash

OVERRIDE=0
TESTS_ONLY=0
LIVE_DEPLOYMENT=0

while getopts u:p:o:e:r:a:n:tl opt; do
	case $opt in
		u)
			USERNAME=${OPTARG}
     	 	;;
		p)
			PASSWORD=${OPTARG}
   		   	;;
		o)
			ORGANIZATION=${OPTARG}
      		;;
    	e)
			ENVIRONMENT="${OPTARG}"
			;;
        r)
            RESOURCE="${OPTARG}"
            ;;
        a)
            ACTION="${OPTARG}"
            ;;
        n)
            PROXY_NAME="${OPTARG}"
            ;;
        t)
            TESTS_ONLY=1
            ;;
        l)
            LIVE_DEPLOYMENT=1
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

shift $((OPTIND-1))

if [ -z ${USERNAME} -o -z ${PASSWORD} ]; then
	source ~/.apigeerc
fi

if [ -z ${USERNAME} ]; then
	echo "Missing mandatory option -u <username>" >&2
    exit 1
fi

if [ -z ${PASSWORD} ]; then
	echo "Missing mandatory option -p <password>" >&2
    exit 1
fi

if [ -z ${ORGANIZATION} ]; then
    ORGANIZATION=$(echo ${USERNAME} | cut -d '@' -f 1)
fi

if [ -z ${ENVIRONMENT} ]; then
    ENVIRONMENT="test"
fi

if [[ ${LIVE_DEPLOYMENT} -eq 0 &&  -z ${DEPLOYMENT_SUFFIX} ]]; then
    DEPLOYMENT_SUFFIX="-"$(echo ${USERNAME} | cut -d '@' -f 1)
else
    DEPLOYMENT_SUFFIX=""
fi

HOSTURL=https://api.enterprise.apigee.com
APIVERSION=v1
