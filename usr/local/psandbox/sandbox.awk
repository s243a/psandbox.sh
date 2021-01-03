#!/usr/bin/gawk -f 
@include "./sandbox_fns.awk"
    BEGIN {OFS=" "}
    /^\s*$/ {next}
    /==mount==/ { mode=1 }
    /==losetup==/ { mode=2 }
    /==branches==/ { mode=3 }
    !/^[\s]*$/ {
    if (mode == 1) {
      # get list of mount points, types, and devices - index is $3 (mount points)
      mountdev[$2]=$1
      mounttypes[$2]=$3
      
      field2[$2]=$3
    } else if (mode == 2) {
      # get list of loop devices and files - index is $1 (loop devs)
      sub(/:/,"",$1)
      loopdev_full[$1]=remove_parentheses($3)
      sub(/.*[/]/,"",$3); sub(/)/,"",$3)
      loopdev[$1]=$3
    } else if (mode == 3) {
      # map mount types to loop files if mount devices is a loop
      for (m in mountdev) {
        if ( loopdev[mountdev[m]] != "" ){
			 BNAME=loopdev[mountdev[m]]
             sub(/.*[/]/,"",BNAME)    
			 field2[m]=BNAME
			 mountpath[m]=loopdev_full[mountdev[m]]
			 system("echo 'BNAME=" BNAME " m=" m " mountpath[m]=" mountpath[m] "' > /dev/stderr")
	    }
	    
      }
      # for (m in mountdev) print m " on " mountdev[m] " type " mounttypes[m]
      mode=4
    } else if (mode==4) {
      key=remove_quotes($1)
      
      # print the branches and its mappings
	  system( "echo 'AWK (mode==4):" $0 "' >/dev/stderr" )      
	  if ( !(key in field2)){
        MNT_PT=$1
        MNT_PATH=$2
        if (length(MNT_PATH)==0){
          MNT_PATH=$1
        }
        mountpath[$1]=MNT_PATH
        
        if (length(MNT_PATH) ==0){
           next
        }
        print "mount_if_valid(" MNT_PT "," MNT_PATH "," PDRV ")" > "/dev/stderr"
        mnt_status=mount_if_valid(MNT_PT,MNT_PATH,PDRV)
        if(mnt_status == "fail"){
            next
        }
        BNAME=MNT_PATH
        sub(/.*[/]/,"",BNAME)    
         field2[MNT_PT]=BNAME
      }
      if (NF>2){
         STATE=$3
      } else {
           STATE=on
      }      
      STATE=remove_quotes(STATE)
      if ( STATE !~ /(on|off)/){
          STATE=on
      }
              
      start=length($1)-MAX_STR_LEN
      if (start<1) start=1
      #field1[$1]=substr($1,start)
      field1[key]=key
        #out1=field1[$1] " " field2[$1] " " STATE
        #out2=$1 " " mounttypes[$1] " " mountpath[$1]
        #print out1
        #print out2 > OUTFILE
      if (length(mounttypes[key]) ==0 ){
		  mounttypes[key]="none"
	  }
	  field4="\"" key "\""
	  field5="\"" mounttypes[key] "\"" 
	  field6=mountpath[key]
	  field7=get__dev_mnt_pt(field6,"","") #args mount path, dev mnt pt (maybe shoudl be dev path), uuid)
	  field8=get__dev(field7)
	  field9=get__uuid(field8,"") #args: dev, uuid
      print field1[key],field2[key],STATE
      field6="\"" field6 "\""; field7="\"" field7 "\""; field8="\"" field8 "\"";field9="\"" field9 "\"";  
      print "\"" field1[key] "\"","\"" field2[key] "\"","off",field4,field5,field6,field7,field8,field9 > OUTFILE
    }
  }