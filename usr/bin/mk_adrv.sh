#!/bin/bash
#WKGMNTPT=/mnt/sb
set -x
WKGMNTPT=/mnt/home
ISO_BLD_FLDR=puppylivecdbuild
INST_PKG_PREFIX=${INST_PKG_PREFIX:-woof}
PUP_LAYER_MNT="" #e.g. /initrd${PUP_LAYER}
MKZDRV=${MKZDRV:-yes} #Setting this to yes will kep kernal modules out of the iso
CLEARPKGLOG=${CLEARPKGLOG:-yes}
[ "`whoami`" != "root" ] && exec sudo -A ${0} ${@} #110505

#NOTE: rename to avoid clash with 'remasterpup2.mo' used by previous i18n method.
export TEXTDOMAIN=remasterpup2x
export OUTPUT_CHARSET=UTF-8
. gettext.sh


#LANG=C #faster, plus Xdialog happier.
KERNELVER="`uname -r`"

##variables created at bootup by /initrd/usr/sbin/init...
#. /etc/rc.d/PUPSTATE
[ "$PUP_LAYER" = "" ] && PUP_LAYER="/pup_ro2"

#. /etc/DISTRO_SPECS
#PUPPYSFS="$DISTRO_PUPPYSFS" #ex: puppy.sfs
#PUPSFS_ROOT="${PUPPYSFS%.sfs}"
#ZDRVSFS="$DISTRO_ZDRVSFS"   #ex: zdrv.sfs
#SFSBASE="`basename $PUPPYSFS .sfs`" #ex: puppy


PPATTERN="/initrd${PUP_LAYER}"

SAVEPART="$PDEV1" #from PUPSTATE.
CDR="/dev/$SAVEPART"

#XPID=$!
if [ 1 -eq 0 ]; then
	SIZEOPT=0
	SIZEBIN=`du -sk /bin | cut -f 1`
	SIZESBIN=`du -sk /sbin | cut -f 1`
	SIZELIB=`du -sk /lib | cut -f 1`
	SIZEUSR=`du -sk /usr | cut -f 1`
	SIZEOPT=0	# 01jul09
	[ -d /opt ] && SIZEOPT=`du -sk /opt | cut -f 1`
	sync
	SIZETOTALK=`LANG=C dc $SIZEBIN $SIZESBIN + $SIZELIB + $SIZEUSR + $SIZEOPT + p`
	SIZETOTALM=`LANG=C dc $SIZETOTALK 1024 \/ p| cut -d'.' -f1`	# 01jul09
	[ "$SIZETOTALM" ] || SIZETOTALM=1
	#estimate a compressed size...
	SIZENEEDEDM=`expr $SIZETOTALM \/ 3`
	SIZESLACKM=`expr $SIZENEEDEDM \/ 3` #guess
	SIZENEEDEDM=`expr $SIZENEEDEDM + $SIZESLACKM`
	SIZENEEDEDM=`expr $SIZENEEDEDM + 25` #space for vmlinuz, initrd.gz, zdrv, etc
fi	
#now choose working partition... v431 add ext4...  130216 add f2fs...
#PARTSLIST="`probepart -m 2> /dev/null | grep '^/dev/' | grep -E 'f2fs|ext2|ext3|ext4|reiserfs|btrfs|minix|msdos|vfat|exfat|ntfs' | cut -f 1-3 -d '|'`"

#add tmpfs ramdisk choice...

Yes_lbl="$(gettext 'Yes')"
No_lbl="$(gettext 'No')"
m_01="$(gettext 'Puppy simple CD remaster')" #window title.
m_02="$(gettext 'ERROR')"
m_07="$(gettext 'currently mounted')"
m_08="$(gettext 'not mounted')"
m_09="$(gettext 'Filesystem')" #130302
m_10="$(gettext 'Size')" #130302
m_11="$(gettext 'Free')" #130302

	#create new puppy.sfs file...
	squash() {
		echo $0 $@
		rxvt -bg orange -fg black -title "$m_01" -geometry 80x6 -e mksquashfs $@ 2> /dev/null
	}
    fk_squash() {
		echo $0 $@
		#s243a: use set -x to echo cpio commands in fk_mksquashfs and pass to rxvt
		#rxvt -bg orange -fg black -title "$m_01" -geometry 80x6 -e mksquashfs $@ 2> /dev/null
		fk_mksquashfs $@ #Short term hack
	}
	do_squash(){
	  if [ "$mode" = dir ]; then
	    fk_squash $@ 	
	  else
	    squash $@ 
	  fi
	}	
	fk_mksquashfs(){
	  #source_dir=$1; shift
	  #target_dir=$2; shift
      option=""
      out=() #Currently not used
      args=()
      declare -A exludes
	  for arg in "$@";do
	    if [[ "$arg" == -* ]]; then 
	      case "$arg" in
	      -*)
	      option="$arg" ;;
	      esac  
	    else
	      case option in
	      -e)
	        exludes+=( ["$arg"]=1 ) ;;
	      '')
	        args+=( "$arg" ) ;;
	      *)
	        out+=( "$arg" ) ;;
	      esac
	    fi
	  done
	  n_args=${#args}
	  target_dir=$args[$n_args]
	  target_dir="${target_dir%.sfs}"
	  
	  mkdir -p "$target_dir"
	  unset 'args[$n_args-1]' #https://stackoverflow.com/questions/8247433/remove-the-last-element-from-an-array
	  #while read aDir; do
	  if [ realpath "$target_dir" != "/" ]; then
        for aDir in "$args[@]"; do 
	      excluded="${excludes[$aDir]}"
	      [ -z "$excluded" ] && excluded=0
	      if [ ! $excluded -eq 1 ]; then
	        cd $aDir
	        cpio -pd "$target_dir"
	      fi
	    done
	  fi
	  #done < <(ls -a -1)
	  
	}	
	do_mksquashfs(){
	  if [ "$mode" = dir ]; then
	    fk_mksquashfs $@ 	
	  else
	    mksquashfs $@ 
	  fi
	}	
#Use plugin_fns to over_ride functions	

#for a_root in /mnt/home/sb/fakeroot	
function print_str_or_file(){
	if [ "$1" = "-f" ]; then
       cat "$2";
  elif [ "$1" = "-s" ]; then
       echo "$2";
  elif [ "$1" = "-p" ]; then
    while read -r line; do
      echo "$line"
    done
  fi;	
}
#TODO, source this when processing options. 
#source "$plugin_fns"	

#Over ride this function to process more complex file inputs.
function get_a_root(){
   a_root=$(echo "$1" | cut -d ' ' -f1)
    [ -z "$a_root" ] && a_root=/mnt/home/sb/fakeroot
   PUPPYSFS=$(echo "$1" | cut -d ' ' -f2)  
   [ -z "$PUPPYSFS" ] && PUPPYSFS=puppy.sfs
   INST_PKG_PREFIX_maybe=$(echo "$1" | cut -d ' ' -f3)
   [ ! -z "$INST_PKG_PREFIX_maybe" ] && INST_PKG_PREFIX="$INST_PKG_PREFIX_maybe"  
}
function mk_layer_sfs(){
    #Feed print_str_or_file "$@" into the loop below
  #for a_root in /mnt/home/sb/fakeroot
  while read -r a_root_line; do
    DIRHOME=""
    echo "a_root_line=$a_root_line"
    #We need to exclude the following directories
    DIRHOME=''; DIRSYS=''; DIRLOST=''
    [ -d "${a_root}/home" ] && DIRHOME="${a_root}/home"
    [ -d "${a_root}/sys" ] && DIRSYS="${a_root}/sys"
    [ -d "${a_root}/lost+found" ] && DIRLOST="${a_root}/lost+found"
    PUPSFS='' #Override get_pupsfs_name to set pupsfs_name
    
    #type get_pupsfs_name && PUPPYSFS="$(get_pupsfs_name)"
    
    #Set a_root
    get_a_root "$a_root_line"
    mkdir -p ${WKGMNTPT}/${ISO_BLD_FLDR}
    rm -f ${WKGMNTPT}/${ISO_BLD_FLDR}/$PUPPYSFS 2> /dev/null
    
    sync
    #note, /puppy.sfs is not normally there, i relocated it to a separate tmpfs,
    #however have not yet done that for multisession-cd/dvd (PUPMODE=77).
    #note, /home could be in underdog linux...
  
    # modules copied from initrd
    ANOTHER_REMOVE=("${a_root}/lib/modules/$KERNELVER/initrd" "${a_root}/lib/modules/*/modules.*")	# 28dec09 modules.*
    if [ "$MKZDRV" = "yes" ]; then
      rm -f $WKGMNTPT/${ISO_BLD_FLDR}/$ZDRVSFS 2> /dev/null
      do_mksquashfs /lib $WKGMNTPT/${ISO_BLD_FLDR}/$ZDRVSFS -keep-as-directory -e /lib/[^m]* $ANOTHER_REMOVE
      ANOTHER_REMOVE=("${a_root}/lib/modules")
    fi
    #120605 Omit certain /dev subdir content and modem components loaded from firmware tarballs...
    [ -d "${a_root}/dev/snd" ] && [ "$(ls "${a_root}/dev/snd")" != "" ] && DIRDEVSNDFILES="${a_root}/dev/snd/*" #120721
    [ -d "${a_root}/dev/.udev" ] && DIRDEVUDEV="${a_root}/dev/.udev"
    #121021 modem daemons now left in place.
    [ -f "${a_root}/usr/share/icons/hicolor/icon-theme.cache" ] && ICONCACHE="${a_root}/usr/share/icons/hicolor/icon-theme.cache" #120721
    TOPPLCDB=''
    [ -e "${a_root}/${ISO_BLD_FLDR}" ] && TOPPLCDB="${a_root}/${ISO_BLD_FLDR}"
    TOPPUPSFS=''
    [ -e "${a_root}/${PUPPYSFS}" ] && TOPPUPSFS="${a_root}/${PUPPYSFS}"
    
  
  
    # display terminal only for the first stage because it takes the most of time. 'squash' is a function, see above. 120512 $COMP added...
    do_squash ${a_root} $WKGMNTPT/${ISO_BLD_FLDR}/$PUPPYSFS ${COMP} -e "${a_root}/media" "${a_root}/proc" "${a_root}/initrd" \
      "${a_root}/var" "${a_root}/tmp" "${a_root}/archive" "${a_root}/mnt" "${a_root}/root" "$TOPPLCDB" ${ANOTHER_REMOVE[@]} \
      "$DIRHOME" "$DIRSYS" "$DIRLOST" "$TOPPUPSFS" "$DIRDEVSNDFILES" \
       "$DIRDEVUDEV" "$ICONCACHE"  #120605 end #120721 avoid wildecards option, icon-theme.cache 121021
    sync
  
    #add pristine folders (out of current puppy.sfs)...
    #do_mksquashfs "${PUP_LAYER_MNT}"/home $WKGMNTPT/${ISO_BLD_FLDR}/$PUPPYSFS -keep-as-directory
    sync
    if [ ! -z "${PUP_LAYER_MNT}" ]; then
      do_mksquashfs "${PUP_LAYER_MNT}/proc" $WKGMNTPT/${ISO_BLD_FLDR}/$PUPPYSFS -keep-as-directory
      sync
      do_mksquashfs "${PUP_LAYER_MNT}/tmp" $WKGMNTPT/${ISO_BLD_FLDR}/$PUPPYSFS -keep-as-directory
      sync
      do_mksquashfs "${PUP_LAYER_MNT}/mnt" $WKGMNTPT/${ISO_BLD_FLDR}/$PUPPYSFS -keep-as-directory
      sync
      do_mksquashfs "${PUP_LAYER_MNT}"/media $WKGMNTPT/${ISO_BLD_FLDR}/$PUPPYSFS -keep-as-directory
      sync
      kill $XPID
    fi
   
    
  
    #######START WORKING ON /root#######
    rm -rf /tmp/root 2> /dev/null
    cp -arfv --remove-destination "${a_root}"/root* /tmp/root
    rm "/tmp/root/.bashrc"
    rm "/tmp/root/recently-used.xbel"
    rm /tmp"${PKGS_DIR}"/*-installed-packages
    #
  
    if [ -d "${a_root}/var/packages" ]; then
      PKGS_DIR=/var/packages
    elif [ -d "${a_root}/root/.packages" ]; then
      PKGS_DIR=/root/.packages
    else
      PKGS_DIR="$(realpath -m "${a_root}"/root/.pacakges)" #THis doesn't work right : TODO fix
      echo sed "$PKGS_DIR" | sed 's#^'"${a_root}"'##' #TODO make this more robust
      [-z "$PKGS_DIR" ] && PKGS_DIR=/var/packages
    fi
    
    if [ -e "${a_root}$PKGS_DIR/package-files" ]; then
      PKG_FILES_DIR="$PKGS_DIR/package-files"
    else
      PKG_FILES_DIR="$PKGS_DIR"
    fi
    BUILTIN_FILES_DIR="$PKGS_DIR/builtin_files"


    [ -f /tmp/root/.XLOADED ] && rm -f /tmp/root/.XLOADED #130527
      #######END WORKING ON /root (Part #1)#######
  
  
    #######START WORKING ON /etc#######
    rm -rf /tmp/etc 2> /dev/null
    cp -arfv --remove-destination "${a_root}"/etc/* /tmp/etc
    #rm /tmp/etc/resolve.conf
    echo "# nameservers go in here" > /tmp/etc/resolve.conf
    #do some work on /etc before add it to the .sfs...
  
  
  
    #######START WORKING ON /var#######
    rm -rf /tmp/var 2> /dev/null
    [ ! -z "${PUP_LAYER_MNT}" ] && cp -a ${PUP_LAYER_MNT}/var /tmp/var #pristine var
     
    #.packages/ .files, copy any files installed to /var...
    echo -n "" > /tmp/allpkgs.files
    #for ONEPKG in `ls -1 "$PKG_FILES_DIR/"*.files 2>/dev/null | tr "\n" " "`
    #do
    #	grep '^/var/' $ONEPKG | \

    [ ! -d /tmp/var/packages ] && mkdir -p /tmp/var/packages #This is probably already done

    [ -d "${a_root}/var/packages" ] && cp -arf --remove-destination "${a_root}/var/packages/"* /tmp/var/packages
    rm /tmp"${PKGS_DIR}"/*-installed-packages
    sync
    [ "$CLEARPKGLOG" = "yes" ] && rm -f /tmp/var/log/packages/* #120607
  
      #######END WORKING ON /var (Part #1)####### 
  
    ####### COPY PACKAGE METADATA ####### 
      
    # 141008: move *.files to ~/.packages/builtin_files/

	  #touch "${a_root}"/root/.packages/user-installed-packages	
	  
	  mkdir -p /tmp${PKGS_DIR}/builtin_files
	  
	  #cat /root/.packages/user-installed-packages | \
      
	  while read -r ONEPKG
	  do
      ONEFILE="/tmp$PKG_FILES_DIR/`echo "$ONEPKG" | cut -f1 -d '|'`.files"
      ONENAME="/tmp${PKGS_DIR}/builtin_files/`echo "$ONEPKG" | cut -f2 -d '|'`"
      [ -f "$ONEFILE" ] && mv -f "$ONEFILE" "$ONENAME"
      [ -f "$ONENAME" ] && echo "$ONEPKG" >> /tmp${PKGS_DIR}/${INST_PKG_PREFIX}-installed-packages
	  done < <(cat "${a_root}${PKGS_DIR}"/*-installed-packages)
	  #TODO, maybe look up the meta info of any package that wasn't moved
	  
	  #cat "${a_root}${PKGS_DIR}"/*-installed-packages >> /tmp${PKGS_DIR}/${INST_PKG_PREFIX}-installed-packages
	  sort -u --key=1 --field-separator="|" /tmp${PKGS_DIR}/${INST_PKG_PREFIX}-installed-packages > /tmp/${INST_PKG_PREFIX}-installed-packages-tmp #110722
	  mv -f /tmp/${INST_PKG_PREFIX}-installed-packages-tmp /tmp${PKGS_DIR}/${INST_PKG_PREFIX}-installed-packages
	  echo -n "" > /tmp${PKGS_DIR}/user-installed-packages #v431	  


    sync #120607
    rm -f /tmp${PKG_FILES_DIR}/*.files #120607
    rm -f /tmp${PKG_FILES_DIR}/*.remove #120607
    
    ####### END PACKAGE METADATA ####### 
    
    #######Start WORKING ON /root (Part #2) #######	
      m_19="$(eval_gettext 'This program has created folder /tmp/root, which has everything that is now going to be added as /root in the ${PUPPYSFS} file.')
    $(gettext "This is mostly 'pristine', as obviously you do not want all your cache files, temp files, email files, and other working/temporary files to be the ISO. However, if you are familiar with the workings of Puppy, you might like to take a look at /tmp/root right now, and possibly add anything that you want from /root (or remove something!)")
    $(gettext '(if you think that this program has missed out something important, please let us know..')
    
    $(eval_gettext "After examining /tmp/root, click 'Ok' to add /root in \${PUPPYSFS} file...")"
    Xdialog --wrap --left --title "$m_01" --msgbox "$m_19" 0 80
    sync
    [ "`ls /tmp/root/.packages/*.files`" = "" ] && CLEARPKGLOG="yes" || CLEARPKGLOG="no" #120607 in case user copied entire /root to /tmp for boot disk.
    do_mksquashfs /tmp/root $WKGMNTPT/${ISO_BLD_FLDR}/$PUPPYSFS -keep-as-directory
    sync
    rm -rf /tmp/root
    #######END WORKING ON /root (Part #2) #######	
      #######Start WORKING ON /etc (Part #2) #######
    m_23="${MSG1}

    $(gettext 'If you know what you are doing, you can now modify any files in /tmp/etc folder. This is just about to be added to /etc in the .sfs file.')
    $(gettext "Do anything you want before clicking 'Ok'.")
    $(gettext '(If this program has missed something important, let me know -- Barry Kauler)')
    
    $(eval_gettext "Click 'Ok' to add /etc in \${PUPPYSFS} file...")"
    Xdialog --wrap --left  --title "$m_01" --msgbox "$m_23" 0 80
  
    #120606 in case user just now replaced the /etc directory...
    sync
    #130527 .XLOADED moved to /root (see /usr/bin/xwin), change test...
    MODIFETC="$(find /tmp/etc/modules -mindepth 1 -maxdepth 1 -name 'firmware.dep.inst.*')"
    if [ "$MODIFETC" != "" ];then
      #rm -f /tmp/etc/.XLOADED
      rm -f /tmp/etc/modules/firmware.dep.inst.*
      touch /tmp/etc/personal_settings_popup_disabled
      touch /tmp/etc/personal_data_save_disabled
    fi
    [ -f /tmp/etc/.XLOADED ] && rm -f /tmp/etc/.XLOADED #130527 just in case old file still there.
  
    sync
  
    do_mksquashfs /tmp/etc $WKGMNTPT/${ISO_BLD_FLDR}/$PUPPYSFS -keep-as-directory
    sync
    rm -rf /tmp/etc
    #######END WORKING ON /etc (Part #2) #######	
      
      #######Start WORKING ON /var (Part #2) #######
  
    sync
    do_mksquashfs /tmp/var $WKGMNTPT/${ISO_BLD_FLDR}/$PUPPYSFS -keep-as-directory
    sync
    rm -rf /tmp/var
    
    #s243a: TODO: add prompt to modify the var folder like was done in the etc folder
    
    #######END WORKING ON /var#######
    
    #chmod a+r $WKGMNTPT/${ISO_BLD_FLDR}/* &>/dev/null
    #chmod a-x $WKGMNTPT/${ISO_BLD_FLDR}/*.sfs &>/dev/null
  
    #fi ###### end of long skip if, cleating new sfs
    
    #=================================================================
  
m_25="$(gettehttp://www.murga-linux.com/puppy/index.phpxt 'Almost ready to create the new ISO file!')

$(gettext "If you want to add any more files, say extra SFS files, or to edit or modify the files in any way, do it now. Note, if you add an extra SFS file, say 'devx.sfs' then it will be available for use when you boot the new live-CD.")

$(eval_gettext "If you want to make any changes, use ROX-Filer to open \${WKGMNTPT}/${ISO_BLD_FLDR}/ and do so now, before clicking the 'OK' button.")"
    Xdialog --wrap --left  --title "$m_01" --msgbox "$m_25" 0 80
    sync
  done < <(print_str_or_file "$@")
}
declare -a options="$(getopt -o f:,s:,p: --long input-file:,input-string:,pipe-input,plugin-fns: -- "$@")"
eval set -- "$options"
while [ $# -gt 0 ]; do
  case "$1" in
  -f|--input-file) 
    mk_layer_sfs -f "$2"
    shift 2; ;;      
  -s|--input-string) 
    mk_layer_sfs -s "$2"
    shift 2; ;;   
  -p|--pipe-input)
    mk_layer_sfs -p
    shift 1; ;;
  --plugin-fns)
    source $2
    shift 2; ;;
  --) 
    shift 1
    options2+=( "$@" )
    break; ;;
  *)
     options2+=( "$1" )
     shift 1; ;;
  esac
done
for item_source in "${LAYER_SOURCES[@]}"; do
    case "$item_source" in
    input-file)
    mount_items "$INPUT_FILE"
  items+="$(get_items -f "$INPUT_FILE")"; ;;
  esac
done

### END ###