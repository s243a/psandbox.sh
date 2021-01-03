function get_ws_field(){
  
}
function mnt_home_first(){
  local rest
  local first
  while read line; do
    if [[ "$line" = *dev_save* ]]; then
      first="$line"
    else
      rest="$rest"$'\n'"$line"
    fi
  done
  echo "$rest"| grep -v "^$"
}
function get_puppy_paths(){
  [ -z "$CWD" ] & CWD=$(realpath .)
  if [ -z "$PDRV" ]; then
   for a_folder in "${PSUBDIR}" "PSAVE" "$RW_LAYER"; do
   while read PDRV_line; do 
     if [ -z  "PSAVE" ] && [ -z "$RW_LAYER" ] && break
     PDRV_mnt_try=$(echo "$PDRV_line" | cut -f2 -d' ')
     #for a_path in "$PDRV_try/${PSUBDIR}" "PSAVE" "$RW_LAYER"; do
       a_path="$PDRV_try/$a_folder"
       key=md5_$(md5sum < <( echo "$a_path" ) | cut -f1 -d' ')
       Puppy_Path_Tries[$key]="$a_path"
       PDRV_mnt_tries[$key]="$PDRV_mnt_try"
       PDRV_dev_tries[$key]=$(echo "$PDRV_line" | cut -f1 -d' ')
    done < <(echo_pdrvs)
    for a_path in "PSAVE" "$RW_LAYER"; do
       PDRV_mnt_try=$(df "$a_path" | sed -r 's#^([^[:blank:]]+[[:blank:]]+){5,5}##g' | grep -v "Mounted on")
       PDRV_dev_try=$(df "$a_path" | cut -f1 -d' '| grep -v 'Filesystem')

     #for a_path in "$PDRV_try/${PSUBDIR}" "PSAVE" "$RW_LAYER"; do
       a_path="$PDRV_try/$a_folder"
       key=md5_$(md5sum < <( echo "$a_path" ) | cut -f1 -d' ')
       Puppy_Path_Tries[$key]=$a_path
       PDRV_mnt_tries[$key]=$PDRV_mnt_try
       PDRV_dev_tries[$key]=$PDRV_dev_try
    done    
    #done 
    for a_key in ${!PDRV_mnt_tries}; do
      PUPPY_SFS_try=$(ls -1 "${Puppy_Path_Tries[$key]}"/.. | grep -E 'puppy_.*[.]sfs')
      if [ ! -z "$PUPPY_SFS_try" ]; then
        get_puppy_paths__rtn__path=$(realpath "${Puppy_Path_Tries[$key]}")
        get_puppy_paths__rtn__dev=$(realpath "${PDRV_dev_tries[$key]}")
        get_puppy_paths__rtn__mnt=$(realpath "${PDRV_dev_tries[$key]}")
        break
      fi
    done
  done 
}
function echo_pdrvs(){
	if [ ! -z  "PSAVE" ] || [ ! -z "$RW_LAYER" ]; then 
	  if [ -d 
	  lsblk -lo NAME,TYPE,MOUNTPOINT | grep part | cut -f1,4 -d' ' | mnt_home_first #TODO make this more robust (e.g. handle multple spaces sperating fields)
	else #This is to keep the pipe from hanging. 
	  echo /mnt/home
	fi
}
#export -f echo_pdrvs