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
# -o, --output-file 
#    Just write layer paths to an output file but don't mount the sandbox. 
# --no-exit
#   if an output file is specified (i.e. -o or --output-file) layer paths are just written to a file and the program exits unless the no-exit flag is specified.
# f, --input-file
#   read layer paths from a file rather than reading existing layers
# m,--pmedia
#   determines pupmodes. Refer to puppy boot parmaters
# d, --pdrv
#   this is the particiaion where the puppy files are located. The default is /mnt/home
# s, psubdir
#   this is the sub directory where the puppy files are located
# c, --clear-env
#   deletes enviornental variabls
# --env-prefix
#   enviornental variable prefix
# b --boot-config
#   path to boot config (e.g. /etc/rc.d/BOOTCONFIG
# --disto-specs
#   path to distro specs (e.g. /etc/DISTRO_SPECS; e.g. /initrd/distro-specs)
# L, --layer
#   a subgke kater
#  e, --extra-sfs
#   a list of extra sfs files (space seperated)
#  u, --union-record
# --xterm
# --sandbox
# -initrd
# --save
# --noexit
# --psave
# --pupmode

#I thought some assoitive arrays might be useful but I'm not using them yet. 
#declare -A KEYs_by_MNT_PT
#declare -A KEYs_by_FILE_PATH
#declare -A KEYs_by_trimmed_MNT_PT
#declare -A KEYs_by_trimmed_FILE_PATH
#declare -A MNT_PTs
#declare -A FILE_PATHs
#declare -A ON_status
cd "$(dirname "$0")"
MAX_STR_LEN=50
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

XTERM=${XTERM:-urxvt}
SANDBOX_ROOT=${SANDBOX_ROOT:-/mnt/sb}

declare -a options2
declare -a LAYER_SOURCES
LAYER_SOURCE=none
function log(){
  local logfile="${2}"
  local trace="$3"
  #[ -z "$logfile" ] && LOGFILE 
  #[ -z "$trace" ] && trace=TRACE
  if [ ! -z "$LOGFILE" ]; then
    case "$1" in
    init)
      [ "$TRACE" = true ] && set -x
      [ ! -z "$LOGFILE" ] && rm "$LOGFILE"
      exec 6>&1           # Link file descriptor #6 with stdout.
      #exec &1> >(tee -a "$LOGFILE")
      #exec &2> >(tee -a "$LOGFILE")
      exec &> >(tee -a "$LOGFILE")
      ;;
    start)
      [ "$TRACE" = true ] && set -x
      #exec &1> >(tee -a "$LOGFILE")
      #exec &2> >(tee -a "$LOGFILE") 
      exec &> >(tee -a "$LOGFILE") 
      ;;
    stop)
      #https://stackoverflow.com/questions/21106465/restoring-stdout-and-stderr-to-default-value
      [ "$TRACE" = true ] && set +x
      exec 1>&6  
      exec 6>&-      # Restore stdout and close file descriptor #6.
      exec &2> /dev/stderr    
      ;;
    esac
  fi 	
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
   echo "PSAVE"mount_items
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
    if [ "$PUPMODE" = 2 ]; then #Full install
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
    fi
  fi
}
declare -a options="$(getopt -o f:,o:,m:,d:,s:,b:,e:,l:,t:: --long input-file:output-file:,pmedia:,pdrv:,psubdir:,boot-config:,distro-specs:,extra-sfs:,maybe-aufs,maybe-psubdir:,no-exit::,psave:,pupmode:,logfile:,trace:,rw-layer: -- "$@")"
eval set --"$options"
while [ $# -gt 0 ]; do
  case "$1" in
  -f|--input-file) 
     INPUT_FILE=$2 
    LAYER_SOURCE=INPUT_FILE
    LAYER_SOURCES+=( input-file )
    shift 2; ;;      
  -o|--output-file) OUTPUT_FILE=$2; shift 2; ;;
  --no-exit) 
    if [ $# -gt 1 ] && [[ ! "$2" = --* ]] && [ ! -z "$2" ]; then
      NO_EXIT="$2"
      shift 2
    else
      NO_EXIT=true
      shift 1
    fi; ;;
  -p|--env-prefix) ENV_PREFIX=$2; shift 2; ;;
  -m|--pmedia) PMEDIA=$2; shift 2; ;;
  -d| --pdrv) PDRV=$2; shift 2; ;;
  -s|--psubdir) PSUBDIR=$2; 
    LAYER_SOURCE=psubdir   
    LAYER_SOURCES+=( psubdir )
    shift 2; ;;
    --maybe-psubdir) PSUBDIR=$2; 
    LAYER_SOURCE=maybe-psubdir   
    LAYER_SOURCES+=( maybe-psubdir )
    shift 2; ;;    
  --distro-specs) 
     DISTRO_SPECS=$2; 
     . "$DISTRO_SPECS"
     shift 2 
     ;;
   --boot-config)
       DISTRO_SPECS=$2; 
     . "$BOOTCONFIG"
     shift 2 
     ;; 
   --union-record)  
     LASTUNIONRECORD="$2"; 
     LAYER_SOURCES+=( union-record )
     shift 2; ;;
   -e|--extra-sfs) 
     EXTRASFSLIST="$2"; 
     LAYER_SOURCES+=( extrasfs )
     shift 2; ;;
  --maybe-aufs)
    LAYER_SOURCE=maybe-aufs   
    LAYER_SOURCES+=( maybe-aufs )
    shift 1; ;;
  --psave)
    PSAVE=$2
    shift 2
    ;;
  --pupmode)
    PUPMODE=$2
    shift 2
    ;;
  --rw-layer)
    RW_LAYER=$2
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
      shift 2
    else
      TRACE=true
      shift 1
    fi
    log init
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

#set -- "${options2[@]}"
if [ "$LAYER_SOURCE" = none ] && [ ! -z "$PDRV" ]; then
  PDRV=${PDRV:-/mnt/home}
  for rec in $LASTUNIONRECORD; do
    if [ -f "$PDRV/$rec" ]; then
      items+="\"$PDRV/$rec\" \"$rec\""$'\n'
    fi
  done 
  if [ -z "$items" ]; then
    [ -z "$DISTRO_ADRVSFS" ] && DISTRO_ADRVSFS=$(ls -1 $PDRV | grep -i -m1 adrv.*\.sfs$)   
    [ -z "$DISTRO_YDRVSFS" ] && DISTRO_YDRVSFS=$(ls -1 $PDRV | grep -i -m1 ydrv.*\.sfs$)       
    [ -z "$DISTRO_ZDRVSFS" ] && DISTRO_ZDRVSFS=$(ls -1 $PDRV | grep -i -m1 zdrv.*\.sfs$) 
    [ -z "$DISTRO_FDRVSFS" ] && DISTRO_FDRVSFS=$(ls -1 $PDRV | grep -i -m1 fdrv.*\.sfs$)        
    [ -z "$DISTRO_PUPPYSFS" ] && DISTRO_PUPPYSFS=$(ls -1 $PDRV | grep -i -m1 puppy_.*\.sfs$)

    for rec in "$DISTRO_ADRVSFS" "$DISTRO_YDRVSFS" "$DISTRO_ZDRVSFS" "$DISTRO_FDRVSFS" "$DISTRO_PUPPYSFS"; do
      [ -z "$rec" ] && continue
      items+="$PDRV/$rec" "$rec"$'\n'  
    done
  fi
  if [ ! -z "$items" ]; then  
    for rec in $EXTRASFSLIST; do
      if [ -f "$PDRV/$rec" ]; then
        items+="\"$PDRV/$rec\" \"$rec\" "on"\""$'\n'
      fi
    done
  fi
fi
if [ -z "$items" ] && [ "$LAYER_SOURCE" = none ] ; then
    LAYER_SOURCE=aufs   
    LAYER_SOURCES+=( aufs )
fi
[ -z "$PDRV" ] && PDRV="/mnt/home"

if [ "$(cat /proc/mounts | grep -c "$(realpath "$PDRV")")" = 0 ]; then
  PDRV_DEV="$(blkid | grep -m1 "$PDRV" | cut -d ':' -f1)"
  PDRV="$(echo "$PDRV_DEV" | sed 's#^/dev/#/mnt/#')"
  mount "$PDRV_DEV" "$PDRVV"
fi  


FAKEROOT=$SANDBOX_ROOT/fakeroot   # mounted chroot location of sandbox - ie, the fake root
[ -z "$RW_LAYER" ] && SANDBOX_TMPFS=$SANDBOX_ROOT/sandbox # mounted rw location of tmpfs used for sandbox
DEV_SAVE=$SANDBOX_ROOT/dev_save
mkdir -p "$DEV_SAVE" 

SANDBOX_ID=
TMPFILE=$(mktemp -p /tmp)
# use namespaces if available
#[ -e /proc/1/ns/pid ] && [ -e /proc/1/ns/mnt ] && type unshare >/dev/null && USE_NS=1




# umount all if we are accidentally killed
trap 'umountall' 1
umountall() {
  {
  umount -l $FAKEROOT/$SANDBOX_TMPFS
  if [ PUPMODE = 2 ]; then #Full Install
      umount -l $FAKEROOT/tmp
    else
      umount -l $FAKEROOT/initrd/mnt/tmpfs
    fi
  for layer_name in "pup_ro2" "pup_ro3" "pup_ro4" "pup_ro5" "pup_z"; do
    layer="$(eval 'echo $'$layer_name)"
    if [ ! -z "$layer" ] ; then
      umount -l "$FAKEROOT/initrd/$layer_name"
    fi
  done    
  umount -l $FAKEROOT/proc
  umount -l $FAKEROOT/sys
  umount -l $FAKEROOT/dev
  
  umount -l $FAKEROOT
  [ -z "$RW_LAYER" ] && umount -l $SANDBOX_TMPFS 
  rmdir $FAKEROOT
  #if  [ PUPMODE = 2 ] || PUPMODE = 5 ]; then
    [ -z "$RW_LAYER" ] && rmdir $SANDBOX_TMPFS
  #fi
  } 2> /dev/null
}

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

if [ -z "$items" ]; then

  for item_source in "${LAYER_SOURCES[@]}"; do
  # 2. get branches, then map branches to mount types or loop devices 
    case "$item_source" in
    input-file)
    mount_items "$INPUT_FILE"
  items+="$(get_items -f "$INPUT_FILE")"; ;;
    union-record)
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
      items+="$(get_items -f <<<"$new_items")" 
      ;; 
    extra-sfs)
       new_items=''
       for rec in $EXTRASFSLIST; do
       if [ -f "$rec" ]; then
          MNT_PT="$(mount_fm "$rec" )"
          new_items+="\"$MNT_PT\" \"$rec\" \"on\""$'\n'
        elif [ -f "$PDRV/$rec" ]; then
          MNT_PT="$(mount_fm "$PDRV/$rec" )"
          new_items+="\"$MNT_PT\" \"$PDRV/$rec\" \"on\""$'\n'
        fi
      done
      ;;
    layer=*)
      item_path="$(echo ${litem_source#*=})"
      if [ -f "$item_path" ]; then
        MNT_PT="$(mount_fm "$item_path" )"
      elif [ -d "$item_path" ]; then  
        MNT_PT="$item_path" #This isn't really a mount poing
      elif [ ! -d  "$item_path" ]; then
        echo "Warning  cannot mount $item_path"
        continue
      fi
      items+="\"$MNT_PT\" \"$item_path\" \"on\""$'\n' 
      ;;
    psubdir|maybe-psubdir)
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
      export new_items="$new_items"
      echo "$new_items"
      items+="$(get_items -s "$new_items")" 
      ;;       
    aufs)
      items+="$(get_items)" ; ;;  
    maybe-aufs)
       [  -z "$items" ] && items+="$(get_items)"; ;;   
  esac
  items="$(echo "$items" | sed -n '/^\s*\(on\)\?\s*$/! p' | sed -n '/^Error: Expected on/! p' | sed -n '/^Use --help on/! p')"
  done
fi
# 3. Ask user to choose the SFS
log stop
dialog --separate-output --backtitle "tmpfs sandbox" --title "sandbox config" \
  --checklist "Choose which SFS you want to use" 0 0 0 $items 2> $TMPFILE
chosen="$(cat $TMPFILE)"
log start
clear
if [ -z "$chosen" ]; then
  echo "Cancelled or no SFS is chosen - exiting."
  exit 1
fi


# 4. convert chosen SFS to robranches
robranches=""
for a in $(cat $TMPFILE) ; do
    #a="$(echo "$a" | sed 's/,$//')" # | sed 's/^'//' | sed 's/'$//' )"
    a="$(echo "$a" | sed 's/"//g')" # | sed 's/^'//' | sed 's/'$//' )"
  robranches=$robranches:$a=ro
  sed -i "\#^$a # {s/ off / on /}" /tmp/get_items_out
done
if [ ! -z "$OUTPUT_FILE" ]; then
  cp "/tmp/get_items_out" "$OUTPUT_FILE"
  if [ ! "$NO_EXIT" = true ]; then
    exit 0
  fi
fi
rm $TMPFILE

#if [ PUPMODE = 2 ] || PUPMODE = 5 ]; then
  # 0.5 is this the first sandbox? If not, then create another name for mountpoints
  if grep -q $FAKEROOT /proc/mounts && [ -z "$RW_LAYER" ]; then
  FAKEROOT=$(mktemp -d -p $SANDBOX_ROOT ${FAKEROOT##*/}.XXXXXXX)
  SANDBOX_ID=".${FAKEROOT##*.}"
  SANDBOX_TMPFS=$SANDBOX_ROOT/${SANDBOX_TMPFS##*/}${SANDBOX_ID}
  rmdir $FAKEROOT
  fi
  # 5. make the mountpoints if not exist  yet
  [ -z "$RW_LAYER" ] && mkdir -p $FAKEROOT $SANDBOX_TMPFS
#else
#  SANDBOX_TMPFS="$SAVE_MP_FULL_PATH"
#fi



mk_initrd_dir


# 6. do the magic - mount the tmpfs first, and then the rest with aufs
if mount -t tmpfs none $SANDBOX_TMPFS || [ ! -z "$RW_LAYER" ]; then
  if [ -z "$RW_LAYER" ]; then
    TOP_LAYER="$SANDBOX_TMPFS"
  else 
    mkdir -p "$RW_LAYER"
    #TODO maybe check if the RW layer is a file and if so mount it first. 
    TOP_LAYER="$RW_LAYER"
  fi 
  if mount -t aufs -o "udba=reval,diropq=w,br:$TOP_LAYER=rw$robranches" aufs $FAKEROOT; then
    # 5. record our new aufs-root-id so tools don't hack real filesystem  
    SANDBOX_AUFS_ID=$(grep $FAKEROOT /proc/mounts | sed 's/.*si=/si_/; s/ .*//') #'
    sed -i -e '/AUFS_ROOT_ID/ d' $FAKEROOT/etc/BOOTSTATE 2> /dev/null
    echo AUFS_ROOT_ID=$SANDBOX_AUFS_ID >> $FAKEROOT/etc/BOOTSTATE
    
    # 7. sandbox is ready, now just need to mount other supports - pts, proc, sysfs, usb and tmp
    mkdir -p $FAKEROOT/dev $FAKEROOT/sys $FAKEROOT/proc $FAKEROOT/tmp
    mkdir -p  "$DEV_SAVE/${PSUBDIR}"
    mount -o bind  "PDRV/${PSUBDIR}" "$DEV_SAVE/${PSUBDIR}" #TODO: ONLY do this if we aren't going to mount all of mnt/dev_save
    mount -o bind  "$DEV_SAVE/${PSUBDIR}" "$FAKEROOT/initrd/mnt/dev_save"
    #Maybe optionally do this based on some input paramater:
    #Also pull these layers from an array
    for layer_name in "pup_ro2" "pup_ro3" "pup_ro4" "pup_ro5" "pup_z"; do
        layer="$(eval 'echo $'$layer_name)"
      if [ ! -z "$layer" ] ; then
        mount -o bind  "$layer" "$FAKEROOT/initrd/$layer_name"
      fi
    done
    mount -o rbind /dev $FAKEROOT/dev
    mount -t sysfs none $FAKEROOT/sys
    mount -t proc none $FAKEROOT/proc
    if [ PUPMODE = 2 ]; then #Full Install
      tmp_des=$FAKEROOT/tmp
      tmp_source=/tmp
    else
        mkdir -p $FAKEROOT/initrd/mnt/tmpfs
      tmp_des=$FAKEROOT/initrd/mnt/tmpfs
      tmp_source=/initrd/mnt/tmpfs
      cd $FAKEROOT
      rm tmp
      ln -s initrd/mnt/tmpfs tmp
    fi
    mount -o bind $tmp_source $tmp_des
    mkdir -p $FAKEROOT/$SANDBOX_TMPFS
    mount -o bind $SANDBOX_TMPFS $FAKEROOT/$SANDBOX_TMPFS # so we can access it within sandbox
    
    # 8. optional copy, to enable running sandbox-ed xwin 
    cp /usr/share/sandbox/* $FAKEROOT/usr/bin 2> /dev/null
    
    # 9. make sure we identify ourself as in sandbox - and we're good to go!
    echo -e '\nexport PS1="sandbox'${SANDBOX_ID}'# "' >> $FAKEROOT/etc/shinit #fatdog 600
    sed -i -e '/^PS1/ s/^.*$/PS1="sandbox'${SANDBOX_ID}'# "/' $FAKEROOT/etc/profile # earlier fatdog
    
    if [ -d "$FULL_SAVE_PATH" ]; then #TODO verify that this works with a save file
      if [ $PUPMODE -eq 13 ] && [ $PUPMODE -eq 77 ]; then
        #TODO: when PUPMODE=77 (multisession cd) we need to copy folders. See: https://github.com/puppylinux-woof-CE/woof-CE/blob/c483d010a8402c5a1711517c2dce782b3551a0b8/initrd-progs/0initrd/init#L1084
        #and copy_folders()  https://github.com/puppylinux-woof-CE/woof-CE/blob/c483d010a8402c5a1711517c2dce782b3551a0b8/initrd-progs/0initrd/init#L482
          #https://github.com/puppylinux-woof-CE/woof-CE/blob/c483d010a8402c5a1711517c2dce782b3551a0b8/initrd-progs/0initrd/init#L1091
          mount -o remount,prepend:"$FULL_SAVE_PATH"=rw,mod:"$SANDBOX_TMPFS"=ro,del:"$SANDBOX_TMPFS" "$FAKEROOT" 
          #mount -o remount,add:1:"$FULL_SAVE_PATH"=ro+wh "$FAKEROOT" 
      fi
    fi
    echo "Starting sandbox now."
    log stop    
    if [ $USE_NS ]; then
      unshare -f -p --mount-proc=$FAKEROOT/proc chroot $FAKEROOT
    else
      chroot $FAKEROOT
    fi
log start
    # 10. done - clean up everything 
    umountall
    echo "Leaving sandbox."
  else
    echo "Unable to mount aufs br:$SANDBOX_TMPFS=rw$robranches"
    umount -l $SANDBOX_TMPFS    
  fi
else
  echo "unable to mount tmpfs."
fi