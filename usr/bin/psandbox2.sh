#!/bin/bash
#Based on James Budiono 2015 sandbox.sh (version 10) but with many options added
# version 10 - (2015) use pid/mount namespaces if available
#
# 0. directory locations
#. $BOOTSTATE_PATH # AUFS_ROOT_ID
#XTERM="defaultterm"
#
# All options below were added by s243a:
#
# f, --input-file
#    read layer paths from a file rather than reading existing layers
# -o, --output-file 
#    Just write layer paths to an output file but don't mount the sandbox. 
# --no-exit
#    if an output file is specified (i.e. -o or --output-file) layer paths are just written to a file and the program exits unless the no-exit flag is specified.
# -p|--env-prefix
#    TODO: Not yet defined. See if there is any old code related to this. 
#    enviornental variable prefix
# -m,--pmedia
#    Used to emulate the pmedia boot parmater. This helps to determine the pup mode. 
# d, --pdrv
#    this is the particiaion where the puppy files are located. The default is /mnt/home
# s, psubdir
#    this is the sub directory where the puppy files are located
#  --maybe-psubdir
#    get the layers from a given sub directory if no layers were found via the previous options.  
#  --distro-specs
#    path to distro specs (e.g. /etc/DISTRO_SPECS; e.g. /initrd/distro-specs)
#    this file is sourced to provide information about the pup layers. 
# c, --clear-env (Not yet implemented, but option processed)
#    deletes enviornental variabls
# b --boot-config (Not Yet Implemented, but option processed)
#    path to boot config (e.g. /etc/rc.d/BOOTCONFIG). This file provides information about extra sfs layers to add. If this option apears after psubdir then the layring will be like a standard puppy. 
#   --union-record (Not yet implemented, but option processed)
#   Specifies the main pup layers but file name only rather than the full path to the sfs. This is usually defined in boot-config. 
#  --aufs
#   With this option the currently mounted layers are used as part of the sandbox. 
#  --maybe-aufs
#   Same as aufs, but is only used if the layers aren't already selected by a previous option. 
# -t|--tmpfs
#   Use ram as the top layer. If no path is specified then tmpfs will be mounted. 
#  -r|--root
#   Specifies the parrent directory of the chroot folder. This parent directory is called SANDBOX_ROOT. By default this is /mnt/sb. See the option --fake-root, for the actual chroot folder. 
#  -f|-n|--fake-root|--new-root
#   Specifies the chroot folder. /mnt/sb/fakeroot. If this is occupied by a previous sandbox then the default is /mnt/sb/fakeroot.sandboxID Relative paths are assumed to be a subdirectory of SANDBOX_ROOT (see the --root option above). Currently, all these options do the same thing but thought behind the --new-root option is that we might try moving a mount point. The effect of this is to hide what is underneath the old mount point. This is simmilar to a chroot but would impact the whole system! 
#    This is a risky/experimental option. The idea
#  --pupmode
#   This option is used to emulate a pupmode. The default pupmode is "2" which emulates a full install. 
# --layer
#   Specify a layer of the layered file system. Layers are added as per the order that they apear as arguments. 
#   a subgke kater
# -l|--logfile
#   Standard error and standard output will copied to this file while the logger is on. 
# -t|--trace
#   Uses the set -x option in the areas of code where the logger is on. 
# -a|--copy-Xauth
#   Copy the Xauthority into the chroot. 
#  -u|--bind-X11-sockets
#   Bind the X11 sockets into the chroot. The default folder to bind is /tmp/.X11-unix
#  -r|--copy-resolv_conf
#   Copy /etc/resolve.conf into the chroot.
#  e, --extra-sfs
#   a list of extra sfs files (space seperated)
#  u, --union-record
# --xterm
# --sandbox
# -initrd
# --rev-bind 
#  Bind one or more folders from the sandbox into the main system
#  --before-chroot
#  Enter an arbitrary command immediatly before entering the chroot folder (e.g. start a samba server)
#  --bind
#  Bind arbitrary directories from the host system into the chroot. For safety reasons binds are not recursive but the option for recursive binds may be implemented at a later date. 
# 


#I thought some assoitive arrays might be useful but I'm not using them yet. 
#declare -A KEYs_by_MNT_PT
#declare -A KEYs_by_FILE_PATH
#declare -A KEYs_by_trimmed_MNT_PT
#declare -A KEYs_by_trimmed_FILE_PATH
#declare -A MNT_PTs
#declare -A FILE_PATHs
#declare -A ON_status
CWD=$(realpath .)
CWD_parent=$(realpath ..)
[ -z "$CWD" ] && CWD="$PWD"
declare -a bind_sources
declare -a bind_targets
declare -a rev_bind_sources
declare -a rev_bind_targets
cd "$(dirname "$0")"
MAX_STR_LEN=50
SANDBOX_ID=
TMPFILE=$(mktemp -p /tmp)
# use namespaces if available
#[ -e /proc/1/ns/pid ] && [ -e /proc/1/ns/mnt ] && type unshare >/dev/null && USE_NS=1
PUPMODE=2
XTERM=${XTERM:-urxvt}
SANDBOX_ROOT=${SANDBOX_ROOT:-/mnt/sb}

declare -a options2
declare -a binds
LOG_INITIALIZED=false

RP_FN="`which realpath`"
RP_TARGET=$($RP_FN "$RP_FN")
[ -z "$RP_TARGET" ] && RP_TARGET="`readlink $RP_FN`"
declare -a del_rules_filter
declare -a del_rules_action
declare -a umount_rules_filter
declare -a umount_rules_action

unset SANDBOX_ID
unset rwbranch
unset FAKEROOT
unset SANDBOX_TMPFS
unset FAKEROOT_dir
unset SANDBOX_IMG
FAKEROOT_SET=false

function realpath(){
  	case "$RP_TARGET" in
  	*busybox*)
  	  if [ "$1" = -m ]; then
  	    shift
  	    A_PATH=$1
  	    A_PATH=$(echo "$A_PATH" | sed 's#^./#'"$CWD"'#g' )
  	    A_PATH=$(echo "$A_PATH" | sed 's#^../#'"$CWD_parent"'#g' ) #&& A_PATH=$(dirname $A_PATH)
  	    
  	    echo "Warning simulating '-m' option since it isn't supported by busybox" >&2
  	    echo "A_PATH=$A_PATH" >&2
  	    if [ -f  "$A_PATH" ] || [ -d  "$A_PATH" ]; then
  	      $RP_FN "$@"
  	    else
    	  echo "$A_PATH"
    	fi
  	  else
  	    $RP_FN "$@"
  	  fi
  	  ;;
  	*)
  	  $RP_FN "$@"
  	  ;;
  	esac 
}
export -f realpath

if [ -f ../local/psandbox/sandbox.awk ]; then 
  SANDBOX_AWK="$(realpath ../local/psandbox/sandbox.awk)"
elif [ -f /usr/local/psandbox/sandbox.awk ]; then
 SANDBOX_AWK=/usr/local/psandbox/sandbox.awk
fi
SANDBOX_AWK_DIR="$(dirname $SANDBOX_AWK)"
if [ -f ../local/psandbox/sb_db_rec_field.awk ]; then
  SB_DB_REC_FIELD_AWK="$(realpath ../local/psandbox/sb_db_rec_field.awk)"
elif [ -f /usr/local/psandbox/sb_db_rec_field.awk ]; then
  SB_DB_REC_FIELD_AWK=/usr/local/psandbox/sb_db_rec_field.awk
fi

if [ -f ../local/psandbox/sandbox_mnt_fn.sh ]; then
  SANDBOX_MNT_FN="$(realpath ../local/psandbox/sandbox_mnt_fn.sh)"
elif [ -f /usr/local/psandbox/sandbox_mnt_fn.sh ]; then
  SANDBOX_MNT_FN=/usr/local/psandbox/sandbox_mnt_fn.sh
fi

. "$SANDBOX_MNT_FN"
function set_pdrv(){
	local a_dir
	if [ -z "$PDRV" ]; then
	   if [ -f "$savebranch" ]; then
	     a_dir="$(dirname "$savebranch")"
	   elif [ -d  "$savebranch" ]; then
	     a_dir="$savebranch"
	   else
	     a_dir=$(readlink /mnt/home)
 	     PDRV="$(df -h . | sed -r 's#^(.*[%][[:blank:]]+)([^[:blank:]]+)$#\2#g' | tail -n1)"
 	   fi
	fi
}

function find_real_pdrv(){
	#!!!! New find PDRV code
	if [ ! -z "$SANDBOX_ROOT" ]; then
	  DEV_SAVE=$SANDBOX_ROOT/dev_save
	  mkdir -p "$DEV_SAVE"
	  if [ -z "$PDRV" ]; then
	    if [[ "$SANDBOX_IMG" = *"/mnt/"* ]]; then
	      PSUBDIR_rw=${SANDBOX_IMG#/mnt/*/}
	      PDRV_rw=${SANDBOX_IMG%"/$PSUBDIR_rw"}
	      PDRV_real=$(cat /proc/mounts | grep $(realpath $PDRV_rw) | cut -d " " -f1)
	          PSUBDIR_i=${PSUBDIR}
	          PDRV_i=${PDRV}
	          PDRV_real_i=${PDRV_real}      
	      while (true); do
	 
	          if [[ PDRV_real_i = /dev/loop* ]]; then
	            PDRV_real_i=$(losetup-FULL -a | grep "$(basename PDRV_real)")
	            PDRV_real_i=${PDRV_real#*(}
	            PDRV_real_i=${PDRV_real%)}
	            PSUBDIR_i=${PDRV_real_i#/mnt/*/}
	            PSUBDIR_rw=$PSUBDIR_i/$PSUBDIR_rw
	            PDRV_real_i=${SANDBOX_IMG%"/$PSUBDIR_i"}
	            PDRV_real_i=$(cat /proc/mounts | grep $(realpath $PDRV_real_i) | cut -d " " -f1)
	          elif [[ PDRV_real_i = /dev/* ]]; then
	            PDRV_real=$(blkid | grep $PDRV_real)
	            break
	          else
	            echo "could not identify PDRV_real"
	            break
	          fi
	          
	      done
	    fi
	  fi
	fi
}
function get_items(){
    local out
    OUTFILE=/tmp/get_items_out
    rm "$OUTFILE"
    cd "$SANDBOX_AWK_DIR"
    out+="$(
  { echo ==mount==; cat /proc/mounts; 
    echo ==losetup==; losetup-FULL -a; 
    echo ==branches==; 
      if [ $# -eq 0 ]; then
        ls -v /sys/fs/aufs/$AUFS_ROOT_ID/br[0-9]* | xargs sed 's/=.*//';
      else
        if [ "$1" = "-f" ]; then
          cat "$2";
        elif [ "$1" = "-s" ]; then
          cat <<<"$2";
        fi;
      fi; } | \
    awk -v PDRV="$PDRV" -v MAX_STR_LEN="$MAX_STR_LEN" -v OUTFILE="$OUTFILE" \
-f "$SANDBOX_AWK"
)"
  echo "$out"
}
function process_psubdir(){
	  item_source="$1"
      if [ "$item_source" = "maybe-psubdir" ]; then
         [ ! -z "$items" ] && continue
      fi
      [ -z "$DISTRO_ADRVSFS" ] && DISTRO_ADRVSFS="$(ls -1 "${PDRV}/${PSUBDIR}" | grep -i -m1 'adrv.*\.sfs$')" 
      [ -z "$DISTRO_YDRVSFS" ] && DISTRO_YDRVSFS="$(ls -1 "${PDRV}/${PSUBDIR}" | grep -i -m1 'ydrv.*\.sfs$')"   
      [ -z "$DISTRO_ZDRVSFS" ] && DISTRO_ZDRVSFS="$(ls -1 "${PDRV}/${PSUBDIR}" | grep -i -m1 'zdrv.*\.sfs$')"
      [ -z "$DISTRO_FDRVSFS" ] && DISTRO_FDRVSFS="$(ls -1 "${PDRV}/${PSUBDIR}" | grep -i -m1 'fdrv.*\.sfs$')"                        
      [ -z "$DISTRO_PUPPYSFS" ] && DISTRO_PUPPYSFS="$(ls -1 "${PDRV}/${PSUBDIR}" | grep -i -m1 'puppy_.*\.sfs$')"

      new_items=""
      for rec in "$DISTRO_ADRVSFS" "$DISTRO_YDRVSFS" "$DISTRO_ZDRVSFS" "$DISTRO_FDRVSFS" "$DISTRO_PUPPYSFS";  do
        #MNT_PATH="${rec}"
        [ -z "$rec" ] && continue
        #[ ! -z "${PSUBDIR}" ] && MNT_PATH=${PSUBDIR}/${MNT_PATH}
        MNT_PATH="${PDRV}/${PSUBDIR}/$rec"
        MNT_PT="$(mount_fn "$MNT_PATH")"
        new_items+="\"${MNT_PT}\" \"$rec\" \"on\""$'\n' 
        
      done
      #export new_items="$new_items"
      #echo "$new_items"
     
      new_items_result="$(get_items -s "$new_items")"$'\n' 
      # log stop
      #log start
      items+="$new_items_result" 
      #echo "items+=\"$new_items_result\""
      #echo "Exiting process_psubdir()"
      # read -p "Press enter to continue"
      #log start
      
}
process_union_record(){
       new_items=''
       for rec in $LASTUNIONRECORD; do
        if [ -f "$rec" ]; then
          MNT_PT="$(mount_fm "$rec" )"
          new_items+="\"$MNT_PT\" \"$rec\" \"on\""$'\n'
        elif [ -f "$PDRV/$rec" ]; then
          MNT_PT="$(mount_fm "$PDRV/$rec" )"
          new_items+="\"$MNT_PT\", \"$PDRV/$rec\", \"on\""$'\n'
        fi
      done 
      items+="$(get_items -f <<<"$new_items")"$'\n' 	
}
process_extra_sfs(){
     EXTRASFSLIST="$2";
     unset new_items
     if [ ! -f "$EXTRASFSLIST" ]; then
       EXTRASFSLIST_tmp=$(realpath "$PDRV/$PSUBDIR/$EXTRASFSLIST")
       if [ -f "$EXTRASFSLIST_tmp" ]; then
         EXTRASFSLIST="$EXTRASFSLIST_tmp"
       fi
     fi
     if [ ! -f "$EXTRASFSLIST" ]; then
       EXTRASFSLIST_tmp=$(realpath "$PDRV/$EXTRASFSLIST")
       if [ -f "$EXTRASFSLIST_tmp" ]; then
         EXTRASFSLIST="$EXTRASFSLIST_tmp"
       fi
     fi
     if [[ "$EXTRASFSLIST" = *.sfs ]]; then
         a_sfs="$EXTRASFSLIST"
         MNT_PT="$(mount_fn "$a_sfs" )"
         new_items+="\"$MNT_PT\" \"$a_sfs\" \"on\""$'\n'
     else
       while read a_sfs; do
         a_sfs=$(echo"$a_sfs") #Trims leading and trailing whitespace
         if [ -f "$a_sfs" ]; then
           a_sfs=$(realpath "$a_sfs")
         else
           a_sfs1="$PDRV/${PSUBDIR}/$a_sfs"
           a_sfs=$(realpath "$a_sfs")
           if [ -f "$a_sfs"]; then
             a_sfs=$(realpath "$a_sfs")
           else         
             a_sfs1="$PDRV/$a_sfs1"
             if [ -f "$a_sfs1" ]; then
               a_sfs=$(realpath "$a_sfs")
             fi             
           fi 
         fi
         if [ -f  "$a_sfs" ]; then
           MNT_PT="$(mount_fn "$a_sfs" )"
           new_items+="\"$MNT_PT\" \"$a_sfs\" \"on\""$'\n'         
         fi
       done <"$EXTRASFSLIST"
     fi	
     items+="$(get_items -s "$new_items")"$'\n'
     #items+="$(get_items -f <<<"$new_items")" 
}
process_layer(){
      item_path="$2"
      if [ -f "$item_path" ]; then
        MNT_PT="$(mount_fm "$item_path" )"
      elif [ -d "$item_path" ]; then  
        MNT_PT="$item_path" #This isn't really a mount poing
      elif [ ! -d  "$item_path" ]; then
        echo "Warning  cannot mount $item_path"
        continue
      fi
      items+="\"$MNT_PT\" \"$item_path\" \"on\""$'\n'	
}

function mount_items(){
  local Moun_Point
  local File_PATH #Might be a directory
  cd "$SANDBOX_AWK_DIR"
  while IFS="" read -r p || [ -n "$p" ]; do #https://stackoverflow.com/questions/1521462/looping-through-the-content-of-a-file-in-bash
     File_PATH="$(echo "$1" | awk -v FIELD_NUM=6 -f "$SB_DB_REC_FIELD_AWK")"
     Mount_Point="$(echo "$1" | awk -v FIELD_NUM=1 -f "$SB_DB_REC_FIELD_AWK")"
     PDRV_MNT="$(echo "$1" | awk -v FIELD_NUM=7 -f "$SB_DB_REC_FIELD_AWK")"
     PDRV_UUID="$(echo "$1" | awk -v FIELD_NUM=8 -f "$SB_DB_REC_FIELD_AWK")"
     
     [ -z "$PDRV_MNT" ] && 
     mount_fn2 "PDRV" "$File_PATH" "$Moun_Point"
  done <"$1"
}
function log(){
  local SET_X=false
  set +x #TODO add more verbose log option that doesn't do this. 
  local logfile="${2}"
  local trace="$3"
  #[ -z "$logfile" ] && LOGFILE 
  #[ -z "$trace" ] && trace=TRACE
  if [ ! -z "$LOGFILE" ]; then
    case "$1" in
    init)
      [ "$TRACE" = true ] && SET_X=true
      [ ! -f "$LOGFILE" ] && rm "$LOGFILE"
      exec 6>&1           # Link file descriptor #6 with stdout.
      exec 7>&2
      #exec &1> >(tee -a "$LOGFILE")
      #exec &2> >(tee -a "$LOGFILE")
      [ ! -f "$LOGFILE" ] && touch "$LOGFILE"
      #exec &> >(tee -a "$LOGFILE")
      ;;
    start)
      [ "$TRACE" = true ] && SET_X=true
      #exec &1> >(tee -a "$LOGFILE")
      #exec &2> >(tee -a "$LOGFILE") 
#      exec 6>&1           # Link file descriptor #6 with stdout.
#      exec 7>&2      
      exec 1>&6           # Link file descriptor #6 with stdout.
      exec 2>&7    
      exec &> >(tee -a "$LOGFILE") 
      ;;
    stop)
      #https://stackoverflow.com/questions/21106465/restoring-stdout-and-stderr-to-default-value
      #[ "$TRACE" = true ] && set +x
      exec 1>/dev/null           # Link file descriptor #6 with stdout.
      exec 2>/dev/null                  
#      exec 1>&6  
#      exec 6>&-      # Restore stdout and close file descriptor #6.
      #exec 2> /dev/stderr    
#      exec 2>&7  
#      exec 7>&-
      ;;
    esac
  fi 	
  [ "$SET_X" = true ] && set -x
}



safe_delete(){
    unset safe_delete_result
    POLICY="" #Default action if no rule is found
  if [ ! -z "$(cat /proc/mounts | grep -F "$(ls -1d $1 | sed 's:/$::')" - )" ] ||
     [ ! -z "$(cat /proc/mounts | grep -F "$(ls -1d $1 | xargs realpath )" - )" ] ; then
          #It is not safe to delete a mounted directory
          safe_delete_result=1 #This is in case one doesn't want to use the return status right away
          return 1    
  else
    PATH_TO_DEL="$(realpath -m $1)"
    [ -d "$PATH_TO_DEL" ] && "PATH_TO_DEL=$PATH_TO_DEL/"
    for a_rule_key in "${!del_rules_filter[@]}"; do
      rule_i="${del_rules_filter[$a_rule_key]}"
      if [ ! -z "$(echo $PATH_TO_DEL | grep -E "$rule_i")" ] ||
         [[ "$PATH_TO_DEL" = $rule_i ]]; then
        action="${del_rules_action[$a_rule_key]}"
        case $action in
        DELETE)
          safe_delete_result=0 #This is in case one doesn't want to use the return status right away
          return 0
          break #This is probably redundant
          ;;
        KEEP)
          safe_delete_result=1 #This is in case one doesn't want to use the return status right away
          return 1
          break #This is probably redundant
          ;;          
        POLICY_KEEP)
          POLICY=KEEP
          ;;    
        POLICY_DELETE)
          POLICY=DELETE
          ;;    
        esac
      fi
    done
    if [ -z ${safe_delete_result+x} ]; then #If we don't have a result yet set result based on policy
      case "$POLICY" in
      KEEP)
        safe_delete_result=1
        return 1; ;; 
      DELETE)
        safe_delete_result=0
        return 0; ;;
      *)
        echo "No Delete policy set, so keeping file/dir $1"
        safe_delete_result=1
        return 1    
      esac
    fi
  fi
}
safe_umount(){
    unset safe_umount_result
    POLICY="" #Default action if no rule is found
    PATH_TO_UMOUNT="$(realpath -m $1)"
    [ -d "$PATH_TO_UMOUNT" ] && PATH_TO_UMOUNT="$PATH_TO_UMOUNT/" #TODO, this should always be true so add error if it is not.
 
    for a_rule_key in "${!umount_rules_filter[@]}"; do
      rule_i="${umount_rules_filter[$a_rule_key]}"
      if [ ! -z "$(echo $1 | grep -E "$rule_i")" ] ||
        [[ "$PATH_TO_UMOUNT" = $rule_i ]]; then
        action="${umount_rules_action[$a_rule_key]}"
        case $action in
        DELETE)
          safe_umount_result=0 #This is in case one doesn't want to use the return status right away
          return 0
          break #This is probably redundant
          ;;
        UMOUNT)
          safe_umount_result=1 #This is in case one doesn't want to use the return status right away
          return 1
          break #This is probably redundant
          ;;          
        POLICY_KEEP)
          POLICY=KEEP
          ;;    
        POLICY_UMOUNT)
          POLICY=UMOUNT
          ;;    
        esac
      fi
    done
    if [ -z ${safe_umount_result+x} ]; then #If we don't have a result yet set result based on policy
      case "$POLICY" in
      KEEP)
        safe_umount_result=1
        return 1; ;; 
      UMOUNT)
        safe_umount_result=0
        return 0; ;;
      *)
        echo "No Delete policy set, so keeping file/dir $1"
        safe_umount_result=1
        return 1    
      esac
    fi
  
}
umountall() {
  {
  log start
  set -x
  
  FAKEROOT="$(echo "$FAKEROOT" | sed -r 's#/$##g')"
  #R_FR=$(realpath -m "$FAKEROOT")
  #[ ${#R_FR} -lt 2 ] && exit
  safe_umount $SANDBOX_TMPFS
  [ $safe_umount_result -eq 0 ] && umount -l $SANDBOX_TMPFS
  if [ PUPMODE = 2 ]; then #Full Install
      safe_umount $FAKEROOT/tmp
      umount -l $FAKEROOT/tmp
    else
      safe_umount $FAKEROOT/initrd/mnt/tmpfs
      [ $safe_umount_result -eq 0 ] && umount -l $FAKEROOT/initrd/mnt/tmpfs
    fi
  for layer_name in "pup_ro2" "pup_ro3" "pup_ro4" "pup_ro5" "pup_z"; do
    layer="$(eval 'echo $'$layer_name)"
    if [ ! -z "$layer" ] ; then
      safe_umount "$FAKEROOT/initrd/$layer_name"
      [ $safe_umount_result -eq 0 ] && umount -l "$FAKEROOT/initrd/$layer_name"
    fi
  done 
  for aFolder in /proc /sys /dev ""; do
     safe_umount $FAKEROOT"/$aFolder"
     [ $safe_umount_result -eq 0 ] && umount -l $FAKEROOT$aFolder
  done
  
  
  if [ -z "$RW_LAYER" ]; then
    safe_umount "$SANDBOX_TMPFS"
    [ $safe_umount_result -eq 0 ] && umount -l $SANDBOX_TMPFS
    safe_delete "$SANDBOX_TMPFS"
    [ $safe_delete_result -eq 0 ] && rmdir $SANDBOX_TMPFS
  fi
  
  safe_delete $FAKEROOT
  [ $safe_delete_result -eq 0 ] && rmdir $FAKEROOT
 
  } # 2> /dev/null
}
function choose_save(){
    # location not specified - then ask
    log stop
    dialog --backtitle "rw image sandbox" --title "choose rw image" \
    --extra-button --extra-label "Create" --ok-label "Locate" \
    --yesno "You didn't specify the location of the rw image file. Do you want to locate existing file, or do you want to create a new one?" 0 0
    chosen=$?
    log start
    case $chosen in
        0) # ok - locate
            log stop
            dialog --backtitle "rw image sandbox" --title "Specify location of existing rw image" --fselect `pwd` 8 60 2> $TMPFILE
            savebranch=`cat $TMPFILE`
            log start
            rm $TMPFILE
            if [ -n "$savebranch" ]; then
                if [ -d "$savebranch" ]; then
                  case "$savebranch" in
                  "/mnt"|"/mnt/"|"/mnt/home"|"/mnt/home/"|"/")
                    log stop
                    echo "warning chose the following savebranch $savebranch"
                    read -p "Press enter to continue"
                    log start
                    set_sandbox_img ""
                    ;;
                  esac
                  SANDBOX_IMG=$savebranch
                elif [ ! -f "$savebranch" ]; then
                    echo "$savebranch doesn't exist - exiting."
                    echo "will use tmpfs instead"
                    log stop
                    read -p "Press enter to continue"
                    log start
                    savebranch=""
                else
                  set_sandbox_img ""                    
                fi
            else
                echo "You didn't specify any file or you pressed cancel. Exiting."
                exit
            fi
            ;;
        3) # create
            echo "create"
            log stop
            dialog --backtitle "save image sandbox" --title "Specify name and path of new the file" --fselect `pwd` 8 60 2> $TMPFILE
            savebranch=`cat $TMPFILE`
            log start
            rm $TMPFILE
            if [ -n "$savebranch" ]; then
                if [ -f "$savebranch" ]; then
                    echo "$savebranch already exist - exiting."
                    exit
                else
                    # get the size
                    log stop
                    dialog --title "Create new save image" --inputbox "Specify size (in megabytes)" 0 40 100 2> $TMPFILE
                    size=`cat $TMPFILE`
                    log start
                    rm $TMPFILE
                    
                    if [ -n "$size" ]; then
                        if dd if=/dev/zero of="$savebranch" bs=1 count=0 seek="$size"M; then
                            if ! mke2fs -F "$savebranch"; then
                                echo "I fail to make an ext2 filesystem at $savebranch, exiting."
                                exit
                            fi
                        else
                            echo "I fail to create a ${size}M file at $savebranch,, exiting."
                            exit
                        fi
                    else
                        echo "You didn't specify the size or your press cancel. Exiting."
                        exit
                    fi                  
                fi
            else
                echo "You didn't specify any file or you pressed cancel. Exiting."
                exit
            fi
            ;;
        1 | 255) # 1 is cancel, 255 is Escape
            echo "Cancelled - exiting."
            exit
            ;;
        *) # invalid input - treat as cancel
            echo "Cancelled - exiting."
            exit
            ;;
    esac
}
function find_save(){
  for prefix in '${DISTRO_FILE_PREFIX}save' '.*save'; do
    for dir in "$PDRV/${PSUBDIR}" "PDRV";  do
       
      ONE_SAVE="$(ls $dir -1 | grep -m "${prefix}save")"
      if [ -z "$ONE_SAVE" ]; then
         continue
      else
         SAVE_FILE="$ONE_SAVE"
         FULL_SAVE_PATH="$dir"/ONE_SAVE
         break
      fi
    done
   done
   echo "PSAVE"
   mount_items
}
function find_bk_folders(){
  for a_PDRV in "$PDRV" sr0 sr1; do #Consider adding /mnt/home here
    for a_psubdir in "${PSUBDIR}" "";  do
      MT_PT_of_Folder="$(mount_fn2 "$PDRV" "${PSUBDIR}")"
      #https://github.com/puppylinux-woof-CE/woof-CE/blob/c483d010a8402c5a1711517c2dce782b3551a0b8/initrd-progs/0initrd/init#L981
      BKFOLDERS="$(find $MT_PT_of_Folder -maxdepth 1 -xdev -type d -name '20[0-9][0-9]-[0-9][0-9]-[0-9][0-9]-[0-9][0-9]-[0-9][0-9]' | sed -e s%^${SAVE_MP}/%% | sort -r)"
      [ ! -z "#BKFOLDERS" ] && break   
    done
  done
}
function mk_initrd_dir(){
  mkdir -p "$FAKEROOT"/initrd
  if [ -z "$PUPMODE" ] ; then
    if [ -z "$PMEDIA" ]; then
      #if [ "$PUPMODE" = 5 ] ; then
      #  #aufs layers:              RW (top)      RO1             RO2              PUPMODE
      #  #First boot (or pfix=ram): tmpfs                         pup_xxx.sfs      5
      PUPMODE=5 #MAYBE PUPMODE=2 would be better
    elif [ PMEDIA = 'atahd' ] || [ "$PMEDIA" = 'usbhd' ]; then
      find_save
      if [ -f "$FULL_SAVE_PATH" ] || [ -d "$FULL_SAVE_PATH" ]; then
        #aufs layers:               RW (top)      RO1             RO2              PUPMODE
        #Normal running puppy:      pup_save.3fs                  pup_xxx.sfs      12      
        PUPMODE=12
      else
        echo "Invalid SAVE_PATH=$SAVE_PATH does not exist"
        PUMPMODE=2
        #TODO, prompt to either search for save file/folder or alternatively create it. 
      fi
    elif [ PMEDIA = 'usbflash' ] || [ pmedia = 'ideflash' ]; then
      find_save
      #aufs layers:                 RW (top)      RO1             RO2              PUPMODE
      #ditto, but flash drive:      tmpfs         pup_save.3fs    pup_xxx.sfs      13
      if [ -f "$SAVE_PATH" ] || [ -d "$SAVE_PATH" ]; then
        #aufs layers:               RW (top)      RO1             RO2              PUPMODE
        #ditto, but flash drive:    tmpfs         pup_save.3fs    pup_xxx.sfs      13
        PUPMODE=13
      else
        echo "Invalid SAVE_PATH=$SAVE_PATH does not exist"
        PUPMODE=5
      fi
    elif [ "$PMEDIA" =  usbcd ] || [ "$PMEDIA" =  idecd ] || [ "$PMEDIA" =  satacd ] ; then 
      find_bk_folders
      if [ ! -z "$BKFOLDERS" ]; then
        PUPMODE=77  #MULTI-Session CD
      else #First Boot
        find_save
        if [ -f "$FULL_SAVE_PATH" ] || [ -d "$FULL_SAVE_PATH" ]; then
          PUPMODE=13      
        else
          PUPMODE=5
        fi
      fi
      #aufs layers:            RW (top)      RO1             RO2              PUPMODE
      #Multisession cd/dvd:       tmpfs         folders         pup_xxx.sfs      77
    else #[PUPMODE=2 -> full install
      PUPMODE=2
    fi
    #TODO: add option to make initrd anyway even if full install. For now make it regardless:
    if [ "$PUPMODE" = 2 ] && [ 1 -ne 1 ]; then #Full install; then #Full install
      echo "Full install has no initrd"
    else
      mkdir -p "$FAKEROOT/initrd"
      cd $FAKEROOT/initrd
      if [ "$PUPMODE" = 12 ]; then # Usually [ PMEDIA = 'atahd' ] || [ "$PMEDIA" = usbhd ] 
        ln -s mnt/dev_save/"${SAVE_PATH}" pup_rw
      elif [ "$PUPMODE" = 13 ] || [ "$PUPMODE" = 5 ] || [ "$PUPMODE" = 77 ]; then 
        ln -s mnt/tmpfs/pup_rw pup_rw
        if [ "$PUPMODE" = 13 ]; then  # Usually [ PMEDIA = 'usbflash' ] || [ pmedia = 'ideflash' ]
          ln -s "mnt/tmpfs/dev_save/${SAVE_PATH}" pup_ro1
        elif [ "$PUPMODE" = 77 ]; then
          ln -s mnt/tmpfs/pup_ro1/"${SAVE_PATH}" pup_ro1  #Usually [ "$PMEDIA" =  usbcd ] || [ "$PMEDIA" =  idecd ] || [ "$PMEDIA" =  satacd ] 
        fi
      fi
      #!!!! This code was moved from elsehwere inside this section. 
       mkdir -p "$FAKEROOT/initrd/mnt/dev_save"
      mount -o bind  /mnt/home "$FAKEROOT/initrd/mnt/dev_save"
      mkdir $FAKEROOT/mnt
      cd $FAKEROOT/mnt
      ln -s ../initrd/mnt/dev_save
      cd $FAKEROOT
      mount -o bind $SANDBOX_IMG initrd/mnt/tmpfs/pup_rw #not sure if this applies to all pupmodes.     
    fi
  fi
}
function set_fakeroot(){
    unset CLEANUP_SANDBOX_ROOT
    # if SANDBOX_ROOT is set to null then set it in this function
    # if FAKEROOT is null then this implies "/"
    if [ -z ${FAKEROOT+x} ]; then # && [ $FAKEROOT_SET != true ] 
      FAKEROOT_SET=false
      FAKEROOT=fakeroot
      CLEANUP_SANDBOX_ROOT=yes #TODO: figure out why I set this here. 
      if [ -z "${SANDBOX_ROOT}" ] ; then
        SANDBOX_ROOT=/mnt/sb
      fi
    fi
    if [ ! -z ${SANDBOX_ROOT+x} ] || [ ${#FAKEROOT} -gt 1 ]; then 
 
      #When  $FAKEROOT_SET = false then     
      #SANDBOX_ROOT will not be set yet unless suplied by an option or if FAKEROOT isn't specified
      if [ ${#SANDBOX_ROOT} -gt 1 ] && [ $FAKEROOT_SET = false ]; then
        FAKEROOT=$SANDBOX_ROOT/$FAKEROOT
        FAKEROOT_SET=true
      elif [ ! -z ${FAKEROOT+x} ]; then
        FAKEROOT_SET=true #A empty value for FAKEROOT implies we will mount over "/". This is experimental! Warnings will be given!
      fi
       FAKEROOT_dir="${FAKEROOT%/*}"
      [ -z "${SANDBOX_ROOT}" ] && SANDBOX_ROOT=${FAKEROOT_dir}
      if grep -q $FAKEROOT /proc/mounts; then
        if [ ! "$SANDBOX_ROOT" = /mnt/sb ]; then #TODO: we might also want to rename root under other circumstances. 
            log stop
            dialog --backtitle "rename root" --title "already mounted" \
            --extra-button --extra-label "Rename" --ok-label "Keep" \
            --yesno "FAKEROOTI is already a mount point. Rename Root?" 0 0
            chosen=$?
            log start      
           case "#chosen" in
           1)
             RENAME_ROOT=yes; ;;
           0)
             RENAME_ROOT=no; ;;
           esac
           
        else
          RENAME_ROOT=yes
        fi  
        
        if [ "${RENAME_ROOT}" = yes ]; then     
          FAKEROOT=$(mktemp -d -p ${FAKEROOT%/*}/ ${FAKEROOT##*/}.XXXXXXX)
          SANDBOX_ID=".${FAKEROOT##*.}"
          if [ -z "$SANDBOX_IMG" ]; then
            [ -z "$savebranch" ] && choose_save
            savebranch="$(realpath -m $savebranch)"
            if [ -d  "$savebranch" ]; then
              #TODO: verify this works if savebranch is a mounted directory.
              SANDBOX_IMG="$savebranch"
            else
              [ ! -z "$savebranch"  ] && loop=$(losetup -a | grep  "$savebranch"  | sed "s/:.*$//" )
              if [ ! -z "$loop" ]; then
                SANDBOX_IMG=$(cat /proc/mounts | grep $loop | cut -d " " -f2)
              fi
              if [ -z "$SANDBOX_IMG" ] ; then
                SANDBOX_IMG=$FAKEROOT_dir/sandbox_img${SANDBOX_ID}
                mkdir -p $SANDBOX_IMG
              fi
            fi
            rmdir $FAKEROOT
          else
            log stop
            echo "Warning chose to remount over existing mount! $FAKEROOT"
            echo "ctrl-c to quit"
            read -p "Press enter to continue"  
            log start     
          fi
        fi
      else
            echo "This is our first sandbox"
      fi
    else
      echo "Warning sandbox root not defined" 
      #[ -z "$FAKEROOT" ] && FAKEROOT=/
    fi
    if [ $CLEANUP_SANDBOX_ROOT = yes ]; then
      if [ ${#del_rules_filter} -eq 0 ]; then
         del_rules_filter+=( $SANDBOX_ROOT"/.+" )
         del_rules_actionr+=( POLICY_DELETE )
      fi
      if [ ${#umount_rules_filter} -eq 0 ]; then
         umount_rules_filter+=( $SANDBOX_ROOT"/.+"  )
         umount_rules_action+=( POLICY_UMOUNT )
      fi    
    fi
    mkdir -p "$SANDBOX_ROOT"
    mkdir -p "$FAKEROOT"
}
function set_sandbox_img(){
     [ -z ${FAKEROOT_dir+x} ] &&  set_fakeroot
     if [ ! -z ${SANDBOX_IMG+x} ]  && [ -z "${SANDBOX_IMG}" ] || [ ! -z ${1+x} ]; then
      SANDBOX_IMG=sandbox_img
      SANDBOX_IMG=${SANDBOX_IMG}${SANDBOX_ID}
      [ ! -z "$FAKEROOT_dir" ] && SANDBOX_IMG=$FAKEROOT_dir/$SANDBOX_IMG
     elif [ -z "${FAKEROOT_dir}" ] ; then 
      SANDBOX_IMG=$FAKEROOT_dir/$SANDBOX_IMG
     fi
     mkdir -p "$SANDBOX_IMG"
}
function set_sandbox_tmpfs(){
     [ -z ${FAKEROOT_dir+x} ] &&  set_fakeroot
     if [ ! -z ${SANDBOX_TMPFS+x} ]  && [ -z "${SANDBOX_TMPFS}" ]; then
      SANDBOX_TMPFS=sandbox_tmpfs
      SANDBOX_TMPFS=${SANDBOX_TMPFS}${SANDBOX_ID}
      [ ! -z "$FAKEROOT_dir" ] && SANDBOX_TMPFS=$FAKEROOT_dir/$SANDBOX_TMPFS
    elif [ ! -z "${FAKEROOT_dir}" ]  && [ ! -d $SANDBOX_TMPFS ]; then 
      SANDBOX_TMPFS=$FAKEROOT_dir/$SANDBOX_TMPFS
    fi
    mkdir -p "$SANDBOX_TMPFS"
}
function make_set(){
  log stop
  local item 
  local key
  unset make_set_rtn
  declare -gA make_set_rtn
  for item in "$@"; do 
    key=md5_$(md5sum < <( echo "$item" ) | cut -f1 -d' ')
    make_set_rtn[$key]="$item"
  done
  log start
}


declare -a options="$(getopt -o f:,o:,m:,d:,s:,b:,e:,l:,t::,a::,u::,r::,j: --long input-file:,output-file:,:tmpfs::,root::,pmedia:,pdrv:,psubdir:,boot-config:,distro-specs:,extra-sfs:,aufs,maybe-aufs,maybe-psubdir:,no-exit::,psave:,pupmode:,logfile:,trace::,rw-layer:,copy-Xauth::,bind-X11-sockets::,copy-resolv_conf::,layer:,rev-bind:,bind:,before-chroot: -- "$@")"
eval set --"$options_str"
#set -- $options
#declare -a options=$( $options_str )
eval set --"$options"
while [ $# -gt 0 ]; do
  log stop
  echo "processing args: $@"
  log start
  case $1 in
  -f|--input-file) 
     INPUT_FILE=$2 
    mount_items "$INPUT_FILE"
    items+="$(get_items -f "$INPUT_FILE")"
    shift 2; ;;      
  -o|--output-file) OUTPUT_FILE=$2; shift 2; ;;
  --no-exit) 
    if [ $# -gt 1 ] && [[ ! "$2" = --* ]] && [ ! -z "$2" ]; then
      NO_EXIT="$2"
      [ -z "$NO_EXI" ] && NO_EXIT=true
      shift 2
    else
      NO_EXIT=true
      shift 1
    fi; ;;
  -p|--env-prefix) ENV_PREFIX=$2; shift 2; ;;
  -m|--pmedia) PMEDIA=$2; shift 2; ;;
  -d| --pdrv) PDRV=$2; shift 2; ;;
  -s|--psubdir) PSUBDIR=$2; 
    process_psubdir psubdir
    shift 2; ;;
    --maybe-psubdir) PSUBDIR=$2; 
    process_psubdir maybe-psubdir     
    shift 2; ;;    
  --distro-specs) 
     DISTRO_SPECS=$2; 
     [ -f "$DISTRO_SPECS" ] && . "$DISTRO_SPECS"
     shift 2 
     ;;
   --boot-config)
       BOOTCONFIG=$2; 
     [ -f "$BOOTCONFIG" ] && . "$BOOTCONFIG"
     shift 2 
     ;; 
   --union-record)  
     LASTUNIONRECORD=$2; 
     process_union_record union-record "$LASTUNIONRECORD"
     shift 2; ;;
   -e|--extra-sfs) 
     EXTRASFSLIST=$2;
     process_extra_sfs extra-sfs "$EXTRASFSLIST"
     shift 2; ;;
  --aufs)
    items+="$(get_items)"
    shift 1; ;;
  --maybe-aufs)
    [  -z "$items" ] && items+="$(get_items)"
    shift 1; ;;
    -r|--root)
    if [ $# -gt 1 ] && [[ ! "$2" = --* ]] && [ ! -z "$2" ]; then
      SANDBOX_ROOT="$2"
      shift 2
    else
      SANDBOX_ROOT="" #Later we use [ -z ${SANDBOX_ROOT+x} ] to check that this is set
      shift 1
    fi; ;;   
   -f|-n|--fake-root|--new-root)
      if [ $# -gt 1 ] && [[ ! "$2" = --* ]] && [ ! -z "$2" ]; then
        FAKEROOT="$2"
        set_fakeroot
        shift 2
      else
        FAKEROOT="" #Later we use [ -z ${FAKEROOT+x} ] to check that this is set
        set_fakeroot
        shift 1
      fi; ;; 
  #--rw-layer) #TOTO unlike 
     #if [ $PUPMODE -eq 5 ] || [ $PUPMODE -eq 13 ] || [ $PUPMODE -eq 77 ]; then
        #tmpfsbranch="$2"
        #if [ -d "$2" ]; then
          #SANDBOX_TMPFS="$2"          
          #[ -z savebranch ] && savebranch="$SANDBOX_TMPFS"
        #else
           #tmpfsbranch="$2"
           #set_sandbox_tmpfs #TODO: verify this does what we want.
        #fi 
     #else
       #if [ -d "$2" ]; then
         #SANDBOX_IMG=$2
         #savebranch=$2
      #else [ -f "$2" ]
        ##mnt_sb_immage
        ##mount -o loop "$rwbranch" $SANDBOX_IMG;
        #savebranch=$1
        #loop=$(losetup-FULL -a | grep  "$savebranch"  | sed "s/:.*$//")
        #if [ ! -z "$loop" ]; then
          #SANDBOX_IMG=$(/proc/mounts | grep $loop | cut -d " " -f2)
        #else
          #SANDBOX_IMG=""
          #set_sandbox_img
        #fi    
      #fi
    #fi  
    #shift 2
    #;;         
  --save|--psave|--rw-layer|-t|--tmpfs)
    #!!!!New code. See the -s|--save option of remount_save.sh https://pastebin.com/0ZeU2Prjhttps://www.google.com/url?sa=i&url=https%3A%2F%2Fwww.talkbass.com%2Fmedia%2Fbass-fishing.19514%2F&psig=AOvVaw3on7Iu-gEIXoFMt5eiuTJX&ust=1608338515238000&source=images&cd=vfe&ved=0CAIQjRxqFwoTCPiAsY6m1u0CFQAAAAAdAAAAABAD
    #PSAVE=$2
    #shift 2
	  set_pdrv #TODO: limit complexity for now. We may not need to know this perfectly
	  make_set "" "$PSUBDIR" "$PDRV/$PSUBDIR" "$PRRV"      
	  unset a_dir
	  unset a_file
	  for a_path in "${make_set_rtn[@]}" ; do
        if [ -d "$2" ] || [ ! -e "$2" ]; then
          a_dir="$2" #""SANDBOX_TMPFS_maybe=          
          #[ -z "$savebranch" ] && savebranch="$SANDBOX_TMPFS"
          break
        elif [ -f "$2" ]; then
           a_file="$2" #tmpfsbranch_maybe="$2"
           #set_sandbox_tmpfs #TODO: verify this does what we want.
           break          
        fi
      done      

        #RW_LAYER is tmpfs     
        if  [ "$1" = "-t" ] || [ "$1" = "--tmpfs" ] ; then
                if [[ ! $2 = -* ]] && [ $# -gt 1 ]]; then
                 tmpfsbranch="$a_file"
               fi
               set_sandbox_tmpfs       
        elif [ $PUPMODE -eq 5 ] || [ $PUPMODE -eq 13 ] || [ $PUPMODE -eq 77 ] ; then #[ "$1" = "-t" ] || [ "$1" = "--tmpfs" ] 
           case "$1" in
           --rw-layer)
             if [ -d "$a_dir" ]; then
                RW_LAYER="$a_dir"
                tmpfsbranch="$a_dir"
                SANDBOX_TMPFS="$a_dir"
             elif [ -f "$a_file" ]; then 
                tmpfsbranch="$a_file"
                set_sandbox_tmpfs
             fi
             ;;
             --psave|--save)
              if [ -d "$a_dir" ]; then
                savebranch="$2"
                SANDBOX_IMG="$2"
             elif [ -f "$a_file" ]; then 
                tmpfsbranch="$a_file"
                set_sandbox_tmpfs
             fi
             ;;
             esac              
        else
           #--rw-layer|--psave|--save)
             if [ -d "$a_dir" ]; then
                RW_LAYER="$a_dir"
                savebranch="$a_dir"
                SANDBOX_IMG="$a_dir"
             elif [ -f "$a_file" ]; then 
                savebranch="$a_file"
                set_sandbox_img
             fi
             #;;
            # esac    
       fi
      
      
      #if [ -d "$2" ]; then
        #SANDBOX_IMG=$2
        #savebranch=$2
      #else [ -f "$2" ]
        ##mnt_sb_immage
        ##mount -o loop "$rwbranch" $SANDBOX_IMG;
        #savebranch=$2
        #loop=$(losetup-FULL -a | grep  "$savebranch"  | sed "s/:.*$//")
        #if [ ! -z "$loop" ]; then
          #SANDBOX_IMG=$(/proc/mounts | grep $loop | cut -d " " -f2)
        #else
          #SANDBOX_IMG=""
          #set_sandbox_img
        #fi
        #shift 2;
      #fi; 
      if [ $# -gt 1 ] && [[ $2 = -* ]]; then 
        shift 2
      else
        shift
      fi
      ;;   
  --pupmode)
    PUPMODE=$2
    shift 2
    ;;

  --layer)
    #RW_LAYER=$2
    process_layer layer $2
    shift 2
    ;;
  -l|--logfile)
    LOGFILE=$2
    [ -z "$TRACE" ] && TRACE=true
    shift 2
    log init
    ;;  
  -t|--trace)
    TRACE=$2
    if [ $# -gt 1 ] && [[ ! "$2" = --* ]] && [ ! -z "$2" ]; then
      TRACE="$2"
      [ -z "$TRACE" ] && TRACE=true
      shift 2
    else
      TRACE=true
      shift 1
    fi
    log init
    ;;
  -a|--copy-Xauth)
    if [ $# -gt 1 ] && [[ ! "$2" = --* ]] && [ ! -z "$2" ]; then
      [ -f $2 ] && XAUTH=$(realpath "$2")
      log stop
      [ -z "$XAUTH" ] && [ -f $2 ] && XAUTH=$(realpath "~/.Xauthority")
      shift 2
    else
      log stop
      [ -f ~/.Xauthority ] && XAUTH=$(realpath "~/.Xauthority")
      shift 1
    fi
    echo "XAUTH=$XAUTH"
    log start
    ;;
  -u|--bind-X11-sockets)
    if [ $# -gt 1 ] && [[ ! "$2" = --* ]] && [ ! -z "$2" ]; then
      uSocketDir=$(realpath "$2"); 
      log stop
      [ -z "$uSocketDir" ] && uSocketDir=/tmp/.X11-unix
      shift 2
    else
      log stop
      uSocketDir=/tmp/.X11-unix
      shift 1
    fi
    echo "uSocketDir=$uSocketDir"
    log start
    ;;
  -r|--copy-resolv_conf)
    if [ $# -gt 1 ] && [[ ! "$2" = --* ]] && [ ! -z "$2" ]; then
      RESOLV_CONF_PATH=$(realpath "$2")
      log stop
      [ -z "$RESOLV_CONF_PATH" ] && RESOLV_CONF_PATH=/etc/resolv.conf
      shift 2
    else
      log stop
      RESOLV_CONF_PATH=/etc/resolv.conf
      shift 1
    fi
    echo "RESOLV_CONF_PATH=$RESOLV_CONF_PATH"
    log start
    ;;
  --rev-bind) #Bind the fakeroot into a folder (e.g. a samba share)
       unset rev_b_source
      unset rev_b_target
      while true
      do
        if [ $# -lt 1 ]; then
          break
        fi
        case "$1" in
        --)    

          if [ ! -z "$rev_b_source" ]; then
            break
          else
          #TODO, add some further checking here. What we want to do is eat the -- at the end of the positional parameters if we are missing a target. 
            shift
            continue
          fi
          ;;
        --rev-bind)
            shift 
            continue
            ;;
        -*)
            break
            ;;
        esac
        if [ -z "$rev_b_source" ]; then
          if [ ! -z "$1" ]; then
            rev_b_source="$1"; shift
            continue
          fi        
        elif [ -z "$b_target" ]; then
          if [ ! -z "$1" ]; then
            rev_b_target="$1"; shift
            
            log stop
            
            echo "rev_bind_sources+=( \"$rev_b_source\" )"
            echo "rev_bind_targets+=( \"$rev_b_target\" )"
            
            
            rev_bind_sources+=( "$rev_b_source" )
            rev_bind_targets+=( "$rev_b_target" )
            
            log start
            
            unset rev_b_source
            unset rev_b_target
            shift
            continue
          else
            shift
            continue
          fi       
        else
          shift
          break
        fi
      done
 #   fi
    ;; 
  --before-chroot)
     BEFORE_CHROOT_CMD="$2"; 
     shift 2 
     ;; 
  --bind)
#    if [ $# -ge 4 ] && [[ ! "$2" = --* ]] && [ ! -z "$2" ] && \
#[[ "$3" = -j ]] && [[ ! "$4" = --* ]] && [ ! -z "$4" ]; then
#       bind_source=$(realpath "$2")
#       bind_target=$(realpath "$2")
#       bind_sources+=( "$bind_source" )
#       bind_targets+=( "$bind_target" )
#       shift 4
#    else 
      unset b_source
      unset b_target
      while true
      do
        if [ $# -lt 1 ]; then
          break
        fi
        case "$1" in
        --)    

          if [ ! -z "$b_source" ] && [ $# -lt 3 ]; then
            break
          else
          #TODO, add some further checking here. What we want to do is eat the -- at the end of the positional parameters if we are missing a target. 
            shift
            continue
          fi
          ;;
        --bind)
            shift 
            continue 
            ;;       
        -*)
        
            break
            ;;
        esac        
        if [[ $1 = -* ]]; then
          if [ ! -z "$b_target" ]; then
            break
          else
          #TODO, add some further checking here. What we want to do is eat the -- at the end of the positional parameters if we are missing a target. 
            shift
            continue
          fi
        fi
        if [ -z "$b_source" ]; then
          if [ ! -z "$1" ]; then
            b_source="$1"; shift
            continue
          fi
        elif [ -z "$b_target" ]; then
          if [ ! -z "$1" ]; then
            b_target="$1"; shift
            log stop
            
            echo "bind_sources+=( \"$b_source\" )"
            echo "bind_targets+=( \"$b_target\" )"            
            
            bind_sources+=( "$b_source" )
            bind_targets+=( "$b_target" )
            log start
            
            unset b_source
            unset b_target
            shift
            continue
          fi        
        fi
        shift
      done
 #   fi
    ;;           
  --) 
    shift 1
    options2+=( "$@" )
    break; ;;
  *)
     options2+=( "$1" )
     shift 1; ;;
  esac
done
items="$(echo "$items" | sed -n '/^\s*\(on\)\?\s*$/! p' | sed -n '/^Error: Expected on/! p' | sed -n '/^Use --help on/! p')"

      #log stop
      #echo "Finished Processing Options"
      #read -p "Press enter to continue"
      #log start 

#!!!! Use new code further down to find and mount PDRV

#!!!!Fake root now set with set_fakeroot() (above) for old code see psandbox_removed.sh


if [ -z ${FAKEROOT+x} ]; then # && [ -z ${SANDBOX_ROOT+x} ] 
  #SANDBOX_ROOT="" #Later this will change to SANDBOX_ROOT=/mnt/sb
  set_fakeroot
  [ -z $SANDBOX_IMG ] && set_sandbox_img
fi 
if [ ${#FAKEROOT} -le 1 ]; then
  echo "[ -z ${SANDBOX_ROOT+x} ] && [ -z ${FAKEROOT+x} ]"
  echo "SANDBOX_ROOT=$SANDBOX_ROOT"
  echo "FAKEROOT=$FAKEROOT"
  log stop
  read -p "Press enter to continue"
  log start
fi

# umount all if we are accidentally killed
#trap 'umountall' 1

#!!!! Old umountall() function removed. See new function above 


# 0.1 must be root
if [ $(id -u) -ne 0 ]; then
  echo "You must be root to use sandbox."
  exit
fi

# 0.2 cannot launch sandbox within sandbox
if [ "$AUFS_ROOT_ID" != "" ] ; then
  grep -q $SANDBOX_ROOT /sys/fs/aufs/$AUFS_ROOT_ID/br0 &&
    echo "Cannot launch sandbox within sandbox." && exit
fi

# 0.3 help
case "$1" in
  --help|-h)
  echo "Usage: ${0##*/}"
  echo "Starts an in-memory (throwaway) sandbox. Type 'exit' to leave."
  exit
esac

# 0.4 if not running from terminal but in Xorg, then launch via terminal
! [ -t 0 ] && [ -n "$DISPLAY" ] && exec $XTERM -e "$0" "$@"
! [ -t 0 ] && exit
# 1. get aufs system-id for the root filesystem
if [ -z "$AUFS_ROOT_ID" ] ; then
  AUFS_ROOT_ID=$(
    awk '{ if ($2 == "/" && $3 == "aufs") { match($4,/si=[0-9a-f]*/); print "si_" substr($4,RSTART+3,RLENGTH-3) } }' /proc/mounts
  )
fi


# 3. Ask user to choose the SFS
#TODO: add quite mode. 
echo "items=$items"
cat <<EOF
dialog --separate-output --backtitle "tmpfs sandbox" --title "sandbox config" \
  --checklist "Choose which SFS you want to use" 0 0 0 $items 2> $TMPFILE
EOF

log stop

echo "\"dialog --separate-output --backtitle \"tmpfs sandbox\" --title \"sandbox config\" \
  --checklist \"Choose which SFS you want to use\" 0 0 0 $items 2> $TMPFILE"

dialog --separate-output --backtitle "tmpfs sandbox" --title "sandbox config" \
  --checklist "Choose which SFS you want to use" 0 0 0 $items 2> $TMPFILE
chosen="$(cat $TMPFILE)"
log start
clear
if [ -z "$chosen" ]; then 
  echo "Cancelled or no SFS is chosen - exiting."
  exit 1 #TODO: Maybe instead of exiting we ask the user if they want to continue. For instance, perhaps the user wants an empty chroot directory to work with. 
fi


# 4. convert chosen SFS to robranches
robranches=""
for a in $(cat $TMPFILE) ; do
    #a="$(echo "$a" | sed 's/,$//')" # | sed 's/^'//' | sed 's/'$//' )"
    echo "a=$a"

    a="$(echo "$a" | sed 's/"//g')" # | sed 's/^'//' | sed 's/'$//' )"
  robranches=$robranches:$a=ro
  #TODO, remove line if layer is off in config file. 
  sed -i "\#^$a # {s/ off / on /}" /tmp/get_items_out #If we have a config file then we may need to strip out some stuff like if the layer is off or on. 
  
done
robranches="$(echo $robranches | sed 's#^[:]##g')"
      #log stop
      #echo "Finished building ro branches"
      #read -p "Press enter to continue"
      #log start 
if [ ! -z "$OUTPUT_FILE" ]; then
  cp "/tmp/get_items_out" "$OUTPUT_FILE"
  if [ ! "$NO_EXIT" = true ]; then
    exit 0
  fi
fi
rm $TMPFILE

#!!!! New Section Get rw image if not specified (unless pfx=ram?), and mount SANDBOX_IMG if not already mounted and nt a directory. 
# 5. get location of rw image
[ -z ${savebranch+x} ] && choose_save
mkdir -p $SANDBOX_IMG
[ ${#SANDBOX_IMG} -gt 1 ] || echo "Pathlenth too short SANDBOX_IMG='$SANDBOX_IMG'"
if [ ! -z "$savebranch"  ]; then
  if [ -f "$savebranch" ]; then
        loop=$(losetup -a | grep  "$savebranch"  | sed "s/:.*$//" )
        if [ ! -z "$loop" ]; then
          SANDBOX_IMG=$(cat /proc/mounts | grep $loop | cut -d " " -f2)
        else
          mount -o loop "$savebranch" $SANDBOX_IMG
        fi
  else
    SANDBOX_IMG="$savebranch" 
  fi
fi


#!!!! New code. Flag TMPFS for creation, if in suitable pumode.
#!!!! TMPFS may already be flagged for creation if suitable option is provided. 
  if [ ! -z "$PUPMODE" ]; then
    if [ $PUPMODE  -eq 5 ] && [ $PUPMODE  -eq 5 ] && [ $PUPMODE  -eq 13 ] && [ $PUPMODE  -eq 77 ]; then
      if  [ -z ${SANDBOX_TMPFS+x} ]; then
        SANDBOX_TMPFS="" #Later we use [ -z ${SANDBOX_TMPFS+x} ] to check that this is set
      fi
    fi
  fi


find_real_pdrv
#!!!! New find PDRV code


[ -z $PDRV ] && PDRV=/mnt/home
if [ -z  "$SANDBOX_IMG" ] || [ ! -z ${SANDBOX_TMPFS+x} ]; then 
  if [ -z "$SANDBOX_TMPFS" ] ; then
    #SANDBOX_TMPFS=$SANDBOX_ROOT/sandbox
    set_sandbox_tmpfs
  fi
  
  if [ ! -z "${SANDBOX_TMPFS}" ] && [ -z "$(grep -q "${SANDBOX_TMPFS}" /proc/mounts)" ]; then
    if [ -z "$(ls -A "$SANDBOX_TMPFS")" ]; then
       if [ -z "$tmpfsbranch" ]; then   
          mount -t tmpfs none $SANDBOX_TMPFS;
       else
         if [ -f "$tmpfsbranch" ]; then
           loop=$(losetup -a | grep "$savebranch" | sed -r 's#(^[^:]+)([:].*$)#\1#g')
           if [ -z "$loop" ]; then          
             mount -o loop "$tmpfsbranch" "$SANDBOX_TMPFS"
           fi
         elif [ -d "$tmpfsbranch" ]; then
           mount -o bind "$tmpfsbranch" "$SANDBOX_TMPFS"
         else
           log stop
           echo "tmpfsbranch=$tmpfsbranch is not a file or directory"
           read -p "Press enter to continue"
           log start
         fi        
      fi
    fi
  fi
fi
if [ -z "$SANDBOX_TMPFS" ]; then 
  SANDBOX_TMPFS=$SANDBOX_IMG
else
  if [ ! -z "SANDBOX_IMG" ]; then
    robranches=$SANDBOX_IMG=rr:$robranches
  fi
fi
if [ -z "$(grep -q "${SANDBOX_IMG}" /proc/mounts)" ]; then
  if [ -z "$(ls -A "$SANDBOX_IMG")" ] && [ -f "$savebranch" ]; then
     loop=$(losetup -a | grep "$savebranch" | sed -r 's#(^[^:]+)([:].*$)#\1#g')
     if [ -z "$loop" ]; then
        mount -o loop "$savebranch" "$SANDBOX_IMG"
       #TODO: add else case maybe we want to bind the mount point somewhere. 
       
     fi
  fi
fi
mkdir -p $FAKEROOT

#mk_initrd_dir


## (!!!Removed Section. See psandbox_removed.sh!!) 6. do the magic - mount the tmpfs first, and then the rest with aufs





# 5. do the magic - mount the rw image first, and then the rest with aufs
#if mount -o loop "$rwbranch" $SANDBOX_IMG; then
if [ ${#FAKEROOT} -gt 1 ] && ! grep -q $FAKEROOT /proc/mounts; then
 
 
  echo "mount -t aufs -o \"br:$SANDBOX_TMPFS=rw:$robranches\" aufs ${FAKEROOT}"
  echo "About to mount FAKEROOT at $FAKEROOT"
  read -p "Press enter to continue"
  
    mount -t aufs -o "br:$SANDBOX_TMPFS=rw:$robranches" aufs ${FAKEROOT}
 
        # 5. record our new aufs-root-id so tools don't hack real filesystem
        SANDBOX_AUFS_ID=$(grep $FAKEROOT /proc/mounts | sed 's/.*si=/si_/; s/ .*//') #'
        sed -i -e '/AUFS_ROOT_ID/ d' $FAKEROOT/etc/BOOTSTATE 2> /dev/null
        echo AUFS_ROOT_ID=$SANDBOX_AUFS_ID >> $FAKEROOT/etc/BOOTSTATE  
    
    
    # 7. sandbox is ready, now just need to mount other supports - pts, proc, sysfs, usb and tmp    
    
    mkdir -p $FAKEROOT/dev $FAKEROOT/sys $FAKEROOT/proc $FAKEROOT/tmp
    #mkdir -p  "$DEV_SAVE/${PSUBDIR}"
    #mount -o bind  "$PDRV/${PSUBDIR}" "$DEV_SAVE/${PSUBDIR}"
   
    #TODO: maybe we only want to mount  the psubdirectory folder
    #mount -o bind  "$DEV_SAVE/${PSUBDIR}" "$FAKEROOT/initrd/mnt/dev_save"
    mkdir -p "$FAKEROOT/initrd/mnt/dev_save"
    mount -o bind  "$DEV_SAVE" "$FAKEROOT/initrd/mnt/dev_save"
 
    #Maybe optionally do this based on some input paramater:
    #Also pull these layers from an array
    for layer_name in "pup_ro2" "pup_ro3" "pup_ro4" "pup_ro5" "pup_z"; do
        layer="$(eval 'echo $'$layer_name)"
      if [ ! -z "$layer" ] ; then
        mount -o bind  "$layer" "$FAKEROOT/initrd/$layer_name"
      fi
    done
 
    case "$(uname -a)" in
    *fatdog*)
      mkdir -p "$FAKEROOT/aufs"
      #mount -o bind  "$DEV_SAVE/${PSUBDIR}" "$FAKEROOT/aufs/dev_save"
      mkdir -p "$FAKEROOT/aufs/dev_save"
      mount -o bind  /mnt/home "$FAKEROOT/aufs/dev_save"
      cd $FAKEROOT
      #mkdir -p mnt/home
      cd mnt
      ln -s home ../aufs/dev_save
      pup_save="$SANDBOX_IMG" 
      mount -o bind  "$pup_save" "$FAKEROOT/aufs/pup_save"
      base_sfs=/aufs/pup_ro
      mount -o bind  "$base_sfs" "$FAKEROOT/aufs/pup_ro"
      if [ "$SANDBOX_TMPFS" != "$SANDBOX_IMG" ]; then
         pup_rw="$SANDBOX_TMPFS"
         mount -o bind  "$pup_rw" "$FAKEROOT/aufs/pup_rw"
      fi
      ;;    
    *) #assume this is puppy
      mk_initrd_dir
      #mkdir -p "$FAKEROOT/initrd/mnt/dev_save"
      #mount -o bind  /mnt/home "$FAKEROOT/initrd/mnt/dev_save"
      #mkdir $FAKEROOT/mnt
      #cd $FAKEROOT/mnt
      #ln -s ../initrd/mnt/dev_save
      ;;
    esac
    mkdir -p $FAKEROOT/mnt/home
    mkdir -p $FAKEROOT/dev
    mkdir -p $FAKEROOT/sys
    mkdir -p $FAKEROOT/proc
    
    mount -o rbind /dev $FAKEROOT/dev
    mount -t sysfs none $FAKEROOT/sys
    mount -t proc none $FAKEROOT/proc
    
    #TODO we don't aways want to bind the temp directory into the sandbox. 
    if [ PUPMODE = 2 ] || [[ "$(uname -a)" = *fatdog* ]]; then #Full Install #Maybe don't base this on PUPMODE
      tmp_des=$FAKEROOT/tmp
      tmp_source=/tmp
      mkdir -p "$FAKEROOT/tmp"
    else
      #case "$(uname -a)" in 
      #*fadog*)
      #
      #*) #assume this is puppy
        
        mkdir -p $FAKEROOT/initrd/mnt/tmpfs/tmp
        tmp_des=$FAKEROOT/initrd/mnt/tmpfs/tmp
        tmp_source=/initrd/mnt/tmpfs/tmp
        cd $FAKEROOT
      if [ -d tmp ] && [ -z "$(ls -A tmp)" ]; then
        rm tmp
        ln -s initrd/mnt/tmpfs tmp
      fi 
      
    fi
    mount -o bind $tmp_source $tmp_des
 
    cd $FAKEROOT
    case "$(uname -a)" in
    *fatdog*)
      mkdir -p $FAKEROOT/aufs
      mount -o bind $SANDBOX_TMPFS $FAKEROOT/$SANDBOX_TMPFS
      ;;
    *) #assume this is puppy
      mk_initrd_dir
      #ln -s initrd/mnt/tmpfs tmp   
      #mkdir -p $FAKEROOT/$SANDBOX_TMPFS
      #mount -o bind $SANDBOX_TMPFS $FAKEROOT/$SANDBOX_TMPFS # so we can access it within sandbox
      ;;
    esac
 
#    #mkdir -p $FAKEROOT/$SANDBOX_TMPFS
#    mkdir -p $FAKEROOT/$SANDBOX_IMG
#    mount -o bind $SANDBOX_IMG $FAKEROOT/$SANDBOX_IMG  # so we can access it within sandbox    
     cp /usr/share/sandbox/* $FAKEROOT/usr/bin 2> /dev/null
    
 
 
        # 8. optional copy, to enable running sandbox-ed xwin 
        cp /usr/share/sandbox/* $FAKEROOT/usr/bin 2> /dev/null
        
        # 9. make sure we identify ourself as in sandbox - and we're good to go!
        [ -f $FAKEROOT/etc/shinit ] && echo -e '\nexport PS1="sandbox'${SANDBOX_ID}'# "' >> $FAKEROOT/etc/shinit #fatdog 600
        if [ -f $FAKEROOT/etc/profile ]; then
          sed -i -e '/^PS1/ s/^.*$/PS1="sandbox'${SANDBOX_ID}'# "/' $FAKEROOT/etc/profile # earlier fatdog
        else
          log stop
          echo "Missing: \$FAKEROOT/etc/profile=$FAKEROOT/etc/profile"
          read -p "Press enter to continue"

          log start
        fi
        
    if [ -d "$FULL_SAVE_PATH" ]; then #TODO verify that this works with a save file
      if [ $PUPMODE -eq 13 ] && [ $PUPMODE -eq 77 ]; then
        #TODO: when PUPMODE=77 (multisession cd) we need to copy folders. See: https://github.com/puppylinux-woof-CE/woof-CE/blob/c483d010a8402c5a1711517c2dce782b3551a0b8/initrd-progs/0initrd/init#L1084
        #and copy_folders()  https://github.com/puppylinux-woof-CE/woof-CE/blob/c483d010a8402c5a1711517c2dce782b3551a0b8/initrd-progs/0initrd/init#L482
          #https://github.com/puppylinux-woof-CE/woof-CE/blob/c483d010a8402c5a1711517c2dce782b3551a0b8/initrd-progs/0initrd/init#L1091
          mount -o remount,prepend:"$FULL_SAVE_PATH"=rw,mod:"$SANDBOX_TMPFS"=ro,del:"$SANDBOX_TMPFS" "$FAKEROOT" 
          #mount -o remount,add:1:"$FULL_SAVE_PATH"=ro+wh "$FAKEROOT" 
      fi
    fi
        
 
     if [ ! -z "$XAUTH" ]; then
      cp "$XAUTH" "$FAKEROOT/$XAUTH"
    fi
    if [ ! -z "$uSocketDir" ];then
      mkdir -p "$FAKEROOT$uSocketDir"
      if [ -z "$(ls -A "$FAKEROOT$uSocketDir" )" ]; then
        mount --bind "$uSocketDir" "$FAKEROOT$uSocketDir"
      fi    
    fi  
    if [ ! -z "$RESOLV_CONF_PATH" ]; then
      cp "$RESOLV_CONF_PATH" "$FAKEROOT/etc/resolv.conf"
    fi  
    
    for i in "${!bind_sources[@]}"; do
      b_source="${bind_sources[$i]}"
      b_target=$(realpath -m "$FAKEROOT/${bind_targets[$i]}")
      mkdir -p "$b_target"
      mkdir -p "$b_target"
      log stop
      read -p "Press enter to continue"
      log start 
      mount --bind "$b_source" "$b_target"
    done    
    for i in "${!rev_bind_sources[@]}"; do
      rev_b_source="$rev_bind_sources[$i]"
      rev_b_source="${rev_b_source#/}"
      rev_b_source="$FAKEROOT/$rev_bind_sources"
      rev_b_target="${bind_targets[$i]}"
      rev_b_target=$(eval "echo \"$rev_b_target\"")
      rev_b_target=$(realpath -m "$rev_b_target")
      mkdir -p "$rev_b_target"
      mkdir -p "$rev_b_source"
      log stop
      read -p "Press enter to continue"
      log start 
      mount --bind "$b_source" "$b_target"
    done  
        $BEFORE_CHROOT_CMD    
        echo "Starting sandbox now."
        log stop 
        echo "USE_NS=$USE_NS"
        if [ ! -z "$USE_NS" ] && [ $USE_NS -eq 1 ]; then
            echo " unshare -f -p --mount-proc=$FAKEROOT/proc chroot $FAKEROOT"
            unshare -f -p --mount-proc=$FAKEROOT/proc chroot $FAKEROOT
        else
            export FAKEROOT="$FAKEROOT"
            sync
           (
            echo "chroot $FAKEROOT"
             #bash < /dev/tty > /dev/tty 2>/dev/tty
               echo "Ready to chroot at ${FAKEROOT}."
               log stop
              read -p "Press enter to continue"
             chroot "$FAKEROOT" < /dev/tty > /dev/tty 2>/dev/tty
             log start
            #chroot $FAKEROOT
            )
        fi
        log start
        # 8. done - clean up everything 
       umountall
        echo "Leaving sandbox."  
    
elif [ "${FAKEROOT:-/}" = "/" ]; then
  #[ -z "$FAKEROOT" ] &&  $FAKEROOT="/"
  echo "mount -t aufs -o \"remount,br:$SANDBOX_TMPFS=rw$robranches\" aufs  ${FAKEROOT:-/}"
  echo "Warning!  about to remount rootfs at $FAKEROOT"
  read -p "Press enter to continue"
  trap - 1 #Clear traps
  trap
  mount -t aufs -o "br:$SANDBOX_TMPFS=rw$robranches" aufs ${FAKEROOT:-/};
  mkdir -p /dev /sys /proc /tmp #These probably already exist
  [[ "`mountpoint /dev`"  != *"is a mountpoint"* ]] && mount -t devtmpfs devtmpfs /dev
  mkdir -p /initrd/mnt/tmpfs
  [[ "`mountpoint /initrd/mnt/tmpfs`"  != *"is a mountpoint"* ]] && mount -t tmpfs none /initrd/mnt/tmpfs
  mkdir -p /initrd/mnt/tmpfs/tmp
  if [[ "`mountpoint /tmp`"  != *"is a mountpoint"* ]]; then
    if [[ "`mountpoint /initrd/mnt/tmpfs`"  != *"is a mountpoint"* ]]; then
      mount -o bind /initrd/mnt/tmpfs/tmp /tmp
    else
      mount -t tmpfs none /tmp
    fi
  fi
else
  echo "not implemented for FAKEROOT=${FAKEROOT:-/}}"
  exit
fi
