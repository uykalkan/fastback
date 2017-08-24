#!/bin/bash

blacklist=("Database" "information_schema" "mydb" "mysql" "performance_schema" "phpmyadmin" "sys" "cphulkd")
blacklist_user=("system")
fastbackfolder="/fastback"
#fastbackfolder="$HOME/fastback" #local
#mysql_query_prefix="-u root -p784512" #local
mysql_query_prefix="" #server

source variables.txt

tmpfolder="/tmp/fastback"

# GEREKLİ FONKSİYONLAR

now() {
	echo $(date +"%d-%m-%Y__%H-%M-%S")
}

isfolder() {
	if [ -d "$1" ]
	then
		return 0 
	else
		return 1
	fi
}

isfile() {
	if [ -f "$1" ]
	then
		return 0 
	else
		return 1
	fi
}

explode () {
	#arr=($(explode "," "sti,ng"))
	#echo ${arr[0]}
	arr=(${2//$1/ })
	echo ${arr[@]}
}

sqlfolder() {
	folder=()
	for dir in $(ls $fastbackfolder/sql); do
		if isfolder "$fastbackfolder/sql/$dir";then 
			folder+=($dir)
		fi
	done	

	echo ${folder[@]}
}

lsfolder() {
	# lsfolder . block1 block2 
	# birinci değişken ls çekilecek klasör sonraki değişken blackliste alınacak klasörler
	# Kullanım Örneği:
	# for i in $(lsfolder .)
	# done
	folder=()
	for dir in $(ls $1); do
		blocked=false
		for i in $@; do
			if [[ $i == $dir ]]; then
				blocked=true
			fi
		done

		if !(isfolder "$1/$dir");then 
			echo $1/$dir
			blocked=true
		fi

		if [[ $blocked == false ]]; then
			folder+=($dir)
		fi
		
	done	

	echo ${folder[@]}
}

lsfile() {
	# lsfile . block1 block2 
	# birinci değişken ls çekilecek klasör sonraki değişken blackliste alınacak klasörler
	# Kullanım Örneği:
	# for i in $(lsfile .)
	# done
	file=()

	for dir in $(ls $1); do
		blocked=false
		for i in $@; do
			if [[ $i == $dir ]]; then
				blocked=true
			fi
		done

		if !(isfile "$1/$dir");then 
			blocked=true
		fi

		if [[ $blocked == false ]]; then
			file+=($dir)
		fi
		
	done	

	echo ${file[@]}
}

say() {
	case $1 in
		"hata")
			echo -e "${COLOR_LIGHT_RED}${2}${COLOR_NC}"
		;;
		"soru")
			echo -e "${COLOR_YELLOW}${2}${COLOR_NC}"
		;;
		*)
			echo -e "${COLOR_LIGHT_CYAN}${1}${COLOR_NC}"
		;;
	esac	
}

# GEREKLİ KLASÖRLER AÇILIYOR...

if !(isfolder "/var/cpanel/users");then 
	say hata "$STR_CPANELFAIL"
	exit
fi

if !(isfolder "$fastbackfolder");then 
	mkdir $fastbackfolder
fi

if !(isfolder "$fastbackfolder/sql");then 
	mkdir $fastbackfolder/sql
fi

if !(isfolder "$fastbackfolder/www");then 
	mkdir $fastbackfolder/www
fi

if !(isfolder "$fastbackfolder/trash");then 
	mkdir $fastbackfolder/trash
fi

if !(isfolder "$fastbackfolder/transfer");then 
	mkdir $fastbackfolder/transfer
fi

if !(isfolder "/tmp/fastback");then 
	mkdir /tmp/fastback
fi

for line in $(mysql $mysql_query_prefix -e 'show databases;'); do 
	blocked=false
	for i in "${blacklist[@]}"; do
		if [[ $i == $line ]]; then
			blocked=true
		fi
	done

	if [[ $blocked == false ]]; then
		databases+=("$line")
	fi
done

backup_database() {
	clear
	PS3=$(say soru "$STR_WHICHDBBACKUP")
	select opt in ${databases[@]}
	do
		if [[ $opt ]]; then
			# SQL Klasöründe bu database'in klasörü yoksa açalım
			if isfolder "$fastbackfolder/sql/$opt";then 
				echo # !isfolder tarzında kullanıma geçilecek ileride
			else 
				mkdir "$fastbackfolder/sql/$opt"
			fi

			filename="$fastbackfolder/sql/$opt/$(now).sql"
			mysqldump $mysql_query_prefix $opt > "$filename"
			ret=$?
			
			if [ "$ret" = "0" ]; then
			    say "$filename $STR_BACKUPSUCCESS"
			    break
			else
			    say hata "$filename $STR_BACKUPFAIL"
			fi

		else
			say hata "$STR_INVALIDSELECTION"
		fi
	done	
}

restore_database() {
	if [ ! $(sqlfolder) ]; then
		say hata "$STR_NOBACKUPFOUNDDB"
		break
	fi
	clear
	PS3=$(say soru "$STR_WHICHDBRESTORE")
	select folder in $(sqlfolder)
	do
		if [[ $folder ]]; then
			# SQL Klasöründe bu database'in klasörü yoksa açalım
			if isfolder "$fastbackfolder/sql/$folder";then 

				for i in $(ls "$fastbackfolder/sql/$folder"); do
					arr=($(explode "." "$i"))
					sqlfiles+=(${arr[0]})
				done

				PS3=$(say soru "$STR_WHICHDATERESTORE the $folder ?")
				select sqlfile in ${sqlfiles[@]}
				do
					mysql -e "DROP DATABASE $folder;"
					mysql -e "CREATE DATABASE $folder;"
					mysql $mysql_query_prefix $folder < $fastbackfolder/sql/$folder/$sqlfile.sql
					ret=$?

					if [ "$ret" = "0" ]; then
					    say "$STR_RESTORESUCCESS"
					    break
					else
					    say hata "$STR_RESTOREFAIL $STR_RELATEDMYSQL"
					fi

				done
			else 
				say hata "$STR_FOLDERNOTFOUND"
			fi

			break
		else
			say hata "$STR_INVALIDSELECTION"
		fi
	done
}

backup_www() {
	PS3=$(say soru "$STR_WHICHUSERBACKUP")
	select opt in $(lsfile /var/cpanel/users system)
	do
		if (isfolder "/home/$opt/public_html" == 1);then 
			foldername=$(now)
			folderpath=$tmpfolder/$opt/$foldername

			mkdir $tmpfolder/$opt
			mkdir $fastbackfolder/www/$opt

			mkdir $tmpfolder/$opt/$foldername
			mkdir $fastbackfolder/www/$opt/$foldername

			rsync -avz /home/$opt/public_html $folderpath
			mv $folderpath $fastbackfolder/www/$opt
			
			ret=$?
			if [ "$ret" = "0" ]; then
			    say "$STR_BACKUPSUCCESS"
			    break
			else
			    say hata "$STR_BACKUPFAIL"
			fi
		else
			say "$STR_FOLDERNOTFOUND"
		fi

	done
}

restore_www() {
	clear
	PS3=$(say soru "$STR_WHICHUSERRESTORE")
	select folder in $(lsfolder "$fastbackfolder/www")
	do
		if [[ $folder ]]; then
			# SQL Klasöründe bu database'in klasörü yoksa açalım
			if isfolder "$fastbackfolder/www/$folder";then 
				PS3=$(say soru "$STR_WHICHDATERESTORE the $folder ?")
				select selected_folder in $(lsfolder "$fastbackfolder/www/$folder/")
				do

					#mkdir $tmpfolder/transfer/$selected_folder
					rsync -avz $fastbackfolder/www/$folder/$selected_folder $fastbackfolder/transfer/					

					# Var olanı silmeyelim çöpe atalım ileride çöpten geri al yapacağız
					nowtime=$(now)
					mkdir $fastbackfolder/trash/$folder
					mkdir $fastbackfolder/trash/$folder/$nowtime
					mv /home/$folder/public_html $fastbackfolder/trash/$folder/$nowtime/public_html

					mv $fastbackfolder/transfer/$selected_folder/public_html /home/$folder/public_html
					rm -rf $fastbackfolder/transfer/*
					
					ret=$?
					if [ "$ret" = "0" ]; then
					    say "$STR_RESTORESUCCESS"
					    break
					else
					    say hata "$STR_RESTOREFAIL"
					fi
				done
			else 
				say hata "$STR_FOLDERNOTFOUND"
			fi

			break
		else
			say hata "$STR_INVALIDSELECTION"
		fi
	done
}

backup() {

	if [[ $1 ]]; then
		case $1 in
			"www")
				backup_www $@
			;;
		   "db")
				backup_database $@
			;;
		   *)
			  say hata "$STR_INVALIDCOMMAND"
			;;
		esac
		return
	fi

	clear
	PS3=$(say soru "$STR_BACKUPWHAT")
	select opt in "$STR_WWWFOLDER" "$STR_DATABASE"
	do
		case $opt in
		   "$STR_WWWFOLDER") 
				backup www
				break
			;;
		   "$STR_DATABASE")
				backup db
				break
			;;
		   *)
				say hata "$STR_INVALIDCOMMAND"
			;;
		esac
	done

}

restore() {

	if [[ $1 ]]; then
		case $1 in
			"www")
				restore_www $@
				break
			;;
		   "db")
				restore_database $@
				break
			;;
		   *)
				say hata "$STR_INVALIDCOMMAND"
			;;
		esac
	fi

	clear
	PS3=$(say soru "$STR_RESTOREWHAT")
	select opt in "$STR_WWWFOLDER" "$STR_DATABASE"
	do
		case $opt in
		   "$STR_WWWFOLDER")
				restore www
				break
			;;
		   "$STR_DATABASE")
				restore db
				break
			;;
		   *)
			  say hata "$STR_INVALIDCOMMAND"
			;;
		esac
	done
}

if [[ $1 ]]; then
	function_name=$@
	eval ${function_name}
else 

	clear
	PS3=$(say soru "$STR_SELECTOPERATION")
	select opt in "$STR_BACKUP" "$STR_RESTORE"
	do
		case $opt in
		   "$STR_BACKUP")
				backup
				break
			;;
		   "$STR_RESTORE")
				restore
				break
			;;
		   *)
			  say hata "$STR_INVALIDCOMMAND"
			;;
		esac
	done
fi