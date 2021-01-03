function real_dirname_helper_grep_proc_mnts(){
	local a_path="$(realpath -m "$1")"
	local a_line
	local mnt_pt
	local subdir
	#local mounts_last="$(cat /proc/mounts)"
	local R_path="/${a_path#/*/}"
	local L_path=${a_path#a_p%"$a_path2"}
	local R_path_last="$R_path"
	local L_path_last="$L_path"
	local mounts=${echo "$mounts" | grep "$L_path"}
	local mounts_last=mounts
	mounts_new_file=$(mktemp -p /tmp)
	rm -f "mounts_new_file"
	touch "mounts_new_file"
	while ture; do
	  while read a_line; do
	    if [ ${#mounts} -eq 0 ]; then
	      if [ ${#mounts} -ne 0 ]; then #paranoid check
	        while read mount_line; do 
	            dev__mnt_pt=$(echo "$mount_line" | sed -r 's#([[:blank:]]+[^[:blank:]]+){4,4}$##g')
	            a_dev=${dev__mnt_pt%%" "*}
	            a_mnt_pt=${dev__mnt_pt#"$a_dev "}
	            a_mnt_source=$(cat /proc/self/mountinfo | grep "$a_dev" | grep "a_mnt_pt")
	            [ ${#a_mnt_source} -gt 1 ] && a_mnt_pt=$a_mnt_source$a_mnt_pt
	            case "$a_dev" in
	            /dev/loop*)   
                   file_path=$(losetup-FULL -a | grep "$a_dev")
                   file_path=${file_path#*(}
				   file_path=${file_path%)*}
				   #TODO return result of :
				   #Call this function again with file_path
				   #append R_path to the result. 
				   #!!! In some cases we might not care about the full device path. 
				   ;;
	            /dev/*) 
	              #PDRV_UUID="$(echo "$1" | awk -v FIELD_NUM=8 -f "$SB_DB_REC_FIELD_AWK")"	            	               
	              #PDRV_real=$(blkid | grep $a_dev|)
	               PDRV_real=$(blkid | grep " $a_dev" | tr ' ' '\n' | grep -E '^(UUID=)')
	               subdir=${a_mnt_pt#/}${R_path} #Return ths fult once we get no more items from mounts. 
	               
                   ;;
               esac
                   a_path=$a_mnt_pt$subdir
	               R_path="/${a_path#/*/}"
	               L_path=${a_path#a_p%"$a_path2"}
	local R_path_last="$R_path"
	local L_path_last="$L_path"
	local mounts=${echo "$mounts" | grep "$L_path"}               
	        done < <(echo "$mounts")
	      fi
	    fi
	    a_path2="/${a_path2#/*/}"
	    a_path1=${a_path#a_p%"$a_path2"}
	    mounts=${echo "$mounts" | grep 	         
	    if [ "$a_line" = EOF ]; then
	      mnt_pt=cut -d " " -f1
	      break
	       
	  done < <(cat /proc/mounts | grep $(realpath $PDRV_real_i); echo "EOF" | )
	done
}
function real_dirname_helper(){
	local a_path="$(realpath -m "$1")"
	
	while true; do
	  
	done
}
#(!!!!Removed Section -- old set set_sandbox_tmpfs code -- Se psandbox_removed.sh)