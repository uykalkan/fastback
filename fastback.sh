#!/bin/bash

now() {
	echo $(date +"%d-%m-%Y__%H-%M-%S")
}

echo $(now)

exit
blacklist=("Database" "information_schema" "mydb" "mysql" "performance_schema" "phpmyadmin" "sys")

mysql_query_prefix="-u root -p784512" #local
# mysql_query_prefix="" #server

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
			mysqldump $mysql_query_prefix $opt > yedek.sql
			say "$opt.sql Yedekleme işlemi tamamlandı"
			break
		else
			say hata "İyi oku rakamları!"
		fi
	done	
}

restore_database() {
	say 'Database Restore Edildi'
}

backup_www() {
	say 'WWW klasörü yedeklendi'
}

restore_www() {
	say 'WWW klasörü geri yüklendi'
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
			;;
		   "db")
				restore_database $@
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