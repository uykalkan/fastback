#!/bin/bash

blacklist=("Database" "information_schema" "mydb" "mysql" "performance_schema" "phpmyadmin" "sys" "cphulkd")
blacklist_user=("system")
fastbackfolder="/fastback"
#fastbackfolder="$HOME/fastback" #local
#mysql_query_prefix="-u root -p784512" #local
mysql_query_prefix="" #server

mkdir $fastbackfolder
mkdir $fastbackfolder/sql
mkdir $fastbackfolder/www
mkdir $fastbackfolder/trash
mkdir $fastbackfolder/transfer

if !(isfolder "/tmp/fastback");then 
	mkdir /tmp/fastback
fi

tmpfolder="/tmp/fastback"

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

clear

# echo ${databases[@]};

export COLOR_NC='\e[0m' # No Color
export COLOR_WHITE='\e[1;37m'
export COLOR_BLACK='\e[0;30m'
export COLOR_BLUE='\e[0;34m'
export COLOR_LIGHT_BLUE='\e[1;34m'
export COLOR_GREEN='\e[0;32m'
export COLOR_LIGHT_GREEN='\e[1;32m'
export COLOR_CYAN='\e[0;36m'
export COLOR_LIGHT_CYAN='\e[1;36m'
export COLOR_RED='\e[0;31m'
export COLOR_LIGHT_RED='\e[1;31m'
export COLOR_PURPLE='\e[0;35m'
export COLOR_LIGHT_PURPLE='\e[1;35m'
export COLOR_BROWN='\e[0;33m'
export COLOR_YELLOW='\e[1;33m'
export COLOR_GRAY='\e[0;30m'
export COLOR_LIGHT_GRAY='\e[0;37m'

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

backup_database() {
	clear
	PS3=$(say soru "Hangi Veritabanı Yedeklenecek?")
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
			    say "$filename Yedekleme işlemi tamamlandı"
			    break
			else
			    say hata "$filename Yedekleme başarısız!"
			fi

		else
			say hata "İyi oku rakamları!"
		fi
	done	
}

restore_database() {
	if [ ! $(sqlfolder) ]; then
		say hata "Hiç veritabanı yedeği almamışsınız"
		break
	fi
	clear
	PS3=$(say soru "Hangi Veritabanı Geri Alınacak?")
	select folder in $(sqlfolder)
	do
		if [[ $folder ]]; then
			# SQL Klasöründe bu database'in klasörü yoksa açalım
			if isfolder "$fastbackfolder/sql/$folder";then 

				for i in $(ls "$fastbackfolder/sql/$folder"); do
					arr=($(explode "." "$i"))
					sqlfiles+=(${arr[0]})
				done

				PS3=$(say soru "$folder veritabanı hangi zamana geri dönsün?")
				select sqlfile in ${sqlfiles[@]}
				do
					mysql -e "DROP DATABASE $folder;"
					mysql -e "CREATE DATABASE $folder;"
					mysql $mysql_query_prefix $folder < $fastbackfolder/sql/$folder/$sqlfile.sql
					ret=$?

					if [ "$ret" = "0" ]; then
					    say "Geri Dönüş Başarılı"
					    break
					else
					    say hata "Geri dönüş başarısız oldu (mysql ile alakalı)"
					fi

				done
			else 
				say hata "Klasör Bulunamadı!"
			fi

			break
		else
			say hata "İyi oku rakamları!"
		fi
	done
}

backup_www() {
	PS3=$(say soru "Hangi Kullanıcı Yedeklenecek?")
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
			    say "Yedekleme Başarılı"
			    break
			else
			    say hata "Yedekleme başarısız oldu"
			fi
		else
			say "yok böyle bir klasör"
		fi

	done
}

restore_www() {
	clear
	PS3=$(say soru "Hangi Site Geri Alınacak?")
	select folder in $(lsfolder "$fastbackfolder/www")
	do
		if [[ $folder ]]; then
			# SQL Klasöründe bu database'in klasörü yoksa açalım
			if isfolder "$fastbackfolder/www/$folder";then 
				PS3=$(say soru "$folder kullanıcısının www klasörü hangi zamana geri dönsün?")
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
					    say "Geri Alma Başarılı"
					    break
					else
					    say hata "Geri Alma başarısız oldu"
					fi

					echo $selected_folder
				done
			else 
				say hata "Klasör Bulunamadı!"
			fi

			break
		else
			say hata "İyi oku rakamları!"
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
			  say hata "Yok böyle bir komut!"
			;;
		esac
		return
	fi

	clear
	PS3=$(say soru "Neyi Yedekliyoruz?")
	select opt in "WWW klasörünü yedekleyeceğim" "Veritabanını yedekleyeceğim"
	do
		case $opt in
		   "WWW klasörünü yedekleyeceğim") 
				backup www
				break
			;;
		   "Veritabanını yedekleyeceğim")
				backup db
				break
			;;
		   *)
				say hata "Yok böyle bir komut!"
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
				say hata "Yok böyle bir komut!"
			;;
		esac
	fi

	clear
	PS3=$(say soru "Neyi Geri Alalım?")
	select opt in "WWW klasörünü geri alalım" "Veritabanını geri alalım"
	do
		case $opt in
		   "WWW klasörünü geri alalım")
				restore www
				break
			;;
		   "Veritabanını geri alalım")
				restore db
				break
			;;
		   *)
			  say hata "Yok böyle bir komut!"
			;;
		esac
	done
}

if [[ $1 ]]; then
	function_name=$@
	eval ${function_name}
else 

	clear
	PS3=$(say soru "İşlem Nedir?")
	select opt in "Yedekleme (Backup)" "Geri Yükleme (Restore)"
	do
		case $opt in
		   "Yedekleme (Backup)")
				backup
				break
			;;
		   "Geri Yükleme (Restore)")
				restore
				break
			;;
		   *)
			  say hata "Yok böyle bir komut!"
			;;
		esac
	done
fi