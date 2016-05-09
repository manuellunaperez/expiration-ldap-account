#!/bin/bash

servidorldap="ldap.manuel.com"
adminldap="cn=Manager,dc=cica,dc=es"
passldap="-"
ramaldap="ou=People,dc=manuel,dc=com"
#obtenerdatos=`ldapsearch -H $servidorldap -x -D "$adminldap" -w "$passldap" -b "$ramaldap" "modifyTimestamp" |egrep "dn:|modifyTimestamp:" |cut -d "," -f 1`

diaactual=`date +%s`
margenmin=`date +%s --date='-11 month'`
margenmax=`date +%s --date='-12 month'`
declare -A Usuarios


Calculardias() {
        local nombre=$1
        local fecha=$2
        local fechacaducidad=`date +%Y/%m/%d -d "$fecha + 1 year"`
        local fechacaducidadUE=`date +%s -d "$fecha + 1 year"`
        local diferencia=$(( ( fechacaducidadUE - diaactual) / 86400 ))
        echo "La fecha de expiración de la cuenta del usuario $nombre se aproxima: $fechacaducidad"
        echo "Quedan $diferencia dias para que expire la cuenta"
}


obtenerdatos=`ldapsearch -h ldap.manuel.com -p 389 -x -b "ou=People,dc=manuel,dc=com" "modifyTimestamp" |egrep "dn:|modifyTimestamp:" | tr -d " " | cut -d "=" -f 2 | tr -d "\n" | sed s/Z/"\n"/g`

for i in $obtenerdatos; do
        nombre=`echo $i | cut -d "," -f 1`
        fecha=`echo $i | cut -d ":" -f 2 | cut -c 1-8`
        fechaaltaUE=`date --date="$fecha" +%s`
        if [[ $fechaaltaUE -le $margenmin ]] && [[ $fechaaltaUE -gt $margenmax ]]; then
                Calculardias $nombre $fecha
        fi
        if [[ $fechaaltaUE -lt $margenmax ]]; then
                echo "La cuenta del usuario $nombre está caducada"
        fi
done




