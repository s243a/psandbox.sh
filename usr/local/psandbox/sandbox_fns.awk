#!/usr/bin/gawk -f 
    function remove_parentheses(s1,s){
	  s=s1
	  sub(/^[(]/,"",s)
	  sub(/[)]$/,"",s)
	  return s	
    }
    function remove_quotes(s1,     s){
	  s=s1
	  sub(/^["']/,"",s)
	  sub(/["']$/,"",s)
	  return s	
    }
    #function mount(MNT_PT,MNT_PATH){
    #  system("mkdir -p " MNT_PT)
    #  system("mount " MNT_PATH " " MNT_PT 2>/dev/null)
    #}
    function mount_if_valid(MNT_PT,MNT_PATH,PROOT,PDRV                  ,F_MNT_PATH,D_MNT_PATH){
          if (system("[ -f " MNT_PATH " ] && exit 0 || exit 1") == 0){
            F_MNT_PATH=MNT_PATH
          } else if (system("[ -f " PROOT "/" MNT_PATH " ] && exit 0 || exit 1") == 0){
           F_MNT_PATH=PROOT "/" MNT_PATH
         } else if (system("[ -f " PDRV "/" PROOT "/" MNT_PATH " ]  && exit 0 || exit 1") == 0){
           F_MNT_PATH=PROOT "/" MNT_PATH
          } else if (system("[ -d " MNT_PATH " ] && exit 0 || exit 1") == 0){
            D_MNT_PATH=MNT_PATH
         } else if (system("[ -d " PROOT "/" MNT_PATH " ]  && exit 0 || exit 1") == 0){
           D_MNT_PATH=PROOT "/" MNT_PATH
         } else if (system("[ -d " PDRV "/" PROOT "/" MNT_PATH " ]  && exit 0 || exit 1") == 0 ){
           D_MNT_PATH=PROOT "/" MNT_PATH
         } else {
           F_MNT_PATH=""
           D_MNT_PATH=""
        }
        if (length(F_MNT_PATH)>0){
            mount(MNT_PT,F_MNT_PATH)
            if (system("cat /proc/mounts | grep -c -m1 " MNT_PT) > 0){
              result=sucess }
            else {
              result=fail }
        }
        else if (length(D_MNT_PATH)>0) {
           result=directory
        } else { 
          result=fail 
        }
        return result     
    }
#Field 4 is the mount point
#Field 1 is also the mount point but maybe be trimmed in the future
#Field 6 is the path to the file being mounted
#Field 7 is the mount device but it may be blank
#Field 8 is the uuid but might be blank
#Field 9 is the device
function get_mp(dev,   mp,cmd){
  #cmd="cat /proc/mounts | grep \"$(realpath " dev ")\""
  cmd="cat /proc/mounts | grep '" dev "'"
  while ((cmd | getline )){
    if ( index($1,dev)>0 ){
      mp=$2
      
      break
    }
  }
  close(cmd)
  return mp
}
function realpath(p,    cmd,rp){
  cmd="realpath '" p "'"
  while ((cmd | getline )){
	  rp=$0
	  break
  }
  close(cmd)
  if (length(rp)>0){
	return rp
  } else {
	print "Warning realpath not found for " p > "/dev/stderr"
    return p
  }	
}
function get_dev_mp(path,    mp,rp,count,cmd,cmd2){
  #cmd="cat /proc/mounts | grep \"$(realpath " dev ")\""
  rp=realpath(path)
  cmd="cat /proc/mounts" # | grep \"$(realpath '" rp "')\""
  while ((cmd | getline )){
	#dev=$1 #don't need this yet
	print "cmd_out=" $0 > "/dev/stderr"
	mp=$2
	cmd2="echo " rp " | grep -c " mp 
	while ((cmd2 | getline )){
	    print "cmd2_out=" $0 > "/dev/stderr"
		count=$0
		break #this is uncessary
    }
    close(cmd2)
    if ( count>0 ){
      break
    }
  }
  close(cmd)
  if (count==0){
      print "get_dev_mp(path=" path ")" > "/dev/stderr"
      print "Warning: dev not mounted! Inferring dev mount point from path" > "/dev/stderr"
	  mp=gensub(/^(.*[/]mnt[/][^/]*)[/].*/,"\\1",1,rp)
  }
  return mp
}
#Field 6 is the path to the file being mounted
#Field 7 is the mount device but it may be blank
#Field 8 is the uuid but might be blank
function get__dev_mnt_pt(f6,f7,f8,    mp,dev,dev_mp){
  if (length(f8)>0){ #f8 is the uuid or label
    blkid_line(f8)
    dev=BLKID_REC["DEV"]
    dev_mp=get_mp(dev)
    if (length(dev_mp)==0){
      dev_mp=dev
      sub(/^[/](dev)[/](.*)/,"mnt",dev_mp)
    }
  }
  if (length(dev)==0){ #f
    if (length(f7)>0){ #f7 is the mount device but it may be blank
      dev_mp=get_mp(f7) #This only checks existing mounts
      if (length(dev_mp)==0){ #If the mount isn't existing then try to infer it from the path
        dev_mp=f7
        sub(/^[/]dev/,"[/]mnt",dev_mp)
      }
      
    }
    else { #is the path to the file being mounted
     print  "get__dev_mnt_pt(f6=" f6 ",f7=" f7 ",f8=" f8 ")" > "/dev/stderr"
      if (length(f6)>0){
        print "Dev Mount Point Field Empty. Inferring dev mount point from path" > "/dev/stderr"
        print "path=" f6 > "/dev/stderr"
	    dev_mp=get_dev_mp(f6)
	  } else
	  {
	     print "Dev Mount Point Field Empty. " > "/dev/stderr"
	  }
      #dev_mp=gensub(/^([/][^/]*[/][^/]*)[/].*/,"\\1",1,f6)
    }
  }
  return dev_mp
}
#function get__mounted_dev(mp){
#  #cmd="cat /proc/mounts | grep \"$(realpath " dev ")\""
#  cmd="cat /proc/mounts | grep '" mp "'"
#  while ((cmd | getline )){
#    #this could potentially return a false positive
#    if ( index($2,mp)>0 ){
#      return $1
#      break
#    }
#  }
#}
function get__mounted_dev(path,    rp,cmd,m_dev){
  rp=realpath(path)
  cmd="cat /proc/mounts" # | grep '" rp "'"
  #cmd="mount" # | grep '" rp "'"
  print "get__mounted_dev(" path ")" > "/dev/stderr"
  print "cmd=" cmd > "/dev/stderr"
  while (cmd | getline ){
	print $0 > "/dev/stderr"
    if ( index($2,rp)==1 ){
      m_dev=$1
      break
    }
  }
  close(cmd)
  return m_dev
}
function get__dev(s,    dev){
  dev=get__mounted_dev(s)
  if (length(dev)==0){
    print "dev not mounted" > "/dev/stderr"
    print "s=" s > "/dev/stderr"
    blkid_line(s)
    dev=BLKID_REC["DEV"]
  }
  return dev
}


function get__dev_path(f6,f7,f8,    mp,dev,dev_name){
  if (length(f8)>0){ #Field 8 is the uuid or label but might be blank
    blkid_line(f8)
    dev=BLKID_REC["DEV"]
  }
  if (length(f7)>00){ #Field 7 is the mount device but it may be blank
    dev=f7
  } else { #Field 6 is the path to the file being mounted
    dev_name=gensub(/^[/][^/]*[/]([^/]*)([/].*)?/,"\\1","",f6)
    dev="/dev/" dev_name
  }
  return dev
}
function blkid_line(s,   i,field,field_val,cmd){
  delete BLKID_REC
  cmd="blkid | grep " s
  #print cmd > "/dev/stderr"
  while ((cmd | getline )){
    BLKID_REC["DEV"]=$1
    #array_size
    #print "blkid_line:" $0 > "/dev/stderr"
    #print "BLKID_REC[\"DEV\"]=" $1 > "/dev/stderr"
    for (i = 2; i<=NF; i++){
      
      field_val=gensub(/^[^=]*=[\"]([^\"]*)[\"]$/,"\\1",1,$i)
      field=$i
      sub(/=.*$/,"",field)
      #print "BLKID_REC[\"" field "\"]=" field_val > "/dev/stderr"
      BLKID_REC[field]=field_val
    }
    break 
  }
  close(cmd)
} 

#s can be any regX to filter the blkid output
#s is usually the device (e.g. /dev/sda or sda)
function get__uuid(s,uuid){
  if (length(uuid)==0){
    blkid_line(s)
    return BLKID_REC["UUID"]
  }
  else {
    return uuid
  }
}