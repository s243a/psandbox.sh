#!/bin/bash
function mount_fn2(){
  local a_dev
  local a_mp
  if [ ! -b /dev/$1 ]; then
    a_dev="$(blkid | grep -m1 $1 | cut -d ":" -f1)"
    a_mp="${bla//\/dev/\/mnt}"
    mount "$a_dev" "$a_mp" 
    $1="$a_mp"
  fi 
  if [ -d "$1/$2" ]; then
    #Make sure the directory isn't empty
    if [ ! -z "$(ls -A "$1/$2")" ]; then
      echo "$1/$2"
    fi
  elif [ -f "$1/$2" ]; then
    echo "$(mount_fn "$1/$2")"
  fi
}
function mount_fn(){
  local MNT_PT=''
  
    FULL_PATH=$(realpath "$1")
    loop=$(losetup | grep "$FULL_PATH" | sed "s/:.*$//" )
    if [ ${#loop} -eq 0 ]; then
      key=$(md5sum < <( echo "$FULL_PATH" ) | cut -f1 -d' ')
      key=${key:0:5}
      FNAME="$(echo "${FULL_PATH}__${key}" | sed 's#/#+#g' | sed 's#\.#+#g')"
    
      if [ ! -z "$2" ]; then
        MNT_PT="$(cat /proc/mounts | grep "$2" | grep -m1 $FNAME | cut -d ' ' -f2 )"              
        [ -z "$MNT_PT" ] && MNT_PT="$(cat /proc/mounts | grep -m1 "$2" | cut -d ' ' -f2 )"
        [ -z "$MNT_PT" ] && MNT_PT="$(cat /proc/mounts | grep -m1 $FNAME | cut -d ' ' -f2 )"            
     else
         MNT_PT="$(cat /proc/mounts | grep -m1 $FNAME | cut -d ' ' -f2)"   
         #if [ -f "$MNT_PT" ]; 
     fi
     if [ -z "${MNT_PT}" ]; then  
       #case "FNAME" in
       #*.iso)
       #   DIR_PATH=/media; ;;
       #*)
         DIR_PATH=/mnt #; ;;
       #esac
       #if [ -z "$2" ]; then
        # MNT_PT="$2"
       #fi
       #[ -z "$MNT_PT" ] && MNT_PT="${DIR_PATH}/$FNAME"
       LN=${#FNAME}
       start="$((LN-MAX_STR_LEN-4))"
       if [ "$start" -lt 0 ]; then
         start=0
       fi 
       FNAME=${FNAME:$start}
       MNT_PT="${DIR_PATH}/$FNAME"
      
       mkdir -p "${MNT_PT}"
       mount $FULL_PATH "${MNT_PT}"     
       MNT_PT="$(cat /proc/mounts | grep -m1 $FNAME | cut -d ' ' -f2 )"          
     fi
   else
     MNT_PT="$(cat /proc/mounts | grep $loop | cut -d " " -f2)"
   fi
  echo  "${MNT_PT}"
}
# -f|--full-path
#     The full file path of the mount point
# -m|--mount-point
#     The mount point
# -p|--partition|-pdrv 
#     The partion where the file to be mounted is located
# -d|--mount-directory
#     By default directors aren't mounted, instead the path is just retured

#https://stackoverflow.com/questions/2683279/how-to-detect-if-a-script-is-being-sourced
if [[ "${BASH_SOURCE[0]}" = "${0}" ]] || [ $(echo ${0##*/} | grep -m1 -E -c '(bash|dash|ksh|sh|dash)') -eq 0 ]; then 

	declare -a options="$(getopt -o i:,m:,p:,d: --long item-path:mount-point:,pdrv:,partition: -- "$@")"
	declare -a options2
	
	eval set --"$options"
	while [ $# -gt 0 ]; do
	  case "$1" in
	  -i|--item-path)
	    ITEM=$1; shift 2; ;; 
	  -m|--mount-point)   
	    MOUNT_POINT="$1"; shift 2; ;;
	  -p|--pdrv|--partition)
	    PDRV=$1; shift 2; ;;
	  --) 
	    shift 1
	    options2+=( "$@" )
	    break; ;;
	  *)
	    params+=("$1")
	    shift 1;
	    ;;
	   esac
	done
	#function read_blkid(){
	#
	#}
	
	for param in "$@" "${options2[@]}"; do #Probably don't need options2
	  if [ -z "$PDRV" ]; then
	    dev=${param//\/mnt/\/dev}
	    if [ -b "$dev" ]; then
	      PDRV="$dev"
	      continue
	    fi
	    dev="$(cat /proc/mounts | grep "$param" | cut -d ' ' -f1)"
	    if [[ "$dev" = /dev/* ]]; then
	      PDRV="$dev"
	      continue
	    fi
	  fi
	  if [ -z "$ITEM" ]; then
	    ITEM=$2; shift 2;
	    continue
	  fi
	  if [ -z "$ITEM" ]; then
	    MOUNT_POINT=$2; shift 2;
	    break
	  fi
	done 
	declare -a options3
	for option in "$PDRV" "$ITEM" "$MOUNT_POINT"; do
	  [ -z "$option" ] && continue
	  options3+=("$option")
	done
	if [ -z "$PDRV" ]; then
	  mount_fn ${options[@]}
	else
	  mount_fn2 ${options[@]}
	fi
fi	