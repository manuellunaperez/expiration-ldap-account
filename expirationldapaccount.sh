#!/bin/bash

servidorldap="ldap.manuel.com"
adminldap="cn=Manager,dc=cica,dc=es"
passldap="-"
ramaldap="ou=People,dc=manuel,dc=com"
#obtenerdatos=`ldapsearch -H $servidorldap -x -D "$adminldap" -w "$passldap" -b "$ramaldap" "modifyTimestamp" |egrep "dn:|modifyTimestamp:" | tr -d " " | cut -d "=" -f 2 | tr -d "\n" | sed s/Z/"\n"/g`

diaactual=`date +%s`
margenmin=`date +%s --date='-11 month'` #Se avisará cuando quede un mes hasta la fecha de expiración 
margenmax=`date +%s --date='-12 month'` #El tiempo de expiración será de 1 año
declare -A Usuarios

Calculardias() {
	local nombre=$1
	local fecha=$2
	local fechacaducidad=`date +%Y/%m/%d -d "$fecha + 1 year"`
	local fechacaducidadUE=`date +%s -d "$fecha + 1 year"`
	local diferencia=$(( ( fechacaducidadUE - diaactual) / 86400 ))
	if [[ $diferencia -le 7 ]] ;then
	fi
	if [[ $diferencia -gt 7 ]]  && [[ $diferencia -le 14 ]];then
	fi
	if [[ $diferencia -gt 14 ]] && [[ $diferencia -le 21 ]];then
	fi
	if [[ $diferencia -gt 21 ]] && [[ $diferencia -lt 31 ]];then
	fi
	echo "La fecha de expiración de la cuenta del usuario $nombre se aproxima: $fechacaducidad"
	echo "Quedan $diferencia dias para que expire la cuenta"
}

Acciones() {
	local nombre=$1
	echo "La cuenta del usuario $nombre ha caducado"
	echo $'Pulse 0 para salir. \nPulse 1 para bloquear la cuenta. \nPulse 2 para renovar la cuenta.'
	read -n1 -p "Introduzca un opción ha realizar con el usuario: " ACCION
	case $ACCION in
		0)
			clear
			echo $'Adios.\n'
			exit;;
		1)
			clear
			echo "La cuenta del usuario $nombre ha sido bloqueada."
			;;
		2)
			clear
			echo "La cuenta del usuario $nombre ha sido renovada."
			;;
		*)
			clear
			echo "ERROR: No existe esa opción" 
			Acciones $nombre
			;;
	esac
}

for i in $obtenerdatos; do
        nombre=`echo $i | cut -d "," -f 1`
        fecha=`echo $i | cut -d ":" -f 2 | cut -c 1-8`
        fechaaltaUE=`date --date="$fecha" +%s`
        if [[ $fechaaltaUE -le $margenmin ]] && [[ $fechaaltaUE -gt $margenmax ]]; then
			Calculardias $nombre $fecha
        fi
        if [[ $fechaaltaUE -lt $margenmax ]]; then
			Acciones $nombre
        fi
done




