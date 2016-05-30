#!/bin/bash

servidorldap="ldaps://ldap1.hpc.cica.es:636"
adminldap="cn=Manager,dc=cica,dc=es"
passldap="-"
ramaldap="ou=supercomputacion,ou=externos,ou=users,ou=cuentas,dc=cica,dc=es"
diaactual=`date +%s`
margenmin=`date +%s --date='-11 month'` #Se avisará cuando quede un mes hasta la fecha de expiracion 
margenmax=`date +%s --date='-12 month'` #El tiempo de expiracion será de 1 año
declare -A Usuariosexpirados
touch info_email.txt
echo "Cuentas que expiran en los próximos 30 días:" > info_email.txt

Calculardias() {
	local nombre=$1
	local fecha=$2
	local fechacaducidad=`date +%Y/%m/%d -d "$fecha + 1 year"`
	local fechacaducidadUE=`date +%s -d "$fecha + 1 year"`
	local diferencia=$(( ( fechacaducidadUE - díaactual) / 86400 ))
	local email=`ldapsearch -H $servidorldap -x -D "$adminldap" -w "$passldap" -b "$ramaldap" -s sub "uid=$nombre" mail |grep ^mail |cut -d " " -f 2`
	WARNING $nombre $email $fechacaducidad
	echo "La fecha de expiración de la cuenta del usuario $nombre se aproxima: $fechacaducidad" >> info_email.txt
	echo "Quedan $diferencia días para que expire la cuenta, un mail fue enviado a $email automáticamente avisando a este usuario." >> info_email.txt
}

bloquearcuenta() {
	for nombre in "${!Usuariosexpirados[@]}"; do
		email=`ldapsearch -H $servidorldap -x -D "$adminldap" -w "$passldap" -b "$ramaldap" -s sub "uid=$nombre" mail |grep ^mail |cut -d " " -f 2`

#		`2>/dev/null 1>/dev/null ldapadd -H $servidorldap -x -D "$adminldap" -w "$passldap" << EOF                                                                                  
#dn: uid=$nombre,$ramaldap
#changeType: modify
#add: pwdAccountLockedTime
#pwdAccountLockedTime: 000001010000Z
#EOF`
#		`2>/dev/null 1>/dev/null ldapadd -H $servidorldap -x -D "$adminldap" -w "$passldap" << EOF                                                                                  
#dn: uid=$nombre,$ramaldap
#changeType: modify
#replace: loginShell
#loginShell: /bin/false
#EOF`
		echo -e "\nEl usuario $nombre ha expirado, puede ponerse en contacto con este usuario a través de $email." >> info_email.txt
		MAIL_EXPIRADO $nombre $email
	done
}	

WARNING() {
	local nombre=$1
	local email=$2
	local fecha=$3
	echo -e "Estimado usuario: \n\nNos ponemos en contacto con usted para informarle que su cuenta llamada $nombre expira el día $fecha \n Para poder utilizando dicho usuario en los servicios de Supercomputación debe renovar su cuenta.\nPara renovar su cuenta debe ponerse en contacto con los servicios de supercomputación a través de la dirección de correo eciencia@cica.es \n" | mail -a "Content-Type: text/plain; charset=UTF-8" -s "Fecha de expiración de su cuenta en servicios de Supercomputación de CICA" $email

}
WARNING_CICA() {
	local email="eciencia@cica.es"
	cat info_email.txt| mail -a "Content-Type: text/plain; charset=UTF-8" -s "Cuentas en servicios de Supercomputación de CICA" $email
}


MAIL_EXPIRADO() {
	local nombre=$1
	local email=$2
	echo -e "Estimado usuario: \n\nNos ponemos en contacto con usted para informale que su cuenta $nombre ha expirado en los servicios de Supercomputación de CICA. \nPara renovar su cuenta debe ponerse en contacto con los servicios de supercomputacion a través de la direcion de correo eciencia@cica.es.\n" | mail -a "Content-Type: text/plain; charset=UTF-8" -s "Expiración de cuenta en servicios de Supercomputacion de CICA" $email

}

obtenerdatos=`ldapsearch -H $servidorldap  -x -D "$adminldap" -w "$passldap" -b "$ramaldap" "modifyTimestamp" |egrep "^dn:|^modifyTimestamp:" | tr -d " " | cut -d "=" -f 2 | tr -d "\n" | sed s/Z/"\n"/g`
for i in $obtenerdatos; do
	nombre=`echo $i | cut -d "," -f 1`
	fecha=`echo $i | cut -d ":" -f 2 | cut -c 1-8`
	fechaaltaUE=`date --date="$fecha" +%s`
	if [[ $nombre != "supercomputacion" ]]; then
		if [[ $fechaaltaUE -le $margenmin ]] && [[ $fechaaltaUE -gt $margenmax ]]; then
			Calculardías $nombre $fecha
		fi
		if [[ $fechaaltaUE -lt $margenmax ]]; then
			comprobarshell=`ldapsearch -H $servidorldap -x -D "$adminldap" -w "$passldap" -b "$ramaldap" "uid=$nombre" loginShell | egrep ^loginShell | cut -d " " -f 2 `
			if [[ $comprobarshell == "/bin/bash" ]]; then
				Usuariosexpirados[$nombre]=1
			fi
		fi
	fi
done

echo -e  "\n---------------------Usuarios Expirados---------------------------\n" >> info_email.txt

Comprobarultimaconexion=`ssh sesamo "bash /opt/scripts/usuarios-ultimaConexion.sh" | egrep -v '(Nunca ha entrado|root|Nombre)' | tr -s ' ' | cut -d " " -f 1 | tail -n+4`
for usuario in $Comprobarultimaconexion; do #Comprobamos los usuarios que llevan más de 1 año sin entrar a sesamo y que no estén bloqueados.
	comprobarshell=`ldapsearch -H $servidorldap -x -D "$adminldap" -w "$passldap" -b "$ramaldap" "uid=$usuario" loginShell | egrep ^loginShell | cut -d " " -f 2 `
	if [[ $comprobarshell == "/bin/bash" ]]; then
		Usuariosexpirados[$usuario]=1
	fi
done
bloquearcuenta
WARNING_CICA
rm info_email.txt
